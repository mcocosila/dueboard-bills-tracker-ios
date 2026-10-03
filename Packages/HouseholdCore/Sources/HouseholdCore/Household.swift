/// The shared set of Categories, Bills and Billing Months, and the only thing
/// the screens talk to.
public struct Household: Sendable {
    private let clock: WallClock

    public init(clock: WallClock) {
        self.clock = clock
    }

    /// The Billing Month that "now" falls in, in the clock's time zone.
    public var currentBillingMonth: BillingMonth {
        let parts = clock.calendar.dateComponents([.year, .month], from: clock.now)
        return BillingMonth(year: parts.year!, month: parts.month!)
    }
}
