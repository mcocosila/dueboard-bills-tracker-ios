import HouseholdCore
import SwiftUI

@main
struct DueboardApp: App {
    private let household = Household(clock: .system)

    var body: some Scene {
        WindowGroup {
            PlaceholderView(month: household.currentBillingMonth)
        }
    }
}
