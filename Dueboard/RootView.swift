import HouseholdCore
import SwiftUI

/// The app's tabs: the Billing Month and the Bills.
struct RootView: View {
    @Binding var household: Household

    var body: some View {
        TabView {
            Tab("Month", systemImage: "calendar") {
                MonthView(household: $household)
            }
            Tab("Bills", systemImage: "list.bullet") {
                BillsView(household: $household)
            }
        }
    }
}
