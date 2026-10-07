import CloudKit
import SwiftUI
import UIKit

extension View {
    /// Shows, along the bottom, that an accepted invite's Household is on its way, while it is.
    func joiningNotice(_ isJoining: Bool) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if isJoining {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Joining the household: it shows here once iCloud brings it.")
                        .lineLimit(2)
                }
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

/// Hands the app the invites a Member accepts by tapping a link in Messages or Mail. iOS
/// gives an invite to the scene: as the app launches when it was not running, or while it
/// runs. Either way it waits here until the app is ready to join the Household.
@MainActor
final class AcceptedInvites {
    static let shared = AcceptedInvites()

    private var waiting: [CKShare.Metadata] = []
    /// Joins the Household of an accepted invite. Invites accepted before it was set are
    /// handed to it as soon as it is.
    var join: ((CKShare.Metadata) -> Void)? {
        didSet {
            guard let join else { return }
            let invites = waiting
            waiting = []
            invites.forEach(join)
        }
    }

    func accepted(_ metadata: CKShare.Metadata) {
        if let join { join(metadata) } else { waiting.append(metadata) }
    }
}

/// Puts `SceneDelegate` on the app's scene, the only place iOS hands accepted invites to.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// Receives the invites a Member accepts, whether the tap launched the app or found it running.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let metadata = options.cloudKitShareMetadata {
            AcceptedInvites.shared.accepted(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        AcceptedInvites.shared.accepted(metadata)
    }
}

/// Shows iCloud's own sharing screen for the Household: the owner invites Members and sees
/// who has joined, and can stop sharing; an invited Member sees the others and can leave.
@MainActor
final class SharingScreen: NSObject, UICloudSharingControllerDelegate {
    /// Called when the owner has stopped sharing, or the Member has left.
    private let stopped: (CKShare) -> Void
    /// Called when the share was saved, with Members added or taken away.
    private let saved: () -> Void
    private let failed: (any Error) -> Void
    private var share: CKShare?

    init(stopped: @escaping (CKShare) -> Void, saved: @escaping () -> Void, failed: @escaping (any Error) -> Void) {
        self.stopped = stopped
        self.saved = saved
        self.failed = failed
    }

    /// Shows the screen for `share` over whatever the app shows now.
    func show(_ share: CKShare, in container: CKContainer) {
        self.share = share
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = self
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.modalPresentationStyle = .formSheet
        topViewController()?.present(controller, animated: true)
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        CoreDataHouseholdStore.shareTitle
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        nil
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {
        failed(error)
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        saved()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if let share = csc.share ?? share { stopped(share) }
    }

    /// The view controller on top, which the sharing screen is presented from.
    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
