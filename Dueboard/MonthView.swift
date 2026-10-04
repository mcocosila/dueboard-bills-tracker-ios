import HouseholdCore
import SwiftUI

/// The Month board: one Billing Month's Unpaid Remaining and its Dues, grouped
/// by Category, with buttons to step to the previous and next month. It starts on
/// the current Billing Month; the household core opens each month the first time
/// it is shown. Each Due takes an Amount and is marked Paid, or Edited, from its row.
struct MonthView: View {
    @Binding var household: Household
    @State private var month: BillingMonth
    @State private var board: MonthBoard?
    @State private var refusal: String?
    /// Why the last change to a Due was refused, shown until dismissed.
    @State private var dueRefusal: String?
    @FocusState private var amountBeingEntered: Due.ID?
    /// Who marks Dues Paid on this phone, until sharing records the iCloud name instead.
    @AppStorage("memberName") private var memberName = ""
    @State private var askingForName = false
    @State private var nameBeingEntered = ""
    /// What to do with the name once it has been entered.
    @State private var waitingForName: ((String) -> Void)?

    init(household: Binding<Household>) {
        _household = household
        _month = State(initialValue: household.wrappedValue.currentBillingMonth)
    }

    var body: some View {
        NavigationStack {
            List {
                if let board, !board.groups.isEmpty {
                    UnpaidRemainingRow(remaining: board.unpaidRemaining)
                }
                ForEach(board?.groups ?? []) { group in
                    Section(group.category.name) {
                        ForEach(group.dues) { due in
                            DueRow(
                                due: due, focus: $amountBeingEntered,
                                enterAmount: { amount in enterAmount(amount, on: due) },
                                markPaid: { withMemberName { name in change { try $0.markPaid(due.id, by: name) } } },
                                edit: { change { try $0.undoPaid(due.id) } }
                            )
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Your name", systemImage: "person.crop.circle") { askForName { _ in } }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountBeingEntered = nil }
                }
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
            .alert(
                "Not changed", isPresented: Binding(get: { dueRefusal != nil }, set: { if !$0 { dueRefusal = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(dueRefusal ?? "")
            }
            .alert("Your name", isPresented: $askingForName) {
                TextField("Name", text: $nameBeingEntered)
                    .textContentType(.givenName)
                Button("Cancel", role: .cancel) { waitingForName = nil }
                Button("Save") {
                    let name = nameBeingEntered.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    memberName = name
                    waitingForName?(name)
                    waitingForName = nil
                }
            } message: {
                Text("Shown on the Dues you mark Paid.")
            }
        }
    }

    /// Enters the Amount. Zero marks the Due Paid, which records who, so only then is
    /// the name needed before going on.
    private func enterAmount(_ amount: Decimal?, on due: Due) {
        if amount == 0 {
            withMemberName { name in change { try $0.enterAmount(amount, on: due.id, by: name) } }
        } else {
            change { try $0.enterAmount(amount, on: due.id, by: memberName) }
        }
    }

    /// Sends a change to the household core, then shows the board as it now is, or
    /// why the change was refused.
    private func change(_ command: (inout Household) throws -> Void) {
        do {
            try command(&household)
        } catch {
            dueRefusal = error.localizedDescription
        }
        board = try? household.openBillingMonth(month)
    }

    /// Runs `action` with the name kept on this phone, asking for it first the one time
    /// there is none.
    private func withMemberName(_ action: @escaping (String) -> Void) {
        if memberName.isEmpty {
            askForName(then: action)
        } else {
            action(memberName)
        }
    }

    private func askForName(then action: @escaping (String) -> Void) {
        nameBeingEntered = memberName
        waitingForName = action
        askingForName = true
    }
}

/// Unpaid Remaining, and how many Dues it cannot count yet for want of an Amount.
private struct UnpaidRemainingRow: View {
    let remaining: UnpaidRemaining

    var body: some View {
        LabeledContent {
            Text(remaining.amount, format: .currency(code: currencyCode))
                .font(.headline)
                .foregroundStyle(.primary)
                .monospacedDigit()
        } label: {
            Text("Unpaid Remaining")
            if remaining.withoutAmount > 0 {
                Text("\(remaining.withoutAmount) without amount")
            }
        }
    }
}

/// One Due: its name, its Due Date or who marked it Paid, and its Amount. A Due not
/// Paid takes an Amount and has a Paid button; a Paid Due's Amount is locked behind Edit.
private struct DueRow: View {
    let due: Due
    let focus: FocusState<Due.ID?>.Binding
    let enterAmount: (Decimal?) -> Void
    let markPaid: () -> Void
    let edit: () -> Void
    /// The Amount as typed, handed on once the field is left.
    @State private var amount: Decimal?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(due.name)
                Group {
                    if let paid = due.paid {
                        Text(paid.summary)
                    } else {
                        Text(due.dueDate.date, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if due.paid != nil {
                Group {
                    if let amount = due.amount {
                        Text(amount, format: .currency(code: currencyCode))
                    } else {
                        Text("No amount").foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                Button("Edit", action: edit)
                    .buttonStyle(.bordered)
            } else {
                TextField("Amount", value: $amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(maxWidth: 110)
                    .focused(focus, equals: due.id)
                Button("Paid", systemImage: "checkmark.circle", action: markPaid)
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
        }
        // Each button acts on its own, rather than a tap anywhere on the row pressing them all.
        .buttonStyle(.borderless)
        .onAppear { amount = due.amount }
        // The field shows the Amount as the Due has it: a refused one goes back to the
        // Amount before, an accepted one arrives with the changed Due.
        .onChange(of: due) { amount = due.amount }
        .onChange(of: amount) {
            guard amount != due.amount else { return }
            enterAmount(amount)
            amount = due.amount
        }
    }
}

private extension Due.Paid {
    /// "Paid Oct 4 by Mircea", or "Paid Oct 4" for a Due Paid from birth.
    var summary: String {
        let day = at.formatted(.dateTime.month(.abbreviated).day())
        return by.map { "Paid \(day) by \($0)" } ?? "Paid \(day)"
    }
}

/// The currency amounts are shown in: the phone's own.
private var currencyCode: String {
    Locale.current.currency?.identifier ?? "USD"
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
