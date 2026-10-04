import Foundation

/// The one number shown per Billing Month (see CONTEXT.md), and how many Dues it
/// cannot count yet.
public struct UnpaidRemaining: Hashable, Sendable {
    /// The sum of the Amounts on the Dues that are not Paid.
    public let amount: Decimal
    /// How many of the Dues that are not Paid have no Amount yet.
    public let withoutAmount: Int

    public init(amount: Decimal, withoutAmount: Int) {
        self.amount = amount
        self.withoutAmount = withoutAmount
    }

    init(of dues: [Due]) {
        let owed = dues.filter { $0.paid == nil }
        self.init(amount: owed.compactMap(\.amount).reduce(0, +), withoutAmount: owed.filter { $0.amount == nil }.count)
    }
}
