import AppKit
import Foundation

func getTopProcesses() -> [[String: Any]] {
    var procs: [[String: Any]] = []
    let apps = NSWorkspace.shared.runningApplications
    var allProcs: [(pid: Int32, name: String, rss: Int64)] = []
    let myPid = ProcessInfo.processInfo.processIdentifier

    for app in apps {
        let pid = app.processIdentifier
        if pid <= 1 || pid == myPid { continue }
        let name = app.localizedName ?? ""
        if name.isEmpty || name == "Dclean" { continue }

        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)
        if result > 0 {
            let rss = Int64(taskInfo.pti_resident_size)
            if rss > 30 * 1024 * 1024 {
                allProcs.append((pid: pid, name: name, rss: rss))
            }
        }
    }
    allProcs.sort { $0.rss > $1.rss }
    for p in allProcs.prefix(7) {
        procs.append(["pid": p.pid, "name": p.name, "memory": p.rss, "selected": false])
    }
    return procs
}

func killProcess(_ pid: Int32) -> Bool {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/bin/kill"); t.arguments = ["-9", "\(pid)"]
    t.standardOutput = FileHandle.nullDevice; t.standardError = FileHandle.nullDevice
    do { try t.run(); t.waitUntilExit(); return t.terminationStatus == 0 } catch { return false }
}
