import Darwin
import Foundation

struct MemorySample: Equatable {
    var pressure: Int
    var usedGB: Double
    var totalGB: Double
}

/// Reads the same numbers as pi-mempress, but straight from the kernel:
/// no `memory_pressure`, no `vm_stat | python3`, no subprocess at all.
enum MemoryReader {
    private static let pageSize = Double(vm_kernel_page_size)
    private static let bytesPerGB = 1_073_741_824.0

    static let totalGB: Double = {
        var bytes: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &bytes, &size, nil, 0) == 0 else { return 0 }
        return Double(bytes) / bytesPerGB
    }()

    /// Identical to the "System-wide memory free percentage" line of `memory_pressure`.
    private static func freePercentage() -> Int? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_level", &level, &size, nil, 0) == 0 else { return nil }
        return Int(level)
    }

    /// (anonymous + wired + compressor - purgeable) pages, matching the vm_stat arithmetic.
    private static func usedGB() -> Double? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pages = Double(stats.internal_page_count)
            + Double(stats.wire_count)
            + Double(stats.compressor_page_count)
            - Double(stats.purgeable_count)
        return pages * pageSize / bytesPerGB
    }

    static func sample() -> MemorySample? {
        guard let free = freePercentage(), let used = usedGB() else { return nil }
        return MemorySample(pressure: 100 - free, usedGB: used, totalGB: totalGB)
    }
}
