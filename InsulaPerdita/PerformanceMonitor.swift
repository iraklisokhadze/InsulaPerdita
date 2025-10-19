import Foundation
#if DEBUG
import os.log

final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "InsulaPerdita", category: "Perf")
    private var timer: DispatchSourceTimer?
    private var lastTick: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private let interval: TimeInterval = 2.0

    private init() {}

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            let now = CFAbsoluteTimeGetCurrent()
            let delta = (now - self.lastTick) * 1000
            self.lastTick = now
            os_log("[Perf] heartbeat dt=%{public}.1fms", log: self.log, type: .debug, delta)
        }
        t.resume()
        timer = t
        os_log("[Perf] monitor started (interval=%{public}.1fs)", log: log, type: .debug, interval)
    }

    func stop() {
        timer?.cancel()
        timer = nil
        os_log("[Perf] monitor stopped", log: log, type: .debug)
    }
}
#endif
