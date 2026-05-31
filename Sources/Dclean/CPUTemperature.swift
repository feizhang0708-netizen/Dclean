import Foundation

// CPU温度监控 — 后台 powermetrics，数据写入临时文件后定时读取

private var _cachedTemp: Double = 0
private var _thermalState: String = "正常"
private var _monitorRunning = false
private let tempLock = NSLock()
private let tempLogPath = "/tmp/dclean_temp.log"

func getCPUTemperature() -> Double {
    tempLock.lock(); defer { tempLock.unlock() }
    if !_monitorRunning { startTempMonitor() }
    return _cachedTemp
}

func getThermalState() -> String {
    tempLock.lock(); defer { tempLock.unlock() }
    switch ProcessInfo.processInfo.thermalState {
    case .nominal:  _thermalState = "正常"
    case .fair:     _thermalState = "轻度"
    case .serious:  _thermalState = "严重"
    case .critical: _thermalState = "危险"
    @unknown default:_thermalState = "未知"
    }
    return _thermalState
}

func getTempJSON() -> String {
    let temp = getCPUTemperature()
    let state = getThermalState()
    if let json = try? JSONSerialization.data(withJSONObject: [
        "dieTemp": temp, "thermalState": state
    ], options: []), let str = String(data: json, encoding: .utf8) {
        return str
    }
    return "{}"
}

private func startTempMonitor() {
    _monitorRunning = true

    // 1. 通过 osascript 在后台启动 powermetrics（弹一次密码框）
    let startCmd = """
    do shell script "rm -f \(tempLogPath); nohup powermetrics --samplers cpu_power -i 3000 > \(tempLogPath) 2>/dev/null &" with administrator privileges
    """
    let starter = Process()
    starter.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    starter.arguments = ["-e", startCmd]
    starter.standardOutput = FileHandle.nullDevice
    starter.standardError = FileHandle.nullDevice
    do { try starter.run(); starter.waitUntilExit() } catch {
        tempLock.lock(); _monitorRunning = false; tempLock.unlock()
        return
    }

    // 2. 打开日志文件，用 DispatchSource 监听变化
    DispatchQueue.global(qos: .utility).async {
        // 等待文件创建
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: tempLogPath) { break }
            Thread.sleep(forTimeInterval: 0.5)
        }

        guard let fh = FileHandle(forReadingAtPath: tempLogPath) else {
            tempLock.lock(); _monitorRunning = false; tempLock.unlock()
            return
        }
        // 跳到文件末尾
        fh.seekToEndOfFile()

        // 用 readabilityHandler 监听新数据
        fh.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            for line in chunk.components(separatedBy: "\n") {
                parseTempLine(line)
            }
        }

        // 保活：如果文件被删或 monitor 标记停止，清理
        while _monitorRunning && FileManager.default.fileExists(atPath: tempLogPath) {
            Thread.sleep(forTimeInterval: 5)
        }
        fh.readabilityHandler = nil
        try? fh.close()
        tempLock.lock(); _monitorRunning = false; tempLock.unlock()
    }
}

private func parseTempLine(_ line: String) {
    guard line.contains("CPU") && line.contains("temperature") else { return }
    let parts = line.components(separatedBy: CharacterSet.whitespaces)
    for part in parts {
        let cleaned = part.replacingOccurrences(of: "C", with: "")
        if let temp = Double(cleaned) {
            tempLock.lock(); _cachedTemp = temp; tempLock.unlock()
            return
        }
    }
}
