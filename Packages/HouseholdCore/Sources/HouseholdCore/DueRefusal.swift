import Foundation

/// Why a change to a Due was not made, in words that say what to do instead.
public enum DueRefusal: Error, Equatable, LocalizedError {
    /// The Amount of a Paid Due is locked until Edit undoes Paid.
    case paidNotEditable
    case negativeAmount
    /// No Due has the id given, as when it was removed from its Billing Month meanwhile.
    case noSuchDue

    public var errorDescription: String? {
        switch self {
        case .paidNotEditable: "A Paid Due's Amount cannot be changed; press Edit first"
        case .negativeAmount: "Amount must be 0 or more"
        case .noSuchDue: "This Due is no longer in its Billing Month"
        }
    }
}
