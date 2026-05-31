import Foundation

func getNetworkInfo() -> [[String: Any]] {
    var results: [[String: Any]] = []
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup"); t.arguments = ["-listallhardwareports"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            var name = "", device = "", mac = ""
            for line in str.components(separatedBy: "\n") {
                if line.hasPrefix("Hardware Port:") { name = line.replacingOccurrences(of: "Hardware Port: ", with: "").trimmingCharacters(in: CharacterSet.whitespaces) }
                else if line.hasPrefix("Device:") { device = line.replacingOccurrences(of: "Device: ", with: "").trimmingCharacters(in: CharacterSet.whitespaces) }
                else if line.hasPrefix("Ethernet Address:") { mac = line.replacingOccurrences(of: "Ethernet Address: ", with: "").trimmingCharacters(in: CharacterSet.whitespaces) }
                else if line.isEmpty && !name.isEmpty { results.append(["name": name, "device": device, "mac": mac]); name = ""; device = ""; mac = "" }
            }
            if !name.isEmpty { results.append(["name": name, "device": device, "mac": mac]) }
        }
    } catch {}
    return results
}

func getActiveInterface() -> String {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/sbin/route"); t.arguments = ["get", "default"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: "\n") {
                if line.contains("interface:") {
                    return line.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
        }
    } catch {}
    return "unknown"
}

func getNetworkPriority() -> [[String: Any]] {
    var order: [[String: Any]] = []
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup"); t.arguments = ["-listnetworkserviceorder"]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            var name = "", device = ""
            for line in str.components(separatedBy: "\n") {
                let tline = line.trimmingCharacters(in: CharacterSet.whitespaces)
                if tline.hasPrefix("(") && tline.contains(")") && !tline.hasPrefix("(Hardware") {
                    if let parenEnd = tline.firstIndex(of: ")") {
                        name = String(tline[tline.index(after: parenEnd)...]).trimmingCharacters(in: CharacterSet.whitespaces)
                    }
                } else if tline.contains("Device:") {
                    let parts = tline.components(separatedBy: ",")
                    for part in parts { if part.trimmingCharacters(in: CharacterSet.whitespaces).hasPrefix("Device:") { device = part.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: CharacterSet.whitespaces) } }
                    if !name.isEmpty {
                        let isWireless = name.lowercased().contains("wi-fi") || name.lowercased().contains("wifi")
                        order.append(["name": name, "device": device, "type": isWireless ? "无线" : "有线", "priority": order.count + 1])
                    }
                    name = ""; device = ""
                }
            }
        }
    } catch {}
    return order
}

func getLinkSpeed() -> Int {
    let activeDev = getActiveInterface()
    guard !activeDev.isEmpty, activeDev != "unknown" else { return 0 }
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/sbin/ifconfig"); t.arguments = [activeDev]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: "\n") {
                let tline = line.trimmingCharacters(in: CharacterSet.whitespaces)
                if tline.contains("media:") {
                    if tline.contains("2500") { return 2500 }
                    if tline.contains("1000") { return 1000 }
                    if tline.contains("500") { return 500 }
                    if tline.contains("100") { return 100 }
                }
            }
            if str.contains("link rate") {
                let at = Process()
                at.executableURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"); at.arguments = ["-I"]
                let ap = Pipe(); at.standardOutput = ap; at.standardError = FileHandle.nullDevice
                do { try at.run(); at.waitUntilExit()
                    let ad = ap.fileHandleForReading.readDataToEndOfFile()
                    if let astr = String(data: ad, encoding: .utf8) {
                        for l in astr.components(separatedBy: "\n") {
                            if l.contains("lastTxRate:") || l.contains("maxRate:") {
                                let val = l.components(separatedBy: ":").last?.trimmingCharacters(in: CharacterSet.whitespaces) ?? "0"
                                return Int(val) ?? 0
                            }
                        }
                    }
                } catch {}
            }
        }
    } catch {}
    return 0
}

func getActiveInterfaceInfo() -> [String: Any] {
    let activeDev = getActiveInterface()
    let adapters = getNetworkInfo()
    let priority = getNetworkPriority()
    var activeName = activeDev
    var activeType = "未知"
    for a in adapters {
        if let dev = a["device"] as? String, dev == activeDev {
            activeName = (a["name"] as? String) ?? activeDev
            activeType = (a["name"] as? String ?? "").lowercased().contains("wi-fi") ? "无线" : "有线"
        }
    }
    return ["activeDevice": activeDev, "activeName": activeName, "activeType": activeType, "priority": priority]
}
