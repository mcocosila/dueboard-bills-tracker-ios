import Foundation

/// Why a Bill was not saved, in words that say what to change.
public enum BillRefusal: Error, Equatable, LocalizedError {
    case noName
    case noCategory
    case dueDayOutOfRange

    public var errorDescription: String? {
        switch self {
        case .noName: "Enter a name"
        case .noCategory: "Choose a Category"
        case .dueDayOutOfRange: "Day must be 1 to 28"
        }
    }
}
