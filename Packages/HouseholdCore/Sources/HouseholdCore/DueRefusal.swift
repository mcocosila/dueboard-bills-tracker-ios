import Foundation

/// Why a change to a Due was not made, in words that say what to do instead.
public enum DueRefusal: Error, Equatable, LocalizedError {
    /// The Amount of a Paid Due is locked until Edit undoes Paid.
    case paidNotEditable
    /// An Amount below zero.
    case negativeAmount
    /// A Paid Due is kept in its Billing Month until Edit undoes Paid.
    case paidNotRemovable
    /// No Due has the id given, as when it was removed from its Billing Month meanwhile.
    case noSuchDue

    public var errorDescription: String? {
        switch self {
        case .paidNotEditable: "The Amount of a Paid Due cannot be changed; press Edit first"
        case .negativeAmount: "Amount must be 0 or more"
        case .paidNotRemovable: "A Paid Due cannot be removed; press Edit first"
        case .noSuchDue: "This Due is no longer in its Billing Month"
        }
    }
}
