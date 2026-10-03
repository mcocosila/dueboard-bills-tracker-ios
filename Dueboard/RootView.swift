import HouseholdCore
import SwiftUI

/// The app's tabs: the Billing Month and the Bills.
struct RootView: View {
    @Binding var household: Household

    var body: some View {
        TabView {
            Tab("Month", systemImage: "calendar") {
                PlaceholderView(month: household.currentBillingMonth)
            }
            Tab("Bills", systemImage: "list.bullet") {
                BillsView(household: $household)
            }
        }
    }
}
