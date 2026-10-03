import HouseholdCore
import SwiftUI

/// Stands in for the Month board until the screens are built. It shows the
/// current Billing Month, which proves the app reaches the household core.
struct PlaceholderView: View {
    let month: BillingMonth

    var body: some View {
        VStack(spacing: 8) {
            Text("Dueboard")
                .font(.largeTitle.bold())
            Text(title)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        // Billing Months are Gregorian months, whatever calendar the phone is set to.
        let name = Calendar(identifier: .gregorian).standaloneMonthSymbols[month.month - 1]
        return "\(name) \(month.year)"
    }
}

#Preview {
    PlaceholderView(month: BillingMonth(year: 2026, month: 9))
}
