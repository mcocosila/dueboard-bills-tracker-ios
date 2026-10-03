import CoreData
import HouseholdCore

/// Keeps the Household in Core Data on this phone. It maps stored records to
/// and from the core's types and holds no rules of its own.
final class CoreDataHouseholdStore: HouseholdStore {
    private let container: NSPersistentContainer

    /// Opens the store in the app's own storage on this phone.
    init() throws {
        container = NSPersistentContainer(name: "Dueboard")
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    func load() throws -> HouseholdRecords? {
        let context = container.viewContext
        return try context.performAndWait {
            let request = StoredHousehold.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \StoredHousehold.createdAt, ascending: true)]
            request.fetchLimit = 1
            guard let household = try context.fetch(request).first else { return nil }
            let categories = (household.categories as? Set<StoredCategory>) ?? []
            let billingMonths = (household.billingMonths as? Set<StoredBillingMonth>) ?? []
            return HouseholdRecords(
                categories: try categories.map(Category.init),
                bills: try categories.flatMap { ($0.bills as? Set<StoredBill>) ?? [] }.map(Bill.init),
                billingMonths: Set(billingMonths.map(BillingMonth.init)),
                dues: try billingMonths.flatMap { ($0.dues as? Set<StoredDue>) ?? [] }.map(Due.init)
            )
        }
    }

    func start(_ records: HouseholdRecords) throws {
        let context = container.viewContext
        try context.performAndWait {
            let household = StoredHousehold(context: context)
            household.createdAt = .now
            for category in records.categories {
                let stored = StoredCategory(context: context)
                stored.id = category.id
                stored.name = category.name
                stored.position = Int64(category.position)
                stored.household = household
            }
            try context.save()
        }
    }

    func insert(_ bill: Bill) throws {
        let context = container.viewContext
        try context.performAndWait {
            let request = StoredCategory.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", bill.categoryID as CVarArg)
            guard let category = try context.fetch(request).first else { throw DamagedRecord(entity: "Category") }
            let stored = StoredBill(context: context)
            stored.id = bill.id
            stored.name = bill.name
            stored.category = category
            stored.dueDay = Int16(bill.dueDay.day)
            stored.dueMonth = bill.dueDay.month.rawValue
            stored.defaultAmount = bill.defaultAmount.map { NSDecimalNumber(decimal: $0) }
            stored.isRecurring = bill.isRecurring
            stored.position = Int64(bill.position)
            try context.save()
        }
    }

    func open(_ month: BillingMonth, with dues: [Due]) throws {
        let context = container.viewContext
        try context.performAndWait {
            let households = StoredHousehold.fetchRequest()
            households.sortDescriptors = [NSSortDescriptor(keyPath: \StoredHousehold.createdAt, ascending: true)]
            households.fetchLimit = 1
            guard let household = try context.fetch(households).first else { throw DamagedRecord(entity: "Household") }
            let bills = Dictionary(
                uniqueKeysWithValues: try context.fetch(StoredBill.fetchRequest()).compactMap { bill in bill.id.map { ($0, bill) } }
            )
            let categories = Dictionary(
                uniqueKeysWithValues: try context.fetch(StoredCategory.fetchRequest()).compactMap { category in
                    category.id.map { ($0, category) }
                }
            )
            let storedMonth = StoredBillingMonth(context: context)
            storedMonth.year = Int32(month.year)
            storedMonth.month = Int16(month.month)
            storedMonth.household = household
            for due in dues {
                guard let bill = bills[due.billID] else { throw DamagedRecord(entity: "Bill") }
                guard let category = categories[due.categoryID] else { throw DamagedRecord(entity: "Category") }
                let stored = StoredDue(context: context)
                stored.id = due.id
                stored.name = due.name
                stored.position = Int64(due.position)
                stored.dueDate = due.dueDate.stored
                stored.amount = due.amount.map { NSDecimalNumber(decimal: $0) }
                stored.bill = bill
                stored.category = category
                stored.billingMonth = storedMonth
            }
            do {
                try context.save()
            } catch {
                // All or nothing: a month half saved would be opened again with only some of its Dues.
                context.rollback()
                throw error
            }
        }
    }
}

/// A stored record is missing something every record of its kind has. The store
/// refuses to open rather than guess what it held.
struct DamagedRecord: LocalizedError {
    let entity: String

    var errorDescription: String? { "A stored \(entity) is incomplete." }
}

private extension HouseholdCore.Category {
    init(_ stored: StoredCategory) throws {
        guard let id = stored.id, let name = stored.name else { throw DamagedRecord(entity: "Category") }
        self.init(id: id, name: name, position: Int(stored.position))
    }
}

private extension Bill {
    init(_ stored: StoredBill) throws {
        guard let id = stored.id, let name = stored.name, let categoryID = stored.category?.id,
              let dueMonth = stored.dueMonth.flatMap(DueMonth.init(rawValue:))
        else { throw DamagedRecord(entity: "Bill") }
        self.init(
            id: id,
            name: name,
            categoryID: categoryID,
            dueDay: DueDay(day: Int(stored.dueDay), month: dueMonth),
            defaultAmount: stored.defaultAmount?.decimalValue,
            isRecurring: stored.isRecurring,
            position: Int(stored.position)
        )
    }
}

private extension BillingMonth {
    init(_ stored: StoredBillingMonth) {
        self.init(year: Int(stored.year), month: Int(stored.month))
    }
}

private extension Due {
    init(_ stored: StoredDue) throws {
        guard let id = stored.id, let name = stored.name, let billID = stored.bill?.id,
              let categoryID = stored.category?.id, let month = stored.billingMonth, let dueDate = stored.dueDate.flatMap(DueDate.init(stored:))
        else { throw DamagedRecord(entity: "Due") }
        self.init(
            id: id,
            billID: billID,
            billingMonth: BillingMonth(month),
            name: name,
            categoryID: categoryID,
            position: Int(stored.position),
            dueDate: dueDate,
            amount: stored.amount?.decimalValue
        )
    }
}

private extension DueDate {
    /// Kept as text, "2026-09-01": a day on the calendar, the same in every time zone.
    var stored: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    init?(stored: String) {
        let parts = stored.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }
}
