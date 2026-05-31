import Foundation

func fastDirSize(_ path: String) -> Int64 {
    let t = Process(); t.executableURL = URL(fileURLWithPath: "/usr/bin/du"); t.arguments = ["-sk", path]
    let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit()
        if let str = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
           let kb = str.components(separatedBy: CharacterSet.whitespaces).first, let v = Int64(kb) { return v * 1024 }
    } catch {}
    return 0
}

func scanAppSizes() -> [[String: Any]] {
    var apps: [[String: Any]] = []
    let fm = FileManager.default
    for dir in ["/Applications", "/System/Applications", "/System/Applications/Utilities"] {
        guard let c = try? fm.contentsOfDirectory(atPath: dir) else { continue }
        for item in c where item.hasSuffix(".app") {
            let path = dir + "/" + item; let name = String(item.dropLast(4))
            let size = fastDirSize(path)
            if size > 0 { apps.append(["name": name, "path": path, "size": size]) }
        }
    }
    return apps.sorted { ($0["size"] as? Int64 ?? 0) > ($1["size"] as? Int64 ?? 0) }
}

func getBundleID(_ appPath: String) -> String {
    let pp = appPath + "/Contents/Info.plist"
    guard FileManager.default.fileExists(atPath: pp), let data = try? Data(contentsOf: URL(fileURLWithPath: pp)) else { return "" }
    var fmt = PropertyListSerialization.PropertyListFormat.xml
    guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: &fmt) as? [String: Any] else { return "" }
    return (plist["CFBundleIdentifier"] as? String) ?? (plist["bundleIdentifier"] as? String) ?? ""
}

func scanUninstallApps() -> [[String: Any]] {
    var apps: [[String: Any]] = []
    let fm = FileManager.default
    guard let c = try? fm.contentsOfDirectory(atPath: "/Applications") else { return apps }
    for item in c where item.hasSuffix(".app") {
        let path = "/Applications/" + item; guard fm.isReadableFile(atPath: path) else { continue }
        let name = String(item.dropLast(4)); let bid = getBundleID(path); let size = fastDirSize(path)
        if size > 0 { apps.append(["name": name, "path": path, "size": size, "bundleID": bid]) }
    }
    return apps.sorted { ($0["size"] as? Int64 ?? 0) > ($1["size"] as? Int64 ?? 0) }
}

func findAppRelatedFiles(_ appName: String, _ bundleID: String) -> [[String: Any]] {
    let h = NSHomeDirectory(); var results: [[String: Any]] = []
    let dirs: [(String, String)] = [(h+"/Library/Preferences","偏好设置"),(h+"/Library/Caches","缓存"),(h+"/Library/Application Support","应用数据"),(h+"/Library/Containers","沙盒容器"),(h+"/Library/Group Containers","共享容器"),(h+"/Library/Saved Application State","保存状态"),(h+"/Library/Logs","日志")]
    for (d, label) in dirs {
        guard FileManager.default.fileExists(atPath: d), let c = try? FileManager.default.contentsOfDirectory(atPath: d) else { continue }
        for item in c {
            if item.lowercased().contains(appName.lowercased()) || (bundleID.count > 0 && item.lowercased().contains(bundleID.lowercased())) {
                let p = d + "/" + item; let s = fastDirSize(p)
                if s > 0 { results.append(["name": item, "path": p, "size": s, "label": label]) }
            }
        }
    }
    return results
}

func uninstallAppFiles(_ paths: [String]) -> Int64 {
    var freed: Int64 = 0
    for path in paths {
        let old = fastDirSize(path)
        if path.hasPrefix("/Applications/") {
            let scr = "do shell script \"rm -rf '\(path)'\" with administrator privileges"
            let t = Process(); t.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); t.arguments = ["-e", scr]
            t.standardOutput = FileHandle.nullDevice; t.standardError = FileHandle.nullDevice
            do { try t.run(); t.waitUntilExit(); if t.terminationStatus == 0 { freed += old } } catch {}
        } else {
            let t = Process(); t.executableURL = URL(fileURLWithPath: "/bin/rm"); t.arguments = ["-rf", path]
            t.standardOutput = FileHandle.nullDevice; t.standardError = FileHandle.nullDevice
            do { try t.run(); t.waitUntilExit(); if t.terminationStatus == 0 { freed += old } } catch {}
        }
    }
    return freed
}
