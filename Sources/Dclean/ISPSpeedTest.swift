import Foundation

func getISPInfo() -> [String: Any] {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/curl"); t.arguments = ["-s", "-m", "5", "https://myip.ipip.net"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
            let cleaned = str.replacingOccurrences(of: "当前 IP：", with: "").replacingOccurrences(of: "当前 IP:", with: "")
            let parts = cleaned.components(separatedBy: "来自于：")
            let ip = parts[0].trimmingCharacters(in: CharacterSet.whitespaces)
            var isp = ""
            var location = ""
            if parts.count > 1 {
                let rest = parts[1].trimmingCharacters(in: CharacterSet.whitespaces)
                let tokens = rest.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
                if !tokens.isEmpty {
                    isp = tokens.last ?? ""
                    location = tokens.dropLast().joined(separator: " ")
                }
            }
            return ["ip": ip, "isp": isp, "location": location]
        }
    } catch {}
    return ["ip": "未知", "isp": "未知", "location": ""]
}

func runSpeedTest() -> String {
    // 多种可能的 speedtest 路径
    let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("../MacOS/speedtest").path
    let searchPaths: [String] = [bundlePath, "/usr/local/bin/speedtest", "/opt/homebrew/bin/speedtest"].compactMap { $0 }
    guard let spPath = searchPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        return "error"
    }
    // Try preferred servers first: Hangzhou (59386)
    let preferredIDs = ["59386"]
    for sid in preferredIDs {
        let t = Process()
        t.executableURL = URL(fileURLWithPath: spPath)
        t.arguments = ["--server-id", sid, "--format=json", "--accept-license", "--accept-gdpr", "--progress=no"]
        let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
        do { try t.run(); t.waitUntilExit()
            if let str = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
                for line in str.components(separatedBy: "\n") {
                    guard line.contains("\"type\":\"result\""),
                          let jd = line.data(using: .utf8),
                          let r = try? JSONSerialization.jsonObject(with: jd) as? [String: Any] else { continue }
                    let dl = ((r["download"] as? [String: Any])?["bandwidth"] as? Double ?? 0) * 8 / 1_000_000
                    let ul = ((r["upload"] as? [String: Any])?["bandwidth"] as? Double ?? 0) * 8 / 1_000_000
                    let ping = (r["ping"] as? [String: Any])?["latency"] as? Double ?? 0
                    let isp = r["isp"] as? String ?? ""
                    let srv = r["server"] as? [String: Any]
                    let loc = "\(srv?["location"] as? String ?? ""), \(srv?["country"] as? String ?? "")"
                    return String(format: "%.1f|%.1f|%.0f|%@|%@|%@", dl, ul, ping, isp, srv?["name"] as? String ?? "", loc)
                }
            }
        } catch {}
    }
    // Fallback to auto-select
    let t = Process()
    t.executableURL = URL(fileURLWithPath: spPath)
    t.arguments = ["--format=json", "--accept-license", "--accept-gdpr", "--progress=no"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else { return "error" }
        for line in str.components(separatedBy: "\n") {
            guard line.contains("\"type\":\"result\""),
                  let jd = line.data(using: .utf8),
                  let r = try? JSONSerialization.jsonObject(with: jd) as? [String: Any] else { continue }
            let dl = ((r["download"] as? [String: Any])?["bandwidth"] as? Double ?? 0) * 8 / 1_000_000
            let ul = ((r["upload"] as? [String: Any])?["bandwidth"] as? Double ?? 0) * 8 / 1_000_000
            let ping = (r["ping"] as? [String: Any])?["latency"] as? Double ?? 0
            let isp = r["isp"] as? String ?? ""
            let srv = r["server"] as? [String: Any]
            return String(format: "%.1f|%.1f|%.0f|%@|%@|%@", dl, ul, ping, isp, srv?["name"] as? String ?? "", "\(srv?["location"] as? String ?? ""), \(srv?["country"] as? String ?? "")")
        }
    } catch {}
    return "error"
}
