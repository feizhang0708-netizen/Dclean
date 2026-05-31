import Foundation
import CoreWLAN

// MARK: - 网络接口诊断（自动识别 WiFi / 有线）

func getWiFiDiagnostics() -> [String: Any] {
    // 1. 找出当前活跃的网络接口
    let activeDev = getActiveInterface()
    // 2. 判断该接口是 WiFi 还是有线
    let connType = interfaceType(activeDev)

    if connType == "wifi" {
        // WiFi 连接 — 用 CoreWLAN 获取信号详情
        if let wifi = wifiViaCoreWLAN() { return wifi }
        if let wifi = wifiViaSystemProfiler() { return wifi }
        return ["connectionType": "wifi", "interfaceName": activeDev, "wifiAvailable": false]
    } else if connType == "wired" {
        return getWiredInfo(activeDev)
    } else {
        return ["connectionType": "none", "interfaceName": activeDev, "wifiAvailable": false]
    }
}

func interfaceType(_ dev: String) -> String {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    t.arguments = ["-listallhardwareports"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            var currentPort = ""
            for line in str.components(separatedBy: "\n") {
                if line.hasPrefix("Hardware Port:") {
                    currentPort = line.replacingOccurrences(of: "Hardware Port:", with: "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                if line.hasPrefix("Device:") {
                    let device = line.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: CharacterSet.whitespaces)
                    if device == dev {
                        let lower = currentPort.lowercased()
                        if lower.contains("wi-fi") || lower.contains("wifi") || lower.contains("airport") { return "wifi" }
                        if lower.contains("ethernet") || lower.contains("usb") || lower.contains("thunderbolt") { return "wired" }
                        // 中文
                        if lower.contains("以太网") || lower.contains("有线") { return "wired" }
                        if lower.contains("无线") { return "wifi" }
                        // 默认根据设备名判断
                        if dev.hasPrefix("en") { return "wifi" }
                        return "wired"
                    }
                }
            }
        }
    } catch {}
    return "unknown"
}

func getWiredInfo(_ dev: String) -> [String: Any] {
    var speed = 0
    var ip = ""
    var mac = ""
    // 获取链路速度和 IP
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/sbin/ifconfig"); t.arguments = [dev]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: "\n") {
                let tline = line.trimmingCharacters(in: CharacterSet.whitespaces)
                if tline.contains("media:") {
                    if tline.contains("2500") { speed = 2500 }
                    else if tline.contains("1000") { speed = 1000 }
                    else if tline.contains("100") { speed = 100 }
                    else if tline.contains("10") { speed = 10 }
                }
                if tline.contains("inet ") && !tline.contains("127.0.0.1") {
                    let parts = tline.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 { ip = parts[1] }
                }
                if tline.hasPrefix("ether ") {
                    let parts = tline.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 { mac = parts[1] }
                }
            }
        }
    } catch {}

    // 获取接口友好名称
    var portName = dev
    let t2 = Process()
    t2.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    t2.arguments = ["-listallhardwareports"]
    let p2 = Pipe(); t2.standardOutput = p2; t2.standardError = FileHandle.nullDevice
    do {
        try t2.run(); t2.waitUntilExit()
        let data = p2.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            var current = ""
            for line in str.components(separatedBy: "\n") {
                if line.hasPrefix("Hardware Port:") { current = line.replacingOccurrences(of: "Hardware Port:", with: "").trimmingCharacters(in: CharacterSet.whitespaces) }
                if line.hasPrefix("Device:"), line.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: CharacterSet.whitespaces) == dev {
                    portName = current; break
                }
            }
        }
    } catch {}

    return [
        "connectionType": "wired",
        "interfaceName": dev,
        "portName": portName,
        "speed": speed,
        "ip": ip,
        "mac": mac,
        "wifiAvailable": false
    ]
}

