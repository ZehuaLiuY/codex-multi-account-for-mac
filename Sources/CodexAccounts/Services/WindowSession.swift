import Darwin
import Foundation

struct ProcessIdentity: Codable, Equatable {
    let pid: Int32
    let startSeconds: UInt64
    let startMicroseconds: UInt64

    static func capture(pid: Int32) -> ProcessIdentity? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return ProcessIdentity(pid: pid, startSeconds: info.pbi_start_tvsec,
                               startMicroseconds: info.pbi_start_tvusec)
    }

    var isCurrent: Bool { Self.capture(pid: pid) == self }
}

struct WindowSession: Codable, Equatable {
    let accountID: UUID
    let process: ProcessIdentity
}
