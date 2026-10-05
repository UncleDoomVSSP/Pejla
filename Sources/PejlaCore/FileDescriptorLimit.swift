import Foundation

public enum FileDescriptorLimit {
    /// Raises the soft open-file limit so hundreds of concurrent probes do not
    /// fail with EMFILE. GUI apps start with a low default.
    @discardableResult
    public static func raise(to desired: Int = 4096) -> Bool {
        var limit = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &limit) == 0 else { return false }
        let ceiling = min(limit.rlim_max, rlim_t(OPEN_MAX))
        let target = min(rlim_t(desired), ceiling)
        guard target > limit.rlim_cur else { return true }
        limit.rlim_cur = target
        return setrlimit(RLIMIT_NOFILE, &limit) == 0
    }
}
