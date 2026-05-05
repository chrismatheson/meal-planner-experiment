import Foundation

/// Captures timestamped sync events for the debug log in Settings → Sync Detail.
/// Capped ring buffer — keeps the most recent entries, oldest are dropped.
@Observable
final class SyncEventLog {
    static let shared = SyncEventLog()

    /// Maximum number of events to retain
    private let maxEvents = 50

    struct Event: Identifiable {
        let id = UUID()
        let date: Date
        let message: String
        let level: Level

        enum Level: String {
            case info = "info"
            case success = "success"
            case warning = "warning"
            case error = "error"

            var icon: String {
                switch self {
                case .info: return "arrow.right.circle"
                case .success: return "checkmark.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.circle"
                }
            }
        }

        var formattedTime: String {
            date.formatted(date: .omitted, time: .standard)
        }
    }

    private(set) var events: [Event] = []

    private init() {}

    // MARK: - Logging

    func log(_ message: String, level: Event.Level = .info) {
        let event = Event(date: Date(), message: message, level: level)
        events.insert(event, at: 0) // newest first
        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
        // Also print so console still works during development
        print("[\(level.rawValue.uppercased())] \(message)")
    }

    func info(_ message: String) { log(message, level: .info) }
    func success(_ message: String) { log(message, level: .success) }
    func warning(_ message: String) { log(message, level: .warning) }
    func error(_ message: String) { log(message, level: .error) }

    func clear() {
        events.removeAll()
    }

    /// Full log as plain text for copy/paste
    var plainText: String {
        events.reversed().map { event in
            "[\(event.formattedTime)] [\(event.level.rawValue.uppercased())] \(event.message)"
        }.joined(separator: "\n")
    }
}
