import HouseholdCore
import SwiftUI

/// The form for adding a Bill, or editing one and Retiring or reactivating it. The
/// household core decides whether it can be saved; a refusal is shown under the form
/// and the form stays open.
struct BillFormView: View {
    @Binding var household: Household
    /// The Bill being edited, or nil when a Bill is being added.
    let bill: Bill?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var categoryID: HouseholdCore.Category.ID?
    @State private var dueDay: Int?
    @State private var dueMonth: DueMonth
    @State private var defaultAmount: Decimal?
    @State private var isRecurring: Bool
    @State private var refusal: String?

    init(household: Binding<Household>, editing bill: Bill? = nil) {
        _household = household
        self.bill = bill
        let details = bill.map(NewBill.init)
        _name = State(initialValue: details?.name ?? "")
        _categoryID = State(initialValue: details?.categoryID ?? household.wrappedValue.categories.first?.id)
        _dueDay = State(initialValue: details?.dueDay)
        _dueMonth = State(initialValue: details?.dueMonth ?? .sameMonth)
        _defaultAmount = State(initialValue: details?.defaultAmount)
        _isRecurring = State(initialValue: details?.isRecurring ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $categoryID) {
                        ForEach(household.categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }
                Section {
                    LabeledContent("Day") {
                        TextField("1 to 28", value: $dueDay, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Due in", selection: $dueMonth) {
                        Text("Same Month").tag(DueMonth.sameMonth)
                        Text("Next Month").tag(DueMonth.nextMonth)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Due Day")
                } footer: {
                    Text("Next Month is for a Bill paid in one month and due early in the next.")
                }
                Section {
                    LabeledContent("Default Amount") {
                        TextField("Optional", value: $defaultAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section {
                    Toggle("Recurring", isOn: $isRecurring)
                } footer: {
                    VStack(alignment: .leading) {
                        Text(isRecurring
                            ? "Gets a Due in every Billing Month opened from now on."
                            : "Occasional: added to a Billing Month by hand, in the months it is paid.")
                        if let refusal {
                            Text(refusal)
                                .foregroundStyle(.red)
                        }
                    }
                }
                if let bill {
                    Section {
                        if bill.isRetired {
                            Button("Reactivate") { change { try $0.reactivateBill(bill.id) } }
                        } else {
                            Button("Retire", role: .destructive) { change { try $0.retireBill(bill.id) } }
                        }
                    } footer: {
                        Text(bill.isRetired
                            ? "Billing Months opened from now on get its Dues again."
                            : "A Retired Bill gets no Dues and cannot be added to a month; its past Dues remain.")
                    }
                }
            }
            .navigationTitle(bill == nil ? "Add a Bill" : "Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        let details = NewBill(
            // A day left empty goes to the core as 0, so it is refused like any day outside 1 to 28.
            name: name, categoryID: categoryID, dueDay: dueDay ?? 0, dueMonth: dueMonth,
            defaultAmount: defaultAmount, isRecurring: isRecurring
        )
        if let bill {
            change { try $0.editBill(bill.id, to: details) }
        } else {
            change { try $0.addBill(details) }
        }
    }

    /// Sends a change to the household core and closes the form, or shows why it was refused.
    private func change(_ command: (inout Household) throws -> Void) {
        do {
            try command(&household)
            dismiss()
        } catch {
            refusal = error.localizedDescription
        }
    }
}
