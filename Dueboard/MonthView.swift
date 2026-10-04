import HouseholdCore
import SwiftUI

/// The Month board: one Billing Month's Unpaid Remaining and its Dues, grouped
/// by Category, with buttons to step to the previous and next month. It starts on
/// the current Billing Month; the household core opens each month the first time
/// it is shown. Each Due takes an Amount and is marked Paid, or Edited, from its row,
/// and its Due Date is coloured by whether it is Paid, Due Soon or Overdue. A Bill the
/// month has no Due for is added from the Add menu; a Due that is not Paid is removed
/// by swiping its row.
struct MonthView: View {
    @Binding var household: Household
    @Environment(\.scenePhase) private var scenePhase
    @State private var month: BillingMonth
    @State private var board: MonthBoard?
    /// Why the month could not be opened.
    @State private var monthRefusal: String?
    /// Why the last change to a Due was refused, shown until dismissed.
    @State private var dueRefusal: String?
    /// The Due waiting for its removal to be confirmed.
    @State private var dueBeingRemoved: Due?
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
                                due: due, state: board?.state(of: due), focus: $amountBeingEntered,
                                enterAmount: { amount in
                                    withMemberName { name in change { try $0.enterAmount(amount, on: due.id, by: name) } }
                                },
                                markPaid: { typed in
                                    withMemberName { name in
                                        change {
                                            if typed != due.amount { try $0.enterAmount(typed, on: due.id, by: name) }
                                            try $0.markPaid(due.id, by: name)
                                        }
                                    }
                                },
                                edit: { change { try $0.undoPaid(due.id) } }
                            )
                            .swipeActions {
                                if board?.canRemove(due) == true {
                                    Button("Remove", systemImage: "trash", role: .destructive) { dueBeingRemoved = due }
                                }
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if let monthRefusal {
                    ContentUnavailableView(monthRefusal, systemImage: "exclamationmark.triangle")
                } else if board?.groups.isEmpty == true {
                    ContentUnavailableView(
                        "No Dues", systemImage: "calendar",
                        description: Text(board?.billsToAdd.isEmpty == false
                            ? "Add a Bill to this month with the + button, or add Bills on the Bills tab."
                            : "Add Bills on the Bills tab and their Dues show up here.")
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
                    if let board, !board.billsToAdd.isEmpty {
                        Menu("Add a Bill to this month", systemImage: "plus") {
                            ForEach(board.billsToAdd) { group in
                                Section(group.category.name) {
                                    ForEach(group.bills) { bill in
                                        Button(bill.name) { change { try $0.addDue(of: bill.id, to: month) } }
                                    }
                                }
                            }
                        }
                    }
                    Button("Previous month", systemImage: "chevron.left") { board?.previous.map { month = $0 } }
                        .disabled(board?.previous == nil)
                    Button("Next month", systemImage: "chevron.right") { board?.next.map { month = $0 } }
                        .disabled(board?.next == nil)
                }
            }
            // Runs each time the tab appears too, so a month left unopened for want of
            // Bills is opened once some have been added.
            .task(id: month) { showMonth() }
            // Due Soon and Overdue are as of the day the board was made, so coming back to
            // the app on a later day shows them as of that day.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { showMonth() }
            }
            .confirmationDialog(
                "Remove \(dueBeingRemoved?.name ?? "") from \(month.title)?",
                isPresented: Binding(get: { dueBeingRemoved != nil }, set: { if !$0 { dueBeingRemoved = nil } }),
                titleVisibility: .visible, presenting: dueBeingRemoved
            ) { due in
                Button("Remove", role: .destructive) { change { try $0.removeDue(due.id) } }
            } message: { _ in
                Text("It can be added back from the Add menu.")
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

    /// Opens the month and shows its board, or why it could not be opened.
    private func showMonth() {
        do {
            board = try household.openBillingMonth(month)
            monthRefusal = nil
        } catch {
            monthRefusal = error.localizedDescription
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

    /// Asks for the name, then runs `action` with it. While the question is open, a
    /// second one is not asked: the action that asked first is the one kept.
    private func askForName(then action: @escaping (String) -> Void) {
        guard !askingForName else { return }
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

/// One Due: its name, its Due Date coloured by its state with who marked it Paid or
/// whether it is Due Soon or Overdue, and its Amount. A Due not Paid takes an Amount and
/// has a Paid button; a Paid Due's Amount is locked behind Edit.
private struct DueRow: View {
    let due: Due
    let state: DueState?
    let focus: FocusState<Due.ID?>.Binding
    /// Hands on the Amount typed, once the field is left.
    let enterAmount: (Decimal?) -> Void
    /// Marks the Due Paid, handing on the Amount typed so it is not lost to the tap.
    let markPaid: (Decimal?) -> Void
    let edit: () -> Void
    @State private var text = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(due.name)
                // One Text, so a long line wraps as a sentence.
                Group {
                    if let paid = due.paid {
                        Text("\(dueDate) · \(paid.summary)")
                    } else if let label = state?.label {
                        Text("\(dueDate) · \(label)")
                    } else {
                        dueDate
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
                TextField("Amount", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(maxWidth: 110)
                    .focused(focus, equals: due.id)
                Button("Paid", systemImage: "checkmark.circle") { markPaid(typedAmount) }
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
        }
        // Each button acts on its own, rather than a tap anywhere on the row pressing them all.
        .buttonStyle(.borderless)
        .onAppear { text = due.amountText }
        // An accepted Amount arrives with the changed Due.
        .onChange(of: due) { text = due.amountText }
        .onChange(of: focus.wrappedValue) { left, _ in
            guard left == due.id, due.paid == nil, typedAmount != due.amount else { return }
            enterAmount(typedAmount)
            // A refused Amount leaves the Due as it was, so the field goes back to it.
            text = due.amountText
        }
    }

    /// The Due Date, coloured by the Due's state.
    private var dueDate: Text {
        Text(due.dueDate.date, format: dayFormat)
            .fontWeight(.semibold)
            .foregroundStyle(state.map { AnyShapeStyle($0.colour) } ?? AnyShapeStyle(.secondary))
    }

    /// The Amount in the field: nil when it is empty, the Due's own when it is not a number.
    private var typedAmount: Decimal? {
        let typed = text.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return nil }
        return (try? Decimal(typed, format: .number)) ?? due.amount
    }
}

private extension Due {
    /// The Amount as the field shows it for changing, or empty when there is none.
    var amountText: String {
        amount?.formatted(.number.precision(.fractionLength(2))) ?? ""
    }
}

private extension DueState {
    /// The colour of the Due Date, readable on a row in light and dark mode.
    var colour: Color {
        switch self {
        case .paid: Color(.paid)
        case .dueSoon: Color(.dueSoon)
        case .overdue: Color(.overdue)
        }
    }

    /// Said after the Due Date, so the state does not rest on colour alone. A Paid Due
    /// says who Paid it instead.
    var label: String? {
        switch self {
        case .paid: nil
        case .dueSoon: "Due Soon"
        case .overdue: "Overdue"
        }
    }
}

private extension Due.Paid {
    /// "Paid Oct 4 by Mircea", or "Paid Oct 4" for a Due Paid from birth.
    var summary: String {
        let day = at.formatted(dayFormat)
        return by.map { "Paid \(day) by \($0)" } ?? "Paid \(day)"
    }
}

/// "Oct 4", in the phone's language.
private let dayFormat = Date.FormatStyle.dateTime.month(.abbreviated).day()

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
