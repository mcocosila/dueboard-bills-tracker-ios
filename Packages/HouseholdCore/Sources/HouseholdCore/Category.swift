import Foundation

/// A named group of Bills, defined by the Household's members (see CONTEXT.md).
public struct Category: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    /// Where the Category sits in the Household's order of Categories, lowest first.
    public let position: Int

    public init(id: UUID, name: String, position: Int) {
        self.id = id
        self.name = name
        self.position = position
    }

    /// What a new Household starts with, so nobody starts from a blank page.
    static func suggested() -> [Category] {
        ["House", "Education", "Credit Cards"].enumerated().map { position, name in
            Category(id: UUID(), name: name, position: position)
        }
    }
}
