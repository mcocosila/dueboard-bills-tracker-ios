import HouseholdCore
import SwiftUI

/// The Bills list: every Bill, grouped by Category in Category order, with a
/// count per Category.
struct BillsView: View {
    @Binding var household: Household
    @State private var isAddingBill = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(household.billsList.groups) { group in
                    Section {
                        ForEach(group.bills) { bill in
                            BillRow(bill: bill)
                        }
                    } header: {
                        HStack {
                            Text(group.category.name)
                            Spacer()
                            Text(group.count, format: .number)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Bills")
            .toolbar {
                Button("Add a Bill", systemImage: "plus") { isAddingBill = true }
            }
            .sheet(isPresented: $isAddingBill) {
                AddBillView(household: $household)
            }
        }
    }
}

/// One Bill: its name, its Due Day and its Default Amount when it has one.
private struct BillRow: View {
    let bill: Bill

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text(dueDayLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let amount = bill.defaultAmount {
                Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .monospacedDigit()
            }
        }
    }

    /// The Due Day as a person says it: "17th", or "1st of next month".
    private var dueDayLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        let day = formatter.string(from: bill.dueDay.day as NSNumber) ?? "\(bill.dueDay.day)"
        switch bill.dueDay.month {
        case .sameMonth: return day
        case .nextMonth: return "\(day) of next month"
        }
    }
}

#Preview {
    @Previewable @State var household = try! Household.open(in: InMemoryHouseholdStore(), clock: .system)
    BillsView(household: $household)
        .task {
            _ = try? household.addBill(NewBill(
                name: "City Power", categoryID: household.categories[0].id, dueDay: 17, dueMonth: .sameMonth,
                defaultAmount: nil
            ))
            _ = try? household.addBill(NewBill(
                name: "Riverside School", categoryID: household.categories[1].id, dueDay: 1, dueMonth: .nextMonth,
                defaultAmount: 450
            ))
        }
}
