import Foundation

/// Why a Bill was not saved, in words a member can act on.
public enum BillRefusal: Error, Equatable, LocalizedError {
    case noName
    case dueDayOutOfRange

    public var errorDescription: String? {
        switch self {
        case .noName: "Enter a name"
        case .dueDayOutOfRange: "Day must be 1 to 28"
        }
    }
}
