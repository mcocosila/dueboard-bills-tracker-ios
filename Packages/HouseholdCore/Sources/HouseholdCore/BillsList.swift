/// The Bills, grouped by Category in Category order, as the Bills list shows them,
/// with the Retired Bills apart after the Categories.
public struct BillsList: Sendable {
    public struct Group: Identifiable, Sendable {
        public let category: Category
        /// The Bills not Retired, in their order within the Category.
        public let bills: [Bill]

        public var id: Category.ID { category.id }
        /// How many Bills not Retired the Category holds.
        public var count: Int { bills.count }
    }

    public let groups: [Group]
    /// The Retired Bills, in Category order and their order within each.
    public let retired: [Bill]

    init(bills: [Bill], categories: [Category]) {
        let byCategory = categories.map { category in
            bills.filter { $0.categoryID == category.id }.sorted { $0.position < $1.position }
        }
        groups = zip(categories, byCategory).map { category, bills in
            Group(category: category, bills: bills.filter { !$0.isRetired })
        }
        retired = byCategory.flatMap { $0.filter(\.isRetired) }
    }
}
