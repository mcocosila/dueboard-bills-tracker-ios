import CloudKit
import CoreData

/// Sharing the Household through iCloud: the owner invites Members with a CloudKit share of
/// the Household, a Member accepts it on their device, and either one ends it. Sharing the
/// Household shares everything that hangs off it, its Categories, Bills, Billing Months and
/// Dues, since iCloud moves the whole graph into the share's zone.
///
/// No rules here: what a Member may do is the household core's, and every Member may do
/// everything.
@MainActor
extension CoreDataHouseholdStore {
    /// The iCloud container, as CloudKit's own screens want it.
    var cloudKitContainer: CKContainer { CKContainer(identifier: Self.iCloudContainer) }

    /// Whether the Household this phone shows is one this Member was invited to, rather than
    /// their own.
    var showsInvitedHousehold: Bool {
        let context = container.viewContext
        return context.performAndWait {
            (try? shownHousehold(in: context))?.objectID.persistentStore == sharedStore
        }
    }

    /// The share of the Household this phone shows, or nil while its owner has not invited
    /// anyone.
    func shareOfShownHousehold() -> CKShare? {
        let context = container.viewContext
        let householdID = context.performAndWait { (try? shownHousehold(in: context))?.objectID }
        guard let householdID else { return nil }
        return (try? container.fetchShares(matching: [householdID]))?[householdID]
    }

    /// The share to invite Members with: the Household's own, made the first time it is
    /// needed. Only the owner makes one; an invited Member always finds the owner's.
    func shareForInviting() async throws -> CKShare {
        if let share = shareOfShownHousehold() { return share }
        let context = container.viewContext
        guard let household = context.performAndWait({ try? shownHousehold(in: context) }) else {
            throw DamagedRecord(entity: "Household")
        }
        let (_, share, _) = try await container.share([household], to: nil)
        share[CKShare.SystemFieldKey.title] = Self.shareTitle
        return share
    }

    /// What the invite calls the Household.
    static let shareTitle = "Dueboard household"

    /// The name this Member goes by in iCloud, as the share of the Household knows it: what
    /// "Paid by" shows. Nil while the Household is not shared, or before iCloud has said.
    static func memberName(in share: CKShare?) -> String? {
        guard let components = share?.currentUserParticipant?.userIdentity.nameComponents else { return nil }
        let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
        return name.isEmpty ? nil : name
    }

    /// Joins the Household of an accepted invite. Its records arrive in the shared store over
    /// the next moments, and the store says so as they do. The owner opening their own invite
    /// joins nothing.
    func accept(_ metadata: CKShare.Metadata) async throws {
        guard metadata.participantRole != .owner else { return }
        _ = try await container.acceptShareInvitations(from: [metadata], into: sharedStore)
    }

    /// Takes the Household this Member was invited to off this phone, once they have left it
    /// or its owner has stopped sharing it. Never the owner's: their Household is in the
    /// private store, and purging it there would delete it from their iCloud.
    func forgetInvitedHousehold(_ share: CKShare) async throws {
        guard showsInvitedHousehold, share.currentUserParticipant?.role != .owner else { return }
        try await container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore)
    }
}
