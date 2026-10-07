import Foundation

/// A named group of Bills, one of the Household's own (see GLOSSARY.md).
public struct Category: Hashable, Identifiable, Sendable {
    public let id: UUID
    public internal(set) var name: String
    /// Where the Category sits in the Household's order of Categories, lowest first.
    public internal(set) var position: Int

    public init(id: UUID, name: String, position: Int) {
        self.id = id
        self.name = name
        self.position = position
    }

    /// The name of the Category whose Bills are credit cards.
    static let creditCards = "Credit Cards"

    /// Whether this is the Credit Cards Category, whose Bills are credit cards and whose Dues
    /// take a Paid Amount. Named so whatever the case, as Category names are unique whatever the case.
    public var isCreditCards: Bool { name.caseInsensitiveCompare(Self.creditCards) == .orderedSame }

    /// What a new Household starts with, so nobody starts from a blank page.
    static func suggested() -> [Category] {
        ["House", "Education", creditCards].enumerated().map { position, name in
            Category(id: UUID(), name: name, position: position)
        }
    }
}
