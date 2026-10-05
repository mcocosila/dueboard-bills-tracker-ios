import HouseholdCore
import SwiftUI

/// The form for adding a Bill, or editing one and Retiring or reactivating it. Retired
/// is saved with the rest of the form, so Cancel leaves it as it was. The household core
/// decides whether it can be saved; a refusal is shown under the form and the form
/// stays open.
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
    @State private var isCardPaid: Bool
    @State private var isRetired: Bool
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
        _isCardPaid = State(initialValue: details?.isCardPaid ?? false)
        _isRetired = State(initialValue: bill?.isRetired ?? false)
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
                    Toggle("Card-Paid", isOn: $isCardPaid)
                } footer: {
                    Text(isCardPaid
                        ? "Charged to a credit card, so its Dues are a reminder only and are left out of Unpaid Remaining."
                        : "Turn on for a Bill charged to a credit card rather than paid from the bank.")
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
                if bill != nil {
                    Section {
                        Toggle("Retired", isOn: $isRetired)
                    } footer: {
                        Text(isRetired
                            ? "A Retired Bill gets no Dues and cannot be added to a month; its past Dues remain."
                            : "Turn on when the Bill is no longer paid at all.")
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
            defaultAmount: defaultAmount, isRecurring: isRecurring, isCardPaid: isCardPaid
        )
        do {
            if let bill {
                try household.editBill(bill.id, to: details)
                if isRetired != bill.isRetired {
                    try isRetired ? household.retireBill(bill.id) : household.reactivateBill(bill.id)
                }
            } else {
                try household.addBill(details)
            }
            dismiss()
        } catch {
            refusal = error.localizedDescription
        }
    }
}
