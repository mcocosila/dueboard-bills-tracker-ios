import CloudKit
import SwiftUI

/// Whether the phone is signed in to iCloud, so the app can say when the Household is
/// kept on this phone alone. Follows the phone as the Member signs in or out.
@MainActor @Observable
final class ICloudAccount {
    /// True when nothing syncs or can be shared: signed out of iCloud, or an account that
    /// cannot use it right now. False while the answer is not known yet.
    private(set) var isUnavailable = false
    @ObservationIgnored private var accountChanges: (any NSObjectProtocol)?

    init() {
        accountChanges = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        check()
    }

    /// Asks iCloud for the account's status.
    func check() {
        Task {
            let status = try? await CKContainer(identifier: CoreDataHouseholdStore.iCloudContainer).accountStatus()
            switch status {
            case .noAccount, .restricted, .temporarilyUnavailable: isUnavailable = true
            default: isUnavailable = false
            }
        }
    }
}

extension View {
    /// Shows, along the bottom, the one line that says why nothing syncs when the phone is
    /// signed out of iCloud.
    func iCloudNotice(_ account: ICloudAccount) -> some View {
        bottomNotice(isShown: account.isUnavailable) {
            Label("Saved on this device only: sync and sharing need iCloud.", systemImage: "icloud.slash")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Shows `notice` along the bottom while `isShown`, in small print on the bar.
    func bottomNotice(isShown: Bool, @ViewBuilder _ notice: () -> some View) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if isShown {
                notice()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(.bar)
            }
        }
    }
}
