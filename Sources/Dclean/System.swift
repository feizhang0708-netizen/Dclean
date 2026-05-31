import Foundation

func getMemInfo() -> (used: UInt64, free: UInt64, cached: UInt64, percent: Int) {
    var u: UInt64 = 0, f: UInt64 = 0, c: UInt64 = 0
    let total = ProcessInfo.processInfo.physicalMemory
    var ps: vm_size_t = 0; host_page_size(mach_host_self(), &ps)
    var vm = vm_statistics64()
    var cnt = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
    if withUnsafeMutablePointer(to: &vm, { $0.withMemoryRebound(to: integer_t.self, capacity: Int(cnt)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &cnt) } }) == KERN_SUCCESS {
        let p = UInt64(ps)
        f = UInt64(vm.free_count) * p
        c = (UInt64(vm.inactive_count) + UInt64(vm.compressor_page_count)) * p
        u = (UInt64(vm.active_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)) * p
    }
    let pct = total > 0 ? Int((Double(u) / Double(total)) * 100) : 0
    return (u, f, c, pct)
}

func getCPUInfo() -> Int {
    var info = host_cpu_load_info()
    var cnt = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
    if withUnsafeMutablePointer(to: &info, { $0.withMemoryRebound(to: integer_t.self, capacity: Int(cnt)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &cnt) } }) != KERN_SUCCESS { return 0 }
    let user = Double(info.cpu_ticks.0), sys = Double(info.cpu_ticks.1), idle = Double(info.cpu_ticks.2), nice = Double(info.cpu_ticks.3)
    let total = user + sys + idle + nice
    return total > 0 ? Int(((user + sys + nice) / total) * 100) : 0
}

func getDiskInfo() -> String {
    var s = statfs()
    guard statfs("/", &s) == 0 else { return "{}" }
    let name = String(cString: withUnsafeBytes(of: s.f_fstypename) { $0.baseAddress!.assumingMemoryBound(to: CChar.self) })
    let total = UInt64(s.f_bsize) * s.f_blocks
    let avail = UInt64(s.f_bsize) * s.f_bavail
    let used = total - avail
    return "{\"\(name)\":{\"total\":\(total),\"avail\":\(avail),\"used\":\(used)}}"
}

func getDiskJSON() -> [[String: Any]] {
    var disks: [[String: Any]] = []
    if let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey], options: .skipHiddenVolumes) {
        for url in urls {
            if let vals = try? url.resourceValues(forKeys: [.volumeNameKey as URLResourceKey, .volumeTotalCapacityKey as URLResourceKey, .volumeAvailableCapacityForImportantUsageKey as URLResourceKey]),
               let name = vals.volumeName, let total = vals.volumeTotalCapacity, let avail = vals.volumeAvailableCapacityForImportantUsage {
                disks.append(["name": name, "total": Int64(total), "avail": Int64(avail), "used": Int64(total) - Int64(avail)])
            }
        }
    }
    return disks
}

func purgeMem() {
    sync()
    // 多轮大块分配/释放，触发 VM 压力，迫使系统回收非活跃页和压缩页
    for _ in 0..<4 {
        let cs = 128 * 1024 * 1024
        var blocks: [UnsafeMutableRawPointer] = []
        for _ in 0..<8 {
            if let p = malloc(cs) { memset(p, 0, cs); blocks.append(p) }
        }
        for p in blocks { free(p) }
    }
}
