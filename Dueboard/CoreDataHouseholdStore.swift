import CloudKit
import CoreData
import HouseholdCore

/// Keeps the Household in Core Data on this phone and syncs it through the Members'
/// iCloud. It maps stored records to and from the core's types and holds no rules of
/// its own.
///
/// Each CloudKit database the Household can live in is a store of its own on the phone:
/// the private store, mirrored to this Member's private database, holds the Household
/// started on this phone, shared or not; the shared store, mirrored to the shared
/// database, holds a Household this Member was invited to. Every new record goes into the
/// store of the record it belongs to, since a relationship cannot cross stores. Sharing
/// itself is in `CoreDataHouseholdStore+Sharing.swift`.
///
/// Works on the main actor, with the container's view context, as the screens do.
@MainActor
final class CoreDataHouseholdStore: @MainActor HouseholdStore {
    /// The iCloud container the Household syncs through, the same for every build.
    static let iCloudContainer = "iCloud.com.neodonis.dueboard"
    /// Who made a change, as the store's history records it: this app's own commands, as
    /// opposed to the changes iCloud brings in from other devices.
    private static let author = "app"

    let container: NSPersistentCloudKitContainer
    /// The store mirrored to the Member's private CloudKit database, where a Household
    /// started on this phone is kept, also once it is shared.
    let privateStore: NSPersistentStore
    /// The store mirrored to the Member's shared CloudKit database, where the Household of
    /// an invite this Member accepted is kept.
    let sharedStore: NSPersistentStore
    /// How far this phone has read the store's history, to tell a change from another
    /// device from one of its own.
    private var historyRead: NSPersistentHistoryToken?
    private var remoteChanges: (any NSObjectProtocol)?
    /// Called on the main thread once a change from another device has been taken in, and
    /// any duplicates it brought have been merged.
    var changedElsewhere: (@MainActor () -> Void)?

    /// Opens the stores in the app's own storage on this phone, syncing with the Member's
    /// private and shared iCloud databases. Signed out of iCloud, they work the same on this
    /// phone alone, and what was saved meanwhile syncs once the Member signs in.
    init() throws {
        container = NSPersistentCloudKitContainer(name: "Dueboard")
        // The private store stays where it was before sync, so the Household already on the
        // phone is the one that starts syncing.
        let privateDescription = container.persistentStoreDescriptions[0]
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.iCloudContainer)
        privateOptions.databaseScope = .private
        privateDescription.cloudKitContainerOptions = privateOptions

