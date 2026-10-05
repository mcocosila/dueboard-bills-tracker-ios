import Foundation

/// Why a Category was not created, renamed, reordered or deleted, in words that say what to do instead.
public enum CategoryRefusal: Error, Equatable, LocalizedError {
    case noName
    /// Another Category of the Household already has the name, whatever the case.
    case nameTaken(String)
    /// Credit Cards was to get another name, which would leave its Bills no longer credit cards.
    case creditCardsRenamed
    /// The Category to delete still holds this many Bills, Retired ones counted.
    case holdsBills(category: String, count: Int)
    /// The Category to delete holds no Bills but still holds Dues, generated before their Bills moved
    /// to another Category.
    case holdsDues(category: String)
    /// The order given is not every Category once each, as when one was created or deleted meanwhile.
    case categoriesChanged
    /// No Category has the id given.
    case noSuchCategory

    public var errorDescription: String? {
        switch self {
        case .noName: "Enter a name"
        case .nameTaken(let name): "There is already a Category named \(name)"
        case .creditCardsRenamed: "Credit Cards cannot be renamed; its name is what makes its Bills credit cards"
        case .holdsBills(let category, 1): "\(category) still holds 1 Bill; move it to another Category first"
        case .holdsBills(let category, let count):
            "\(category) still holds \(count) Bills; move them to another Category first"
        case .holdsDues(let category): "\(category) still holds Dues of past Billing Months, so it is kept"
        case .categoriesChanged: "The Categories changed meanwhile; try again"
        case .noSuchCategory: "This Category no longer exists"
        }
    }
}
