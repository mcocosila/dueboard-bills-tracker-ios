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
            return HouseholdRecords(
                categories: try categories.map(Category.init),
                bills: try categories.flatMap { ($0.bills as? Set<StoredBill>) ?? [] }.map(Bill.init)
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
