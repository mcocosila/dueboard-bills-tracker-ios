import Foundation

/// Which of several copies of one record survives once iCloud has brought copies made on
/// different devices together: two devices that open the same Billing Month, or start a
/// Household, before either has seen the other's change each make their own.
///
/// Every device that sees the same copies picks the same survivor, so two devices tidying
/// up at the same time never each delete the copy the other kept. Plain values in, plain
/// values out: no Core Data here, so the choice can be checked on its own.
enum Duplicates {
    /// The copy that stays: the one with the lowest id. Ids are random, so this favours no device.
    static func survivor(among ids: [UUID]) -> UUID? {
        ids.min { $0.uuidString < $1.uuidString }
    }

    /// The Household that stays: the one started first, and of those started at the same
    /// moment, the one with the lowest id.
    static func survivingHousehold(among households: [(id: UUID, startedAt: Date?)]) -> UUID? {
        households.min { left, right in
            let leftStart = left.startedAt ?? .distantFuture
            let rightStart = right.startedAt ?? .distantFuture
            if leftStart != rightStart { return leftStart < rightStart }
            return left.id.uuidString < right.id.uuidString
        }?.id
    }

    /// What one copy of a Due holds that a Member may have changed: its Amount and Paid.
    struct DueCopy: Equatable {
        var id: UUID
        var amount: Decimal?
        var paid: Paid?

        struct Paid: Equatable {
            var at: Date
            var by: String?
            var paidAmount: Decimal?
        }
    }

    /// The surviving copy of a Due, holding what any copy recorded: a Due marked Paid on
    /// either device stays Paid, with the Amount it was paid at, and an Amount entered on
    /// either device is kept. When more than one copy is Paid, the one Paid first counts.
    static func merged(_ copies: [DueCopy]) -> DueCopy? {
        guard let survivorID = survivor(among: copies.map(\.id)),
              var merged = copies.first(where: { $0.id == survivorID })
        else { return nil }
        let byID = copies.sorted { $0.id.uuidString < $1.id.uuidString }
        if let firstPaid = byID.filter({ $0.paid != nil }).min(by: { $0.paid!.at < $1.paid!.at }) {
            merged.amount = firstPaid.amount
            merged.paid = firstPaid.paid
        } else if merged.amount == nil {
            merged.amount = byID.lazy.compactMap(\.amount).first
        }
        return merged
    }
}
