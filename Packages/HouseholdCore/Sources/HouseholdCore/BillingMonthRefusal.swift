import Foundation

/// Why a Billing Month was not opened, in words that say what is allowed.
public enum BillingMonthRefusal: Error, Equatable, LocalizedError {
    /// Two or more months after the current one.
    case tooFarAhead
    /// A month number outside 1 to 12, or a month before the earliest Billing Month.
    case notACalendarMonth

    public var errorDescription: String? {
        switch self {
        case .tooFarAhead: "Only the month after the current one can be opened yet"
        case .notACalendarMonth: "There is no such month"
        }
    }
}
