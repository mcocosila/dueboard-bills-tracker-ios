import HouseholdCore
import SwiftUI

/// The Bills list: every Bill, grouped by Category in Category order, with a
/// count per Category, and the Retired Bills in a muted group of their own at the
/// end. A Bill is edited, Retired or reactivated by tapping its row. The Categories
/// are managed from the toolbar.
struct BillsView: View {
    @Binding var household: Household
    @State private var isAddingBill = false
    @State private var isManagingCategories = false
    @State private var billBeingEdited: Bill?

    var body: some View {
        NavigationStack {
            List {
                ForEach(household.billsList.groups) { group in
                    Section {
                        ForEach(group.bills) { bill in
                            Button { billBeingEdited = bill } label: { BillRow(bill: bill) }
                        }
                    } header: {
                        CountedHeader(title: group.category.name, count: group.count)
                    }
                }
                let retired = household.billsList.retired
                if !retired.isEmpty {
                    Section {
                        ForEach(retired) { bill in
                            Button { billBeingEdited = bill } label: { BillRow(bill: bill) }
                        }
                        .foregroundStyle(.secondary)
                    } header: {
                        CountedHeader(title: "Retired", count: retired.count)
                    }
                }
            }
            // Rows are buttons only to open the form, so they keep the look of plain rows.
            .tint(.primary)
            .navigationTitle("Bills")
            .toolbar {
                Button("Categories", systemImage: "folder") { isManagingCategories = true }
                Button("Add a Bill", systemImage: "plus") { isAddingBill = true }
            }
            .sheet(isPresented: $isManagingCategories) {
                CategoriesView(household: $household)
            }
            .sheet(isPresented: $isAddingBill) {
                BillFormView(household: $household)
            }
            .sheet(item: $billBeingEdited) { bill in
                BillFormView(household: $household, editing: bill)
            }
        }
    }
}

/// A group's name and how many Bills it holds.
private struct CountedHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(count, format: .number)
                .monospacedDigit()
        }
    }
}

/// One Bill: its name, its Due Day, whether it is Occasional or Card-Paid, and its Default
/// Amount when it has one.
private struct BillRow: View {
    let bill: Bill

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text(subtitle)
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

    /// "17th · Occasional · Card-Paid": the Due Day, then whichever of Occasional and Card-Paid
    /// the Bill is.
    private var subtitle: String {
        let tags: [String?] = [bill.isRecurring ? nil : "Occasional", bill.isCardPaid ? "Card-Paid" : nil]
        return ([dueDayLabel] + tags.compactMap { $0 }).joined(separator: " · ")
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
            _ = try? household.addBill(NewBill(
                name: "Plumber", categoryID: household.categories[0].id, dueDay: 20, dueMonth: .sameMonth,
                defaultAmount: nil, isRecurring: false
            ))
            if let water = try? household.addBill(NewBill(
                name: "Water", categoryID: household.categories[0].id, dueDay: 5, dueMonth: .sameMonth,
                defaultAmount: nil
            )) {
                _ = try? household.retireBill(water.id)
            }
        }
}
