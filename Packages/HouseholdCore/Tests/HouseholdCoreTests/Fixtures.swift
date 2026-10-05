import Foundation
import Testing
import HouseholdCore

extension NewBill {
    /// City Power in the Household's first Category, with no Default Amount; due on the 17th of
    /// the Billing Month itself unless told otherwise.
    static func cityPower(in household: Household, dueDay: Int = 17, dueMonth: DueMonth = .sameMonth) -> NewBill {
        NewBill(
            name: "City Power", categoryID: household.categories[0].id, dueDay: dueDay, dueMonth: dueMonth,
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

    /// Plumber in the Household's first Category, due on the 20th, with no Default Amount: Occasional.
    static func plumber(in household: Household) -> NewBill {
        NewBill(
            name: "Plumber", categoryID: household.categories[0].id, dueDay: 20, dueMonth: .sameMonth,
            defaultAmount: nil, isRecurring: false
        )
    }

    /// Walmart in the Household's third Category, due on the 12th, with a Default Amount of 120.00:
    /// Occasional unless told otherwise.
    static func walmart(in household: Household, recurring: Bool = false) -> NewBill {
        NewBill(
            name: "Walmart", categoryID: household.categories[2].id, dueDay: 12, dueMonth: .sameMonth,
            defaultAmount: Decimal(string: "120.00"), isRecurring: recurring
        )
    }

    /// Visa in the Household's third Category, Credit Cards, due on the 25th, with no Default Amount.
    static func visa(in household: Household) -> NewBill {
        NewBill(
            name: "Visa", categoryID: household.categories[2].id, dueDay: 25, dueMonth: .sameMonth,
            defaultAmount: nil
        )
    }

    /// Mastercard in the Household's third Category, Credit Cards, due on the 22nd, with no Default
    /// Amount.
    static func mastercard(in household: Household) -> NewBill {
        NewBill(
            name: "Mastercard", categoryID: household.categories[2].id, dueDay: 22, dueMonth: .sameMonth,
            defaultAmount: nil
        )
    }

    /// Dance Studio in the Household's second Category, due on the 8th, with a Default Amount of
    /// 200.00: Card-Paid.
    static func danceStudio(in household: Household) -> NewBill {
        NewBill(
            name: "Dance Studio", categoryID: household.categories[1].id, dueDay: 8, dueMonth: .sameMonth,
            defaultAmount: Decimal(string: "200.00"), isCardPaid: true
        )
    }

    /// Water in the Household's first Category, due on the 5th, with no Default Amount.
    static func water(in household: Household) -> NewBill {
        NewBill(
            name: "Water", categoryID: household.categories[0].id, dueDay: 5, dueMonth: .sameMonth,
            defaultAmount: nil
        )
    }
}

extension BillingMonth {
    /// Two months before the current one on the `.testing` clock.
    static let july = BillingMonth(year: 2026, month: 7)
    /// The month before the current one on the `.testing` clock.
    static let august = BillingMonth(year: 2026, month: 8)
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

    /// The Bill named `name`, listed in its Category or with the Retired Bills.
    func bill(named name: String) throws -> Bill {
        try #require((billsList.groups.flatMap(\.bills) + billsList.retired).first { $0.name == name })
    }
}

extension WallClock {
    /// Noon on September 15, 2026 in New York.
    static var testing: WallClock {
        .fixed(Date(timeIntervalSince1970: 1_789_488_000), in: TimeZone(identifier: "America/New_York")!)
    }

    /// A clock stopped at `moment`, written as ISO 8601 in UTC, in the time zone named `timeZone`.
    static func at(_ moment: String, in timeZone: String = "America/New_York") -> WallClock {
        .fixed(ISO8601DateFormatter().date(from: moment)!, in: TimeZone(identifier: timeZone)!)
    }
}
