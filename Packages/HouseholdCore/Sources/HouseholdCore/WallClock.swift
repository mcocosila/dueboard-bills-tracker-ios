import Foundation

/// Where the core gets "now" and the time zone from. The app passes `.system`;
/// tests pin both with `.fixed(_:in:)`, so every date rule can be checked
/// against a chosen moment and place.
public struct WallClock: Sendable {
    private let currentDate: @Sendable () -> Date
    public let timeZone: TimeZone

    public init(timeZone: TimeZone, now: @escaping @Sendable () -> Date) {
        self.timeZone = timeZone
        self.currentDate = now
    }

    public var now: Date { currentDate() }

    /// The device's clock and time zone, following the device if either changes.
    public static let system = WallClock(timeZone: .autoupdatingCurrent) { Date() }

    /// A clock stopped at `date` in `timeZone`.
    public static func fixed(_ date: Date, in timeZone: TimeZone) -> WallClock {
        WallClock(timeZone: timeZone) { date }
    }

    /// A Gregorian calendar in this clock's time zone, for turning dates into
    /// days and months.
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
