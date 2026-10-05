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
            guard let household = try firstHousehold(in: context) else { return nil }
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
            stored.position = Int64(bill.position)
            stored.keep(detailsOf: bill, in: category)
            try context.save()
        }
    }

    func update(_ bill: Bill) throws {
        let context = container.viewContext
        try context.performAndWait {
            do {
                let stored = try record(StoredBill.fetchRequest(), withID: bill.id, entity: "Bill", in: context)
                let category = try record(
                    StoredCategory.fetchRequest(), withID: bill.categoryID, entity: "Category", in: context
                )
                stored.keep(detailsOf: bill, in: category)
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    func open(_ month: BillingMonth, with dues: [Due]) throws {
        let context = container.viewContext
        try context.performAndWait {
            do {
                guard let household = try firstHousehold(in: context) else { throw DamagedRecord(entity: "Household") }
                let bills = try byID(StoredBill.fetchRequest(), \.id, in: context)
                let categories = try byID(StoredCategory.fetchRequest(), \.id, in: context)
                let storedMonth = StoredBillingMonth(context: context)
                storedMonth.year = Int32(month.year)
                storedMonth.month = Int16(month.month)
                storedMonth.household = household
                for due in dues {
                    guard let bill = bills[due.billID] else { throw DamagedRecord(entity: "Bill") }
                    guard let category = categories[due.categoryID] else { throw DamagedRecord(entity: "Category") }
                    StoredDue(context: context).keep(due, of: bill, in: category, month: storedMonth)
                }
                try context.save()
            } catch {
                // All or nothing: a month left half made in the context would be saved by the next
                // command, and the month would then stay open with only some of its Dues.
                context.rollback()
                throw error
            }
        }
    }

    func insert(_ due: Due) throws {
        let context = container.viewContext
        try context.performAndWait {
            do {
                let request = StoredBillingMonth.fetchRequest()
                request.predicate = NSPredicate(
                    format: "year == %d AND month == %d", due.billingMonth.year, due.billingMonth.month
                )
                guard let month = try context.fetch(request).first else { throw DamagedRecord(entity: "Billing Month") }
                let bill = try record(StoredBill.fetchRequest(), withID: due.billID, entity: "Bill", in: context)
                let category = try record(
                    StoredCategory.fetchRequest(), withID: due.categoryID, entity: "Category", in: context
                )
                StoredDue(context: context).keep(due, of: bill, in: category, month: month)
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    func update(_ due: Due) throws {
        let context = container.viewContext
        try context.performAndWait {
            do {
                let stored = try record(StoredDue.fetchRequest(), withID: due.id, entity: "Due", in: context)
                stored.keep(amountAndPaidOf: due)
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    func delete(_ dueID: Due.ID) throws {
        let context = container.viewContext
        try context.performAndWait {
            do {
                let request = StoredDue.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", dueID as CVarArg)
                for stored in try context.fetch(request) {
                    context.delete(stored)
                }
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    /// The Household this phone keeps: the first one started, should there ever be more.
    private func firstHousehold(in context: NSManagedObjectContext) throws -> StoredHousehold? {
        let request = StoredHousehold.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \StoredHousehold.createdAt, ascending: true)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// The record of `entity` with `id`, the first should two share it.
    private func record<Record: NSManagedObject>(
        _ request: NSFetchRequest<Record>, withID id: UUID, entity: String, in context: NSManagedObjectContext
    ) throws -> Record {
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        guard let record = try context.fetch(request).first else { throw DamagedRecord(entity: entity) }
        return record
    }

    /// Every record the request fetches, by id. The model can have no unique
    /// constraints (CloudKit allows none), so two records sharing an id keep the first.
    private func byID<Record>(
        _ request: NSFetchRequest<Record>, _ id: KeyPath<Record, UUID?>, in context: NSManagedObjectContext
    ) throws -> [UUID: Record] {
        Dictionary(
            try context.fetch(request).compactMap { record in record[keyPath: id].map { ($0, record) } },
            uniquingKeysWith: { first, _ in first }
        )
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
            isCardPaid: stored.isCardPaid,
            isRetired: stored.isRetired,
            position: Int(stored.position)
        )
    }
}

private extension StoredBill {
    /// Takes the Bill's details, Recurring, Card-Paid and Retired, the parts of a Bill that change
    /// after it is added.
    func keep(detailsOf bill: Bill, in category: StoredCategory) {
        name = bill.name
        self.category = category
        dueDay = Int16(bill.dueDay.day)
        dueMonth = bill.dueDay.month.rawValue
        defaultAmount = bill.defaultAmount.map { NSDecimalNumber(decimal: $0) }
        isRecurring = bill.isRecurring
        isCardPaid = bill.isCardPaid
        isRetired = bill.isRetired
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
            isCardPaid: stored.isCardPaid,
            amount: stored.amount?.decimalValue,
            paid: stored.paidAt.map { Due.Paid(at: $0, by: stored.paidBy, paidAmount: stored.paidAmount?.decimalValue) }
        )
    }
}

private extension StoredDue {
    /// Takes all of a new Due, tied to its Bill, Category and Billing Month.
    func keep(_ due: Due, of bill: StoredBill, in category: StoredCategory, month: StoredBillingMonth) {
        id = due.id
        name = due.name
        position = Int64(due.position)
        dueDate = due.dueDate.stored
        isCardPaid = due.isCardPaid
        keep(amountAndPaidOf: due)
        self.bill = bill
        self.category = category
        billingMonth = month
    }

    /// Takes the Due's Amount and Paid, the parts of a Due that change after it is generated.
    func keep(amountAndPaidOf due: Due) {
        amount = due.amount.map { NSDecimalNumber(decimal: $0) }
        paidAt = due.paid?.at
        paidBy = due.paid?.by
        paidAmount = due.paid?.paidAmount.map { NSDecimalNumber(decimal: $0) }
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
