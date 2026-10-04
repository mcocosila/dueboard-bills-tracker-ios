import Foundation
import Testing
import HouseholdCore

extension NewBill {
    /// City Power in the Household's first Category, with no Default Amount.
    static func cityPower(in household: Household, dueDay: Int = 17) -> NewBill {
        NewBill(
            name: "City Power", categoryID: household.categories[0].id, dueDay: dueDay, dueMonth: .sameMonth,
            defaultAmount: nil
        )
    }

    /// Riverside School in the Household's second Category: paid in one month, due on the 1st of the next,
    /// with a Default Amount of 450.00.
    static func riversideSchool(in household: Household) -> NewBill {
        NewBill(
            name: "Riverside School", categoryID: household.categories[1].id, dueDay: 1, dueMonth: .nextMonth,
            defaultAmount: Decimal(string: "450.00")
        )
    }

    /// Mortgage in the Household's first Category, due on the 10th, with a Default Amount of 3500.00.
    static func mortgage(in household: Household) -> NewBill {
        NewBill(
            name: "Mortgage", categoryID: household.categories[0].id, dueDay: 10, dueMonth: .sameMonth,
            defaultAmount: Decimal(string: "3500.00")
        )
    }

    /// Home Depot in the Household's third Category, due on the 20th, with the Default Amount given.
    static func homeDepot(in household: Household, defaultAmount: Decimal?) -> NewBill {
        NewBill(
            name: "Home Depot", categoryID: household.categories[2].id, dueDay: 20, dueMonth: .sameMonth,
            defaultAmount: defaultAmount
        )
    }
}

extension BillingMonth {
    /// The current Billing Month on the `.testing` clock.
    static let september = BillingMonth(year: 2026, month: 9)
    /// The month after the current one on the `.testing` clock, the latest that can be opened.
    static let october = BillingMonth(year: 2026, month: 10)
}

extension Household {
    /// The Due generated for the Bill named `name` in `month`, opening the month if need be.
    mutating func due(named name: String, in month: BillingMonth = .september) throws -> Due {
        try #require(try openBillingMonth(month).dues.first { $0.name == name })
    }
}

extension WallClock {
    /// Noon on September 15, 2026 in New York.
    static var testing: WallClock {
        .fixed(Date(timeIntervalSince1970: 1_789_488_000), in: TimeZone(identifier: "America/New_York")!)
    }
}
