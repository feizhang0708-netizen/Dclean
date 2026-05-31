import AppKit
import WebKit

class Bridge: NSObject, WKScriptMessageHandler {
    weak var webView: DWebView?

    func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any], let action = body["action"] as? String else { return }
        let cb = "callback_\(body["id"] as? String ?? "0")"

        switch action {
        case "sysInfo":
            let mem = getMemInfo(); let cpu = getCPUInfo(); let disk = getDiskInfo()
            let js = "window['\(cb)']({memPct:\(mem.percent),memUsed:\(mem.used),memFree:\(mem.free),memCached:\(mem.cached),memTotal:\(ProcessInfo.processInfo.physicalMemory),cpuPct:\(cpu),disks:\(disk)})"
            webView?.eval(js)

        case "purge":
            let before = getMemInfo()
            purgeMem()
            Thread.sleep(forTimeInterval: 1.0)
            let after = getMemInfo()
            let result: [String: Any] = [
                "status": "success",
                "beforePct": before.percent, "afterPct": after.percent,
                "beforeUsed": before.used, "afterUsed": after.used,
                "freed": before.used > after.used ? before.used - after.used : 0
            ]
            if let json = try? JSONSerialization.data(withJSONObject: result, options: []),
               let s = String(data: json, encoding: .utf8) {
                let esc = s.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                webView?.eval("window['\(cb)']('\(esc)')")
            } else {
                webView?.eval("window['\(cb)']('{\"status\":\"error\"}')")
            }

        case "scanJunk":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let groups = categorizeJunk()
                if let json = try? JSONSerialization.data(withJSONObject: groups, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        case "deletePaths":
            if let paths = (body["data"] as? [String: Any])?["paths"] as? [String] {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else { return }
                    var tf: Int64 = 0; var d = 0
                    for p in paths { let (ok, f) = deletePath(p); if ok { d += 1; tf += f } }
                    DispatchQueue.main.async { self.webView?.eval("window['\(cb)']({deleted:\(d),freed:\(tf)})") }
                }
            }

        case "scanApps":
            DispatchQueue.global(qos: .userInitiated).async {
                let apps = scanAppSizes()
                if let json = try? JSONSerialization.data(withJSONObject: apps, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        case "scanUninstall":
            DispatchQueue.global(qos: .userInitiated).async {
                let apps = scanUninstallApps()
                if let json = try? JSONSerialization.data(withJSONObject: apps, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        case "findRelated":
            if let d = body["data"] as? [String: Any], let an = d["name"] as? String, let bid = d["bundleID"] as? String {
                DispatchQueue.global(qos: .userInitiated).async {
                    let files = findAppRelatedFiles(an, bid)
                    if let json = try? JSONSerialization.data(withJSONObject: files, options: []),
                       let s = String(data: json, encoding: .utf8) {
                        let esc = escapeJSON(s)
                        DispatchQueue.main.async { self.webView?.eval("window['\(cb)']('\(esc)')") }
                    }
                }
            }

        case "uninstallApps":
            if let paths = (body["data"] as? [String: Any])?["paths"] as? [String] {
                DispatchQueue.global(qos: .userInitiated).async {
                    let freed = uninstallAppFiles(paths)
                    DispatchQueue.main.async { self.webView?.eval("window['\(cb)']({freed:\(freed)})") }
                }
            }

        case "netInfo":
            let info = getNetworkInfo()
            if let json = try? JSONSerialization.data(withJSONObject: info, options: []),
               let s = String(data: json, encoding: .utf8) {
                let esc = escapeJSON(s)
                webView?.eval("window['\(cb)']('\(esc)')")
            }

        case "activeInterface":
            let info = getActiveInterfaceInfo()
            if let json = try? JSONSerialization.data(withJSONObject: info, options: []),
               let s = String(data: json, encoding: .utf8) {
                let esc = escapeJSON(s)
                webView?.eval("window['\(cb)']('\(esc)')")
            }

        case "topProcs":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let procs = getTopProcesses()
                if let json = try? JSONSerialization.data(withJSONObject: procs, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self?.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        case "killProc":
            if let d = body["data"] as? [String: Any], let pid = d["pid"] as? Int32 {
                let ok = killProcess(pid)
                webView?.eval("window['\(cb)'](\(ok))")
            }

        case "ispInfo":
            DispatchQueue.global(qos: .userInitiated).async {
                let info = getISPInfo()
                if let json = try? JSONSerialization.data(withJSONObject: info, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    DispatchQueue.main.async { self.webView?.eval("window['\(cb)']('\(s)')") }
                }
            }

        case "speedTest":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = runSpeedTest()
                DispatchQueue.main.async { self?.webView?.eval("window['\(cb)']('\(result)')") }
            }

        case "scanLargeFiles":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                var threshold: Int64 = 100 * 1024 * 1024
                if let d = body["data"] as? [String: Any], let t = d["threshold"] as? Int64 { threshold = t }
                let files = scanLargeOldFiles(threshold: threshold)
                if let json = try? JSONSerialization.data(withJSONObject: files, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        // === 网络诊断 ===
        case "wifiDiag":
            let info = getWiFiDiagnostics()
            if let json = try? JSONSerialization.data(withJSONObject: info, options: []),
               let s = String(data: json, encoding: .utf8) {
                let esc = escapeJSON(s)
                webView?.eval("window['\(cb)']('\(esc)')")
            }

        case "pingDiag":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = getPingDiagnostics()
                if let json = try? JSONSerialization.data(withJSONObject: result, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self?.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        case "dnsDiag":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = getDNSDiagnostics()
                if let json = try? JSONSerialization.data(withJSONObject: result, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self?.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        case "connDiag":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = getConnectionQuality()
                if let json = try? JSONSerialization.data(withJSONObject: result, options: []),
                   let s = String(data: json, encoding: .utf8) {
                    let esc = escapeJSON(s)
                    DispatchQueue.main.async { self?.webView?.eval("window['\(cb)']('\(esc)')") }
                }
            }

        case "ifaceDiag":
            let result = getInterfaceErrors()
            if let json = try? JSONSerialization.data(withJSONObject: result, options: []),
               let s = String(data: json, encoding: .utf8) {
                let esc = escapeJSON(s)
                webView?.eval("window['\(cb)']('\(esc)')")
            }

        default: break
        }
    }
}

private func escapeJSON(_ s: String) -> String {
    return s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
}
