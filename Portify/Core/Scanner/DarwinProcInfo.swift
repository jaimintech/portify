import Darwin
import Foundation
import OSLog

// C macros not directly available in Swift
private let PROC_PIDPATHINFO_MAXSIZE_VALUE: Int = 4 * Int(MAXPATHLEN)
private let PROC_PIDVNODEPATHINFO_VALUE: Int32 = 9
private let PROC_PIDTBSDINFO_VALUE: Int32 = 3

/// Production ProcInfoProviding using Darwin APIs.
struct DarwinProcInfo: ProcInfoProviding {
    func executablePath(for pid: Int32) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: PROC_PIDPATHINFO_MAXSIZE_VALUE)
        let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard result > 0 else {
            Logger.resolver.debug("Failed to get path for PID \(pid)")
            return nil
        }
        return String(cString: pathBuffer)
    }

    func workingDirectory(for pid: Int32) -> String? {
        var vnodeInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO_VALUE, 0, &vnodeInfo, Int32(size))
        guard result == size else {
            Logger.resolver.debug("Failed to get CWD for PID \(pid)")
            return nil
        }
        return withUnsafePointer(to: vnodeInfo.pvi_cdir.vip_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cPath in
                String(cString: cPath)
            }
        }
    }

    func startTime(for pid: Int32) -> Date? {
        var taskInfo = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO_VALUE, 0, &taskInfo, Int32(size))
        guard result == size else {
            Logger.resolver.debug("Failed to get start time for PID \(pid)")
            return nil
        }
        let seconds = TimeInterval(taskInfo.pbi_start_tvsec)
        let microseconds = TimeInterval(taskInfo.pbi_start_tvusec) / 1_000_000
        return Date(timeIntervalSince1970: seconds + microseconds)
    }
}
