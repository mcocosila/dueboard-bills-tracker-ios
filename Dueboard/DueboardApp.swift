import HouseholdCore
import SwiftUI

@main
struct DueboardApp: App {
    @State private var household: Household?
    @State private var openingError: String?

    init() {
        do {
            _household = State(initialValue: try Household.open(in: CoreDataHouseholdStore(), clock: .system))
        } catch {
            _openingError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let household = Binding($household) {
                RootView(household: household)
            } else {
                ContentUnavailableView(
                    "Dueboard could not open its data",
                    systemImage: "exclamationmark.triangle",
                    description: Text(openingError ?? "")
                )
            }
        }
    }
}
