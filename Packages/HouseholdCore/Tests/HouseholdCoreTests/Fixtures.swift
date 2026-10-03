import Foundation
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
}

extension WallClock {
    /// Noon on September 15, 2026 in New York.
    static var testing: WallClock {
        .fixed(Date(timeIntervalSince1970: 1_789_488_000), in: TimeZone(identifier: "America/New_York")!)
    }
}
