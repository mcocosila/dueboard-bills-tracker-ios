import CloudKit
import HouseholdCore
import SwiftUI

@main
struct DueboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var opened = OpenedHousehold()
    @State private var reminders = ReminderNotifications()
    @State private var iCloud = ICloudAccount()

    var body: some Scene {
        WindowGroup {
            if let household = Binding($opened.household) {
                RootView(household: household, reminders: reminders)
                    .environment(\.householdReadAgain, opened.timesReadAgain)
                    .environment(iCloud)
                    .environment(opened)
            } else {
                ContentUnavailableView(
                    "Dueboard could not open its data",
                    systemImage: "exclamationmark.triangle",
                    description: Text(opened.openingError ?? "")
                )
            }
        }
    }
}

/// The Household as the store on this phone keeps it, read again whenever iCloud brings in
/// a change made on another device, and how this Member shares it: inviting others to it,
/// joining one they were invited to, and leaving it or stopping sharing it.
@MainActor @Observable
final class OpenedHousehold {
    var household: Household?
    private(set) var openingError: String?
    /// How many times the Household has been read again after a change from elsewhere, so
    /// screens that show something worked out from it can work it out again.
    private(set) var timesReadAgain = 0
    /// The name this Member goes by in iCloud, once the Household is shared: who "Paid by"
    /// names. Nil before, and the name typed on this phone stands in.
    private(set) var memberName: String?
    /// Whether the Household shown is one this Member was invited to, rather than their own.
    private(set) var isInvited = false
    /// True from accepting an invite until its Household has arrived on this phone.
    private(set) var isJoining = false
    /// How many invites have been joined, so the Month tab can open on the joined
    /// Household's current Billing Month.
    private(set) var timesJoined = 0
    /// True while the share is being made, before iCloud's sharing screen can show.
    private(set) var isPreparingShare = false
    /// Why sharing, joining or leaving did not work, shown until dismissed.
    var sharingError: String?

    @ObservationIgnored private var store: CoreDataHouseholdStore?
    /// The zone of the invite being joined, to know when its Household is the one shown.
    @ObservationIgnored private var joiningZone: CKRecordZone.ID?
    @ObservationIgnored private lazy var sharingScreen = SharingScreen(
        stopped: { [weak self] share in self?.sharingStopped(share) },
        saved: { [weak self] in self?.followSharing() },
        failed: { [weak self] error in self?.sharingError = error.localizedDescription }
    )

    init() {
        do {
            let store = try CoreDataHouseholdStore()
            self.store = store
            household = try Household.open(in: store, clock: .system)
            store.changedElsewhere = { [weak self] in self?.readAgain() }
            followSharing()
        } catch {
            openingError = error.localizedDescription
        }
        AcceptedInvites.shared.join = { [weak self] metadata in self?.join(metadata) }
    }

    /// Shows iCloud's sharing screen for the Household, making its share the first time.
    func showSharing() {
        guard let store, !isPreparingShare else { return }
        isPreparingShare = true
        Task {
            defer { isPreparingShare = false }
            do {
                let share = try await store.shareForInviting()
                followSharing()
                sharingScreen.show(share, in: store.cloudKitContainer)
            } catch {
                sharingError = "The Household could not be shared: \(error.localizedDescription)"
            }
        }
    }

    /// Joins the Household of an invite this Member accepted. It shows once its records have
    /// arrived; until then the Household already on this phone stays.
    private func join(_ metadata: CKShare.Metadata) {
        guard let store, metadata.participantRole != .owner else { return }
        joiningZone = metadata.share.recordID.zoneID
        isJoining = true
        Task {
            do {
                try await store.accept(metadata)
                readAgain()
            } catch {
                isJoining = false
                joiningZone = nil
                sharingError = "The invite could not be accepted: \(error.localizedDescription)"
            }
        }
    }

    /// After the owner stopped sharing, or this Member left: a Member's device forgets the
    /// Household they left and shows their own again. The owner keeps theirs.
    private func sharingStopped(_ share: CKShare) {
        guard let store else { return }
        Task {
            do {
                try await store.forgetInvitedHousehold(share)
            } catch {
                sharingError = "The Household could not be removed from this device: \(error.localizedDescription)"
            }
            readAgain()
        }
    }

    private func readAgain() {
        guard let store else { return }
        do {
            household = try Household.open(in: store, clock: .system)
            timesReadAgain += 1
            followSharing()
        } catch {
            openingError = error.localizedDescription
            household = nil
        }
    }

    /// Reads how the Household shown is shared, and whether the invite being joined has
    /// arrived.
    private func followSharing() {
        guard let store else { return }
        isInvited = store.showsInvitedHousehold
        let share = store.shareOfShownHousehold()
        memberName = CoreDataHouseholdStore.memberName(in: share)
        if isJoining, let joiningZone, share?.recordID.zoneID == joiningZone {
            isJoining = false
            self.joiningZone = nil
            timesJoined += 1
        }
    }
}

extension EnvironmentValues {
    /// How many times the Household has been read again after a change from another device.
    @Entry var householdReadAgain = 0
}
