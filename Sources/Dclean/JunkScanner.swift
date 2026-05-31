import Foundation

func dirSize(_ path: String) -> Int64 {
    let fm = FileManager.default; guard fm.fileExists(atPath: path) else { return 0 }
    if (try? fm.destinationOfSymbolicLink(atPath: path)) != nil { return 0 }
    var t: Int64 = 0
    if let e = fm.enumerator(atPath: path) {
        while let f = e.nextObject() as? String {
            let full = path + "/" + f
            if (try? fm.destinationOfSymbolicLink(atPath: full)) != nil {
                e.skipDescendants(); continue
            }
            t += (try? fm.attributesOfItem(atPath: full)[.size] as? Int64) ?? 0
        }
    }
    return t
}

func mkEntry(_ path: String, _ name: String) -> [String: Any]? {
    let s = dirSize(path); return s > 0 ? ["name": name, "path": path, "size": s, "selected": true] : nil
}

func categorizeJunk() -> [[String: Any]] {
    let h = NSHomeDirectory(); var groups: [[String: Any]] = []
    let cats: [(String, [(String, String)])] = [
        ("浏览器缓存", [
            (h + "/Library/Caches/com.apple.Safari", "Safari"),
            (h + "/Library/Caches/Google/Chrome", "Chrome"),
            (h + "/Library/Caches/com.microsoft.edgemac", "Edge"),
            (h + "/Library/Caches/org.mozilla.firefox", "Firefox"),
        ]),
        ("通讯软件", [
            (h + "/Library/Caches/com.tencent.xinWeChat", "微信"),
            (h + "/Library/Caches/com.tencent.WeWorkMac", "企业微信"),
            (h + "/Library/Caches/com.tencent.qq", "QQ"),
            (h + "/Library/Caches/com.alibaba.DingTalkMac", "钉钉"),
        ]),
        ("开发工具", [
            (h + "/Library/Developer/Xcode/DerivedData", "Xcode 编译缓存"),
            (h + "/.npm", "npm 缓存"),
            (h + "/Library/Caches/Yarn", "Yarn 缓存"),
            (h + "/.gradle/caches", "Gradle 缓存"),
        ]),
        ("系统垃圾", [
            ("/Library/Caches", "系统缓存"),
            (h + "/Library/Logs", "用户日志"),
            (h + "/.Trash", "废纸篓"),
        ]),
    ]
    for (cat, items) in cats {
        let entries = items.compactMap { mkEntry($0.0, $0.1) }
        if !entries.isEmpty { groups.append(["icon": "", "category": cat, "items": entries]) }
    }
    // 自动发现 >100MB 的缓存
    var otherItems: [[String: Any]] = []
    let known = Set(["com.apple.Safari", "Google", "com.microsoft.edgemac", "org.mozilla.firefox", "com.tencent.xinWeChat", "com.tencent.WeWorkMac", "com.tencent.qq", "com.alibaba.DingTalkMac", "Yarn"])
    if let c = try? FileManager.default.contentsOfDirectory(atPath: h + "/Library/Caches") {
        for item in c where !known.contains(item) {
            let p = h + "/Library/Caches/" + item; let s = dirSize(p)
            if s > 100 * 1024 * 1024 { otherItems.append(["name": item, "path": p, "size": s, "selected": true]) }
        }
    }
    if !otherItems.isEmpty { groups.append(["icon": "", "category": "其他缓存（>100MB）", "items": otherItems.sorted { ($0["size"] as? Int64 ?? 0) > ($1["size"] as? Int64 ?? 0) }]) }
    return groups
}

func deletePath(_ path: String) -> (Bool, Int64) {
    let old = dirSize(path); let fm = FileManager.default
    guard fm.fileExists(atPath: path) else { return (false, 0) }
    if let _ = try? fm.destinationOfSymbolicLink(atPath: path) {
        try? fm.removeItem(atPath: path)
        return (true, 0)
    }
    if let c = try? fm.contentsOfDirectory(atPath: path) {
        for i in c {
            let itemPath = path + "/" + i
            if let _ = try? fm.destinationOfSymbolicLink(atPath: itemPath) {
                try? fm.removeItem(atPath: itemPath)
                continue
            }
            let realPath = (try? fm.destinationOfSymbolicLink(atPath: itemPath)) ?? itemPath
            let protected = ["/Users/", "/Documents", "/Desktop", "/Downloads", "/Pictures", "/Movies", "/Music"]
            let absReal = realPath.hasPrefix("/") ? realPath : (fm.currentDirectoryPath + "/" + realPath)
            let isProtected = protected.contains { absReal.contains($0) && !absReal.contains("/Library/Caches") && !absReal.contains("/Library/Logs") && !absReal.contains("/.Trash") && !absReal.contains("/.npm") && !absReal.contains("/.gradle") && !absReal.contains("/DerivedData") && !absReal.contains("/Developer/") }
            if isProtected { continue }
            let t = Process(); t.executableURL = URL(fileURLWithPath: "/bin/rm"); t.arguments = ["-rf", itemPath]
            t.standardOutput = FileHandle.nullDevice; t.standardError = FileHandle.nullDevice
            do { try t.run(); let dl = Date().addingTimeInterval(5)
                while t.isRunning && Date() < dl { Thread.sleep(forTimeInterval: 0.1) }
                if t.isRunning { t.terminate() }
            } catch {}
        }
    }
    return ((max(0, old - dirSize(path))) > 0, max(0, old - dirSize(path)))
}

func scanLargeOldFiles(threshold: Int64) -> [[String: Any]] {
    var results: [[String: Any]] = []
    let h = NSHomeDirectory()
    let scanDirs = [h + "/Downloads", h + "/Desktop", h + "/Documents"]
    let now = Date()

    for dir in scanDirs {
        let t = Process()
        t.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        t.arguments = ["-P", dir, "-type", "f", "-size", "+\(threshold / 1024)k", "-maxdepth", "6"]
        let pipe = Pipe(); t.standardOutput = pipe; t.standardError = FileHandle.nullDevice
        do {
            try t.run(); t.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                for line in str.components(separatedBy: "\n") {
                    let full = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if full.isEmpty || full.hasPrefix(".") { continue }
                    var st = stat()
                    if stat(full, &st) == 0 {
                        let size = Int64(st.st_size)
                        let mtime = Date(timeIntervalSince1970: Double(st.st_mtimespec.tv_sec))
                        let age = Int(now.timeIntervalSince(mtime) / 86400)
                        let name = (full as NSString).lastPathComponent
                        results.append(["name": name, "path": full, "size": size, "age": age, "mtime": mtime.description])
                    }
                }
            }
        } catch {}
    }
    return results.sorted { ($0["size"] as? Int64 ?? 0) > ($1["size"] as? Int64 ?? 0) }
}
