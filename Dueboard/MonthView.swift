import HouseholdCore
import SwiftUI

/// The Month board: one Billing Month's Dues, grouped by Category, with
/// buttons to step to the previous and next month. It starts on the current
/// Billing Month; the household core opens each month the first time it is shown.
struct MonthView: View {
    @Binding var household: Household
    @State private var month: BillingMonth
    @State private var board: MonthBoard?
    @State private var refusal: String?

    init(household: Binding<Household>) {
        _household = household
        _month = State(initialValue: household.wrappedValue.currentBillingMonth)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(board?.groups ?? []) { group in
                    Section(group.category.name) {
                        ForEach(group.dues) { due in
                            DueRow(due: due)
                        }
                    }
                }
            }
            .overlay {
                if let refusal {
                    ContentUnavailableView(refusal, systemImage: "exclamationmark.triangle")
                } else if board?.groups.isEmpty == true {
                    ContentUnavailableView(
                        "No Dues", systemImage: "calendar",
                        description: Text("Add Bills on the Bills tab and their Dues show up here.")
                    )
                }
            }
            .navigationTitle(month.title)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Previous month", systemImage: "chevron.left") { board?.previous.map { month = $0 } }
                        .disabled(board?.previous == nil)
                    Button("Next month", systemImage: "chevron.right") { board?.next.map { month = $0 } }
                        .disabled(board?.next == nil)
                }
            }
            // Runs each time the tab appears too, so a month left unopened for want of
            // Bills is opened once some have been added.
            .task(id: month) {
                do {
                    board = try household.openBillingMonth(month)
                    refusal = nil
                } catch {
                    refusal = error.localizedDescription
                }
            }
        }
    }
}

/// One Due: its name, its Due Date, and its Amount or that it has none yet.
private struct DueRow: View {
    let due: Due

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(due.name)
                Text(due.dueDate.date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let amount = due.amount {
                Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .monospacedDigit()
            } else {
                Text("No amount")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension BillingMonth {
    /// "September 2026", in the phone's language.
    var title: String {
        // Billing Months are Gregorian months, whatever calendar the phone is set to,
        // named in the phone's language. A calendar made from an identifier has no
        // locale, and without one the month symbols come out as "M01" to "M12".
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        let name = calendar.standaloneMonthSymbols[month - 1]
        return "\(name) \(year)"
    }
}

private extension DueDate {
    /// Midnight at the start of the Due Date on this phone, for formatting.
    var date: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}

#Preview {
    // The Bills are added before the board first shows, as they would be on a phone in use.
    @Previewable @State var household: Household = {
        var household = try! Household.open(in: InMemoryHouseholdStore(), clock: .system)
        _ = try? household.addBill(NewBill(
            name: "City Power", categoryID: household.categories[0].id, dueDay: 17, dueMonth: .sameMonth,
            defaultAmount: nil
        ))
        _ = try? household.addBill(NewBill(
            name: "Riverside School", categoryID: household.categories[1].id, dueDay: 1, dueMonth: .nextMonth,
            defaultAmount: 450
        ))
        return household
    }()
    MonthView(household: $household)
}