func wifiViaCoreWLAN() -> [String: Any]? {
    guard let iface = CWWiFiClient.shared().interface(), iface.powerOn() else { return nil }
    let rssi = iface.rssiValue()
    let noise = iface.noiseMeasurement()
    let sigQuality: String = rssi > -50 ? "excellent" : rssi > -65 ? "good" : rssi > -75 ? "fair" : "poor"
    return [
        "connectionType": "wifi",
        "interfaceName": iface.interfaceName ?? "en0",
        "wifiAvailable": true,
        "ssid": iface.ssid() ?? "已连接",
        "rssi": rssi,
        "noise": noise,
        "snr": rssi - noise,
        "txRate": iface.transmitRate(),
        "phyMode": phyModeStr(iface.activePHYMode()),
        "channel": iface.wlanChannel()?.channelNumber ?? 0,
        "channelBand": channelBandStr(iface.wlanChannel()),
        "security": securityStr(iface.security()),
        "signalQuality": sigQuality,
        "hardwareAddress": iface.hardwareAddress() ?? ""
    ]
}

func wifiViaSystemProfiler() -> [String: Any]? {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    t.arguments = ["-xml", "SPAirPortDataType"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]],
              let items = plist.first?["_items"] as? [[String: Any]],
              let ifaces = items.first?["spairport_airport_interfaces"] as? [[String: Any]],
              let iface = ifaces.first else { return nil }

        var ssid = "已连接"
        var channelStr = ""
        var phyMode = "未知"
        var security = "未知"
        if let current = iface["spairport_current_network_information"] as? [String: Any] {
            ssid = (current["_name"] as? String) ?? ssid
            channelStr = (current["spairport_network_channel"] as? String) ?? ""
            phyMode = (current["spairport_network_phymode"] as? String) ?? "未知"
            security = (current["spairport_security_mode"] as? String) ?? "未知"
        }
        if ssid == "已连接", let others = iface["spairport_airport_other_local_wireless_networks"] as? [[String: Any]], let first = others.first {
            ssid = (first["_name"] as? String) ?? "已连接"
            channelStr = (first["spairport_network_channel"] as? String) ?? ""
            phyMode = (first["spairport_network_phymode"] as? String) ?? "未知"
            security = (first["spairport_security_mode"] as? String) ?? "未知"
        }

        let chNum = Int(channelStr.components(separatedBy: CharacterSet.whitespaces).first ?? "0") ?? 0
        let chBand = channelStr.contains("5GHz") ? "5GHz" : channelStr.contains("2GHz") ? "2.4GHz" : ""

        return [
            "connectionType": "wifi",
            "interfaceName": iface["_name"] as? String ?? "en0",
            "wifiAvailable": true,
            "ssid": ssid,
            "rssi": 0, "noise": 0, "snr": 0,
            "txRate": wifiTxRate(iface["_name"] as? String ?? ""),
            "phyMode": phyMode,
            "channel": chNum,
            "channelBand": chBand,
            "security": security,
            "signalQuality": "unknown",
            "hardwareAddress": iface["spairport_hardware_address"] as? String ?? ""
        ]
    } catch {}
    return nil
}

func wifiTxRate(_ ifname: String) -> Double {
    let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    guard FileManager.default.fileExists(atPath: airportPath) else { return 0 }
    let t = Process()
    t.executableURL = URL(fileURLWithPath: airportPath)
    t.arguments = ["-I"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: "\n") {
                if line.contains("lastTxRate:") {
                    return Double(line.components(separatedBy: ":").last?.trimmingCharacters(in: CharacterSet.whitespaces) ?? "0") ?? 0
                }
            }
        }
    } catch {}
    return 0
}

func phyModeStr(_ mode: CWPHYMode) -> String {
    switch mode {
    case .mode11a: return "802.11a"; case .mode11b: return "802.11b"
    case .mode11g: return "802.11g"; case .mode11n: return "802.11n"
    case .mode11ac: return "802.11ac"; case .mode11ax: return "802.11ax"
    default: return "未知"
    }
}

func channelBandStr(_ ch: CWChannel?) -> String {
    guard let ch = ch else { return "" }
    switch ch.channelBand {
    case .band2GHz: return "2.4GHz"; case .band5GHz: return "5GHz"
    case .band6GHz: return "6GHz"; default: return ""
    }
}

