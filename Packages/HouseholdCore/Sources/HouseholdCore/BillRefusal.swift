import Foundation

/// Why a Bill was not saved or added to a Billing Month, in words that say what to change.
public enum BillRefusal: Error, Equatable, LocalizedError {
    case noName
    case noCategory
    case dueDayOutOfRange
    /// A Retired Bill was to be added to a Billing Month by hand.
    case retired
    /// No Bill has the id given.
    case noSuchBill

    public var errorDescription: String? {
        switch self {
        case .noName: "Enter a name"
        case .noCategory: "Choose a Category"
        case .dueDayOutOfRange: "Day must be 1 to 28"
        case .retired: "A Retired Bill cannot be added; reactivate it first"
        case .noSuchBill: "This Bill no longer exists"
        }
    }
}