        // The shared store sits beside it, with the same options but the shared database.
        guard let privateURL = privateDescription.url,
              let sharedDescription = privateDescription.copy() as? NSPersistentStoreDescription
        else { throw DamagedRecord(entity: "store") }
        let sharedURL = privateURL.deletingLastPathComponent().appending(path: "Dueboard-shared.sqlite")
        sharedDescription.url = sharedURL
        let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.iCloudContainer)
        sharedOptions.databaseScope = .shared
        sharedDescription.cloudKitContainerOptions = sharedOptions
        container.persistentStoreDescriptions.append(sharedDescription)

        var loadError: (any Error)?
        container.loadPersistentStores { _, error in
            if let error { loadError = error }
        }
        if let loadError { throw loadError }
        let coordinator = container.persistentStoreCoordinator
        guard let privateStore = coordinator.persistentStore(for: privateURL),
              let sharedStore = coordinator.persistentStore(for: sharedURL)
        else { throw DamagedRecord(entity: "store") }
        self.privateStore = privateStore
        self.sharedStore = sharedStore
        #if DEBUG
        // Run once from Xcode, signed in to iCloud, with this launch argument, to create every record
        // type and field of the model in CloudKit's Development environment, ready to deploy to
        // Production. Saving records creates only the fields they hold a value for.
        if ProcessInfo.processInfo.arguments.contains("-initializeCloudKitSchema") {
            try container.initializeCloudKitSchema(options: [])
        }
        #endif

        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        // A field changed on this phone wins over the same field changed elsewhere meanwhile.
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.transactionAuthor = Self.author
        historyRead = container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: nil)

        try mergeDuplicates()
        remoteChanges = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.takeInChangesFromElsewhere() }
        }
    }

    isolated deinit {
        remoteChanges.map(NotificationCenter.default.removeObserver)
    }

    /// Reads the history written since last time. When some of it came from another device,
    /// merges the duplicates it may have brought and says so.
    private func takeInChangesFromElsewhere() {
        let context = container.viewContext
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: historyRead)
        guard let result = try? context.execute(request) as? NSPersistentHistoryResult,
              let transactions = result.result as? [NSPersistentHistoryTransaction]
        else { return }
        if let last = transactions.last { historyRead = last.token }
        purgeHistoryRead()
        guard transactions.contains(where: { $0.author != Self.author }) else { return }
        _ = try? mergeDuplicates()
        changedElsewhere?()
    }

    /// Deletes history this phone is done with, so it does not grow for good. Only what is a
    /// week old goes: the phone reads history as it is written, from launch on, so nothing
    /// that old is still to be read, and the iCloud mirroring, which reads the same history to
    /// send this phone's changes, has had time to send them. Deleting right up to the last
    /// change read could take changes it has not sent yet, made while offline, and have it
    /// sync everything again.
    private func purgeHistoryRead() {
        let weekAgo = Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
        _ = try? container.viewContext.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: weekAgo))
    }

    func load() throws -> HouseholdRecords? {
        let context = container.viewContext
        guard let household = try shownHousehold(in: context) else { return nil }
        let categories = (household.categories as? Set<StoredCategory>) ?? []
        let billingMonths = (household.billingMonths as? Set<StoredBillingMonth>) ?? []
        return HouseholdRecords(
            categories: try categories.map(Category.init),
            bills: try categories.flatMap { ($0.bills as? Set<StoredBill>) ?? [] }.map(Bill.init),
            billingMonths: Set(billingMonths.map(BillingMonth.init)),
            dues: try billingMonths.flatMap { ($0.dues as? Set<StoredDue>) ?? [] }.map(Due.init)
        )
    }

    func start(_ records: HouseholdRecords) throws {
        let context = container.viewContext
        let household = StoredHousehold.new(in: privateStore, context: context)
        household.id = UUID()
        household.createdAt = .now
        for category in records.categories {
            let stored = StoredCategory.new(in: privateStore, context: context)
            stored.id = category.id
            stored.household = household
            stored.keep(category)
        }
        try context.save()
    }

    func insert(_ category: HouseholdCore.Category) throws {
        let context = container.viewContext
        do {
            guard let household = try shownHousehold(in: context) else { throw DamagedRecord(entity: "Household") }
            let stored = StoredCategory.new(beside: household, in: context)
            stored.id = category.id
            stored.household = household
            stored.keep(category)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func update(_ categories: [HouseholdCore.Category]) throws {
        let context = container.viewContext
        do {
            for category in categories {
                try record(StoredCategory.fetchRequest(), withID: category.id, entity: "Category", in: context)
                    .keep(category)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteCategory(_ categoryID: HouseholdCore.Category.ID) throws {
        let context = container.viewContext
        do {
            let request = StoredCategory.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryID as CVarArg)
            request.affectedStores = [try shownStore(in: context)]
            for stored in try context.fetch(request) {
                context.delete(stored)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func insert(_ bill: Bill) throws {
        let context = container.viewContext
        let category = try record(
            StoredCategory.fetchRequest(), withID: bill.categoryID, entity: "Category", in: context
        )
        let stored = StoredBill.new(beside: category, in: context)
        stored.id = bill.id
        stored.position = Int64(bill.position)
        stored.keep(detailsOf: bill, in: category)
        try context.save()
    }

    func update(_ bill: Bill) throws {
        let context = container.viewContext
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

    func open(_ month: BillingMonth, with dues: [Due]) throws {
        let context = container.viewContext
        do {
            guard let household = try shownHousehold(in: context) else { throw DamagedRecord(entity: "Household") }
            let bills = try byID(StoredBill.fetchRequest(), \.id, in: context)
            let categories = try byID(StoredCategory.fetchRequest(), \.id, in: context)
            let storedMonth = StoredBillingMonth.new(beside: household, in: context)
            storedMonth.id = UUID()
            storedMonth.year = Int32(month.year)
            storedMonth.month = Int16(month.month)
            storedMonth.household = household
            for due in dues {
                guard let bill = bills[due.billID] else { throw DamagedRecord(entity: "Bill") }
                guard let category = categories[due.categoryID] else { throw DamagedRecord(entity: "Category") }
                StoredDue.new(beside: household, in: context).keep(due, of: bill, in: category, month: storedMonth)
            }
            try context.save()
        } catch {
            // All or nothing: a month left half made in the context would be saved by the next
            // command, and the month would then stay open with only some of its Dues.
            context.rollback()
            throw error
        }
        mergeDuplicatesMadeHere()
    }

    func insert(_ due: Due) throws {
        let context = container.viewContext
        do {
            guard let household = try shownHousehold(in: context) else { throw DamagedRecord(entity: "Household") }
            let request = StoredBillingMonth.fetchRequest()
            request.predicate = NSPredicate(
                format: "household == %@ AND year == %d AND month == %d",
                household, due.billingMonth.year, due.billingMonth.month
            )
            request.affectedStores = [household.objectID.persistentStore ?? privateStore]
            guard let month = try context.fetch(request).first else { throw DamagedRecord(entity: "Billing Month") }
            let bill = try record(StoredBill.fetchRequest(), withID: due.billID, entity: "Bill", in: context)
            let category = try record(
                StoredCategory.fetchRequest(), withID: due.categoryID, entity: "Category", in: context
            )
            StoredDue.new(beside: month, in: context).keep(due, of: bill, in: category, month: month)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        mergeDuplicatesMadeHere()
    }

    func update(_ due: Due) throws {
        let context = container.viewContext
        do {
            let stored = try record(StoredDue.fetchRequest(), withID: due.id, entity: "Due", in: context)
            stored.keep(amountAndPaidOf: due)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(_ dueID: Due.ID) throws {
        let context = container.viewContext
        do {
            let request = StoredDue.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", dueID as CVarArg)
            request.affectedStores = [try shownStore(in: context)]
            for stored in try context.fetch(request) {
                context.delete(stored)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Merges the copies of one record that devices made before they saw each other's change,
    /// so the core never sees two: a Household started on a new device before the Household
    /// already in iCloud arrived, with its suggested Categories, and a Billing Month opened on
    /// two devices at once, with a Due per Bill on each. Every device picks the same copy to
    /// keep (see `Duplicates`), moves what hangs off the others onto it, and deletes the others.
    /// Returns whether there was anything to merge.
    @discardableResult
    private func mergeDuplicates() throws -> Bool {
        let context = container.viewContext
        do {
            for store in container.persistentStoreCoordinator.persistentStores {
                try mergeDuplicates(in: store, context: context)
            }
            guard context.hasChanges else { return false }
            try context.save()
            return true
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Merges a duplicate this phone has just made itself: a Billing Month opened, or a Due
    /// added, here after the same arrived from another device but before the Household was
    /// read again. Runs once the command that made it has finished, then has the Household
    /// read again, since the copy it holds may be the one merged away.
    private func mergeDuplicatesMadeHere() {
        Task { @MainActor [weak self] in
            guard let self, (try? mergeDuplicates()) == true else { return }
            changedElsewhere?()
        }
    }

    /// Merges the duplicates within one store; records in different stores belong to
    /// different Households and are never merged.
    ///
    /// In the private store every Household is this Member's own, so two of them are copies
    /// made on two devices before they synced, and become one. In the shared store each
    /// Household came with its own invite, from its own owner: they are never merged, and
    /// only the copies within each are. A Member is in one at a time, but one left behind by
    /// an invite that is still being taken away must not swallow the next.
    private func mergeDuplicates(in store: NSPersistentStore, context: NSManagedObjectContext) throws {
        func all<Record: NSManagedObject>(_ request: NSFetchRequest<Record>) throws -> [Record] {
            request.affectedStores = [store]
            return try context.fetch(request)
        }

        let households = try all(StoredHousehold.fetchRequest())
        for household in households where household.id == nil { household.id = UUID() }
        guard store == privateStore else {
            for household in households { mergeDuplicates(within: household, context: context) }
            return
        }
        guard let keptID = Duplicates.survivingHousehold(among: households.map { ($0.id!, $0.createdAt) }),
              let household = households.first(where: { $0.id == keptID })
        else { return }
        for other in households where other != household {
            for category in other.categories as? Set<StoredCategory> ?? [] { category.household = household }
            for month in other.billingMonths as? Set<StoredBillingMonth> ?? [] { month.household = household }
            context.delete(other)
        }
        // A record whose Household was merged away on another device arrives with none.
        for category in try all(StoredCategory.fetchRequest()) where category.household == nil {
            category.household = household
        }
        for month in try all(StoredBillingMonth.fetchRequest()) where month.household == nil {
            month.household = household
        }
        mergeDuplicates(within: household, context: context)
    }

    /// Merges the copies within one Household: one Category per name, one Billing Month per
    /// month, one Due per Bill per Billing Month.
    private func mergeDuplicates(within household: StoredHousehold, context: NSManagedObjectContext) {
        // Category names are unique whatever the case, so two of the same name are one Category.
        let categories = (household.categories as? Set<StoredCategory> ?? []).filter { $0.id != nil }
        for copies in Dictionary(grouping: categories, by: { $0.name?.lowercased() ?? "" }).values where copies.count > 1 {
            guard let keptID = Duplicates.survivor(among: copies.compactMap(\.id)),
                  let kept = copies.first(where: { $0.id == keptID })
            else { continue }
            for other in copies where other != kept {
                for bill in other.bills as? Set<StoredBill> ?? [] { bill.category = kept }
                for due in other.dues as? Set<StoredDue> ?? [] { due.category = kept }
                context.delete(other)
            }
        }

        let months = household.billingMonths as? Set<StoredBillingMonth> ?? []
        for month in months where month.id == nil { month.id = UUID() }
        for copies in Dictionary(grouping: months, by: { BillingMonth($0) }).values where copies.count > 1 {
            guard let keptID = Duplicates.survivor(among: copies.compactMap(\.id)),
                  let kept = copies.first(where: { $0.id == keptID })
            else { continue }
            for other in copies where other != kept {
                for due in other.dues as? Set<StoredDue> ?? [] { due.billingMonth = kept }
                context.delete(other)
            }
        }

        // At most one Due per Bill per Billing Month.
        for month in household.billingMonths as? Set<StoredBillingMonth> ?? [] {
            let dues = (month.dues as? Set<StoredDue> ?? []).filter { $0.id != nil && $0.bill?.id != nil }
            for copies in Dictionary(grouping: dues, by: { $0.bill!.id! }).values where copies.count > 1 {
                guard let merged = Duplicates.merged(copies.map(\.copy)),
                      let kept = copies.first(where: { $0.id == merged.id })
                else { continue }
                if kept.copy != merged { kept.keep(merged) }
                for other in copies where other != kept { context.delete(other) }
            }
        }
    }

    /// The Household this phone shows, since a Member has one Household at a time: the one
    /// they were invited to, while they are in it, or else their own. Their own stays in
    /// their iCloud meanwhile, and shows again once they leave or the owner stops sharing.
    func shownHousehold(in context: NSManagedObjectContext) throws -> StoredHousehold? {
        try firstHousehold(in: sharedStore, context: context) ?? firstHousehold(in: privateStore, context: context)
    }

    /// The store of the Household this phone shows, where every record a command reads or
    /// changes is: a copy of a record in the other store belongs to the other Household.
    private func shownStore(in context: NSManagedObjectContext) throws -> NSPersistentStore {
        try shownHousehold(in: context)?.objectID.persistentStore ?? privateStore
    }

    /// The first Household started of those in `store`, should there ever be more.
    private func firstHousehold(in store: NSPersistentStore, context: NSManagedObjectContext) throws -> StoredHousehold? {
        let request = StoredHousehold.fetchRequest()
        request.affectedStores = [store]
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \StoredHousehold.createdAt, ascending: true),
            NSSortDescriptor(keyPath: \StoredHousehold.id, ascending: true),
        ]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// The record of `entity` with `id` in the shown Household's store, the first should two
    /// share it.
    private func record<Record: NSManagedObject>(
        _ request: NSFetchRequest<Record>, withID id: UUID, entity: String, in context: NSManagedObjectContext
    ) throws -> Record {
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.affectedStores = [try shownStore(in: context)]
        guard let record = try context.fetch(request).first else { throw DamagedRecord(entity: entity) }
        return record
    }

    /// Every record the request fetches from the shown Household's store, by id. The model can
    /// have no unique constraints (CloudKit allows none), so two records sharing an id keep the
    /// first.
    private func byID<Record>(
        _ request: NSFetchRequest<Record>, _ id: KeyPath<Record, UUID?>, in context: NSManagedObjectContext
    ) throws -> [UUID: Record] {
        request.affectedStores = [try shownStore(in: context)]
        return Dictionary(
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

private extension StoredCategory {
    /// Takes the Category's name and position, the parts of a Category that change after it is created.
    func keep(_ category: HouseholdCore.Category) {
        name = category.name
        position = Int64(category.position)
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

private extension StoredDue {
    /// The Amount and Paid this copy of the Due holds, to be merged with other copies.
    var copy: Duplicates.DueCopy {
        Duplicates.DueCopy(
            id: id ?? UUID(),
            amount: amount?.decimalValue,
            paid: paidAt.map { Duplicates.DueCopy.Paid(at: $0, by: paidBy, paidAmount: paidAmount?.decimalValue) }
        )
    }

    /// Takes the Amount and Paid merged from every copy of the Due.
    func keep(_ merged: Duplicates.DueCopy) {
        amount = merged.amount.map { NSDecimalNumber(decimal: $0) }
        paidAt = merged.paid?.at
        paidBy = merged.paid?.by
        paidAmount = merged.paid?.paidAmount.map { NSDecimalNumber(decimal: $0) }
    }
}

private extension NSManagedObject {
    /// A new record in the store of `owner`, a saved record it will belong to: a relationship
    /// cannot cross stores, and the store decides which iCloud database the record syncs to.
    static func new(beside owner: NSManagedObject, in context: NSManagedObjectContext) -> Self {
        new(in: owner.objectID.persistentStore, context: context)
    }

    /// A new record in `store`.
    static func new(in store: NSPersistentStore?, context: NSManagedObjectContext) -> Self {
        let record = Self(context: context)
        if let store { context.assign(record, to: store) }
        return record
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