func securityStr(_ sec: CWSecurity) -> String {
    switch sec {
    case .none: return "无加密"; case .WEP: return "WEP"
    case .wpaPersonal: return "WPA"; case .wpaPersonalMixed: return "WPA/WPA2"
    case .wpa2Personal: return "WPA2"; case .personal: return "WPA3"
    default: return "企业级"
    }
}

// MARK: - 接口错误统计

func getInterfaceErrors() -> [String: Any] {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat"); t.arguments = ["-i"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else { return ["interfaces": []] }
        var lines = str.components(separatedBy: "\n")
        if lines.count > 0 { lines.removeFirst() }
        var interfaces: [[String: Any]] = []
        for line in lines {
            let parts = line.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
            if parts.count >= 8 {
                let name = parts[0]
                let inerrs = Int64(parts[5]) ?? 0
                let outerrs = Int64(parts[7]) ?? 0
                if name != "lo0" { interfaces.append(["name": name, "inErrors": inerrs, "outErrors": outerrs]) }
            }
        }
        return ["interfaces": interfaces]
    } catch {}
    return ["interfaces": []]
}

// MARK: - Ping 诊断

func getPingDiagnostics() -> [String: Any] {
    var results: [[String: Any]] = []
    let gateway = getGatewayIP()
    var targets: [(String, String)] = [("8.8.8.8", "Google DNS"), ("114.114.114.114", "114 DNS")]
    if !gateway.isEmpty && gateway != "unknown" {
        targets.insert((gateway, "网关"), at: 0)
    }
    let group = DispatchGroup()
    let lock = NSLock()
    for (ip, label) in targets {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let r = pingHost(ip)
            lock.lock()
            results.append(["ip": ip, "label": label, "min": r.min, "avg": r.avg, "max": r.max, "stddev": r.stddev, "loss": r.loss])
            lock.unlock()
            group.leave()
        }
    }
    _ = group.wait(timeout: .now() + 12)
    return ["targets": results]
}

func getGatewayIP() -> String {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/sbin/route"); t.arguments = ["-n", "get", "default"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: "\n") {
                if line.contains("gateway:") {
                    return line.replacingOccurrences(of: "gateway:", with: "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
        }
    } catch {}
    return "unknown"
}

func pingHost(_ host: String) -> (min: Double, avg: Double, max: Double, stddev: Double, loss: Double) {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/sbin/ping"); t.arguments = ["-c", "3", "-W", "2000", host]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = pipe
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8), !str.isEmpty else { return (0, 0, 0, 0, 100) }

        // 丢包率
        var loss: Double = 100
        if let range = str.range(of: #"(\d+\.?\d*)% packet loss"#, options: .regularExpression) {
            let sub = String(str[range])
            loss = Double(sub.replacingOccurrences(of: "% packet loss", with: "")) ?? 100
        }

        // 尝试匹配 round-trip 行
        var rmin: Double = 0, ravg: Double = 0, rmax: Double = 0, rstd: Double = 0
        if let range = str.range(of: #"round-trip min/avg/max/stddev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+)"#, options: .regularExpression) {
            let line = String(str[range])
            let values = line.replacingOccurrences(of: "round-trip min/avg/max/stddev = ", with: "").replacingOccurrences(of: " ms", with: "")
            let nums = values.components(separatedBy: "/")
            if nums.count >= 4 {
                rmin = Double(nums[0]) ?? 0; ravg = Double(nums[1]) ?? 0
                rmax = Double(nums[2]) ?? 0; rstd = Double(nums[3]) ?? 0
            }
        }
        return (rmin, ravg, rmax, rstd, loss)
    } catch {}
    return (0, 0, 0, 0, 100)
}

// MARK: - DNS 诊断

