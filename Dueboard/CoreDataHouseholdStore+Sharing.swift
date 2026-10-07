import CloudKit
import CoreData

/// Sharing the Household through iCloud: the owner invites Members with a CloudKit share of
/// the Household, a Member accepts it on their device, and either one ends it. Sharing the
/// Household shares everything that hangs off it, its Categories, Bills, Billing Months and
/// Dues, since iCloud moves the whole graph into the share's zone.
///
/// Every Member may change everything in the Household, so the household core knows
/// nothing of who is who. What tells the owner from an invited Member is decided here and
/// by iCloud's own sharing screen: only the owner makes the share, and only a Household this
/// Member was invited to is ever taken off the phone.
extension CoreDataHouseholdStore {
    /// The iCloud container, as CloudKit's own screens want it.
    var cloudKitContainer: CKContainer { CKContainer(identifier: Self.iCloudContainer) }

    /// Whether the Household this phone shows is one this Member was invited to, rather than
    /// their own.
    var showsInvitedHousehold: Bool {
        (try? shownHousehold(in: container.viewContext))?.objectID.persistentStore == sharedStore
    }

    /// The share of the Household this phone shows, or nil while its owner has not invited
    /// anyone.
    func shareOfShownHousehold() -> CKShare? {
        guard let householdID = (try? shownHousehold(in: container.viewContext))?.objectID else { return nil }
        return (try? container.fetchShares(matching: [householdID]))?[householdID]
    }

    /// The share to invite Members with: the Household's own, made the first time the owner
    /// needs it, with its title saved in it. An invited Member never makes one: their
    /// Household is the owner's, and only the owner's share invites anyone to it.
    func shareForInviting() async throws -> CKShare {
        if let share = shareOfShownHousehold() { return share }
        guard !showsInvitedHousehold else { throw SharingRefusal.shareNotArrived }
        guard let household = try? shownHousehold(in: container.viewContext) else {
            throw DamagedRecord(entity: "Household")
        }
        let (_, share, _) = try await container.share([household], to: nil)
        share[CKShare.SystemFieldKey.title] = Self.shareTitle
        return try await container.persistUpdatedShare(share, in: privateStore)
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

    /// Joins the Household of an invite to someone else's Household; the owner opening their
    /// own invite has nothing to join, and the caller does not pass it on. Its records arrive
    /// in the shared store over the next moments, and it shows once they all have:
    /// `householdJoined` says when.
    func accept(_ metadata: CKShare.Metadata) async throws {
        joiningZone = metadata.share.recordID.zoneID
        do {
            _ = try await container.acceptShareInvitations(from: [metadata], into: sharedStore)
        } catch {
            joiningZone = nil
            throw error
        }
    }

    /// Whether an accepted invite's Household is still on its way. Kept on the phone, so an
    /// app closed while joining still waits for the whole Household when it opens again.
    var isJoining: Bool { joiningZone != nil }

    /// The zone of the invite being joined, until its Household has arrived whole.
    var joiningZone: CKRecordZone.ID? {
        get {
            guard let zone = UserDefaults.standard.dictionary(forKey: Self.joiningZoneKey) as? [String: String],
                  let name = zone["zoneName"], let owner = zone["ownerName"]
            else { return nil }
            return CKRecordZone.ID(zoneName: name, ownerName: owner)
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: Self.joiningZoneKey)
                return
            }
            UserDefaults.standard.set(
                ["zoneName": newValue.zoneName, "ownerName": newValue.ownerName], forKey: Self.joiningZoneKey
            )
        }
    }

    private static let joiningZoneKey = "joiningHouseholdZone"

    /// iCloud has finished bringing in a batch of changes to `storeID`. Once one ends with the
    /// share of the invite being joined in the shared store, that zone has been fetched whole,
    /// the Household with every Category, Bill, Billing Month and Due, since a share comes in
    /// the same fetch as the records of its zone. Only then does it show.
    func importEnded(in storeID: String) {
        guard let joiningZone, storeID == sharedStore.identifier,
              let shares = try? container.fetchShares(in: sharedStore),
              shares.contains(where: { $0.recordID.zoneID == joiningZone })
        else { return }
        self.joiningZone = nil
        householdJoined?()
    }

    /// Takes the Household this Member was invited to off this phone, once they have left it
    /// or its owner has stopped sharing it. Never the owner's: their Household is in the
    /// private store, and purging it there would delete it from their iCloud.
    func forgetInvitedHousehold(_ share: CKShare) async throws {
        guard showsInvitedHousehold, share.currentUserParticipant?.role != .owner else { return }
        try await container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore)
    }
}

/// Why sharing the Household was refused.
enum SharingRefusal: LocalizedError {
    /// An invited Member's phone has the Household but not yet the owner's share of it.
    case shareNotArrived

    var errorDescription: String? {
        switch self {
        case .shareNotArrived:
            "The invite's details have not arrived from iCloud yet. Try again in a moment."
        }
    }
}
