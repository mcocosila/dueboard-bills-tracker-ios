/// The Bills, grouped by Category in Category order, as the Bills list shows them.
public struct BillsList: Sendable {
    public struct Group: Identifiable, Sendable {
        public let category: Category
        /// In their order within the Category.
        public let bills: [Bill]

        public var id: Category.ID { category.id }
        /// How many Bills the Category holds.
        public var count: Int { bills.count }
    }

    public let groups: [Group]
}