func getDNSDiagnostics() -> [String: Any] {
    var servers: [String] = []
    // scutil --dns 获取当前 DNS
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil"); t.arguments = ["--dns"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: "\n") {
                if line.contains("nameserver[") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        let ip = parts[1...].joined(separator: ":").trimmingCharacters(in: CharacterSet.whitespaces)
                        if !ip.isEmpty && isValidIP(ip) && !servers.contains(ip) { servers.append(ip) }
                    }
                }
            }
        }
    } catch {}

    // 如果没有解析到，添加常见 DNS 作为测试目标
    if servers.isEmpty { servers = ["114.114.114.114", "223.5.5.5"] }

    var results: [[String: Any]] = []
    let group = DispatchGroup()
    let lock = NSLock()
    for server in servers.prefix(3) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let qTime = dnsQueryTime(server)
            lock.lock()
            results.append(["server": server, "queryTimeMs": qTime])
            lock.unlock()
            group.leave()
        }
    }
    _ = group.wait(timeout: .now() + 8)

    // 推荐 DNS
    var recommendations: [[String: Any]] = []
    let knownFastDNS: [(String, String)] = [("114.114.114.114", "114 DNS (国内推荐)"), ("223.5.5.5", "阿里 DNS"), ("119.29.29.29", "腾讯 DNS"), ("8.8.8.8", "Google DNS")]
    for (server, name) in knownFastDNS where !servers.contains(server) {
        recommendations.append(["server": server, "name": name])
    }

    return ["servers": results, "recommendations": recommendations]
}

func isValidIP(_ s: String) -> Bool {
    let parts = s.components(separatedBy: ".")
    guard parts.count == 4 else { return false }
    return parts.allSatisfy { p in Int(p).map { $0 >= 0 && $0 <= 255 } ?? false }
}

func dnsQueryTime(_ server: String) -> Double {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/dig"); t.arguments = ["+stats", "+time=3", "@\(server)", "baidu.com"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: "\n") {
                if line.contains("Query time:") {
                    let val = line.replacingOccurrences(of: "Query time:", with: "")
                        .replacingOccurrences(of: "msec", with: "")
                        .trimmingCharacters(in: CharacterSet.whitespaces)
                    return Double(val) ?? -1
                }
            }
        }
    } catch {}
    return -1
}

// MARK: - TCP 连接质量

func getConnectionQuality() -> [String: Any] {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
    t.arguments = ["-J", "rx_dupe,rx_ooo,re-tx,rtt_avg", "-m", "tcp", "-n", "-L", "1", "-d", "-t", "external", "-x"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do {
        try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            var totalRetx: Double = 0, totalDupe: Double = 0, totalOOO: Double = 0, totalRTT: Double = 0
            var connCount = 0
            for line in str.components(separatedBy: "\n") {
                if line.isEmpty || line.hasPrefix("time") || line.hasPrefix(",") { continue }
                let cols = line.components(separatedBy: ",")
                if cols.count >= 10 {
                    let retx = Double(cols[cols.count - 2].trimmingCharacters(in: CharacterSet.whitespaces)) ?? 0
                    let rtt = Double(cols[cols.count - 1].trimmingCharacters(in: CharacterSet.whitespaces)) ?? 0
                    let dupe = Double(cols[cols.count - 4].trimmingCharacters(in: CharacterSet.whitespaces)) ?? 0
                    let ooo = Double(cols[cols.count - 3].trimmingCharacters(in: CharacterSet.whitespaces)) ?? 0
                    if rtt > 0 { totalRetx += retx; totalDupe += dupe; totalOOO += ooo; totalRTT += rtt; connCount += 1 }
                }
            }
            let avgRTT = connCount > 0 ? totalRTT / Double(connCount) : 0
            let retransmitRate = connCount > 0 ? totalRetx / Double(connCount) : 0
            return ["connections": connCount, "avgRTT": Int(avgRTT), "totalRetx": Int(totalRetx), "totalDupe": Int(totalDupe), "totalOOO": Int(totalOOO), "retransmitRate": String(format: "%.1f", retransmitRate * 100)]
        }
    } catch {}
    return ["connections": 0, "avgRTT": 0, "totalRetx": 0, "totalDupe": 0, "totalOOO": 0, "retransmitRate": "0"]
}
