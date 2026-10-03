import HouseholdCore
import SwiftUI

/// The form for adding a Bill. The household core decides whether it can be
/// saved; a refusal is shown under the form and the form stays open.
struct AddBillView: View {
    @Binding var household: Household
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var categoryID: HouseholdCore.Category.ID?
    @State private var dueDay: Int?
    @State private var dueMonth = DueMonth.sameMonth
    @State private var defaultAmount: Decimal?
    @State private var refusal: String?

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
                } footer: {
                    if let refusal {
                        Text(refusal)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add a Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear { categoryID = categoryID ?? household.categories.first?.id }
        }
    }

    private func save() {
        guard let categoryID else { return }
        do {
            try household.addBill(NewBill(
                // A day left empty goes to the core as 0, so it is refused like any day outside 1 to 28.
                name: name, categoryID: categoryID, dueDay: dueDay ?? 0, dueMonth: dueMonth,
                defaultAmount: defaultAmount
            ))
            dismiss()
        } catch {
            refusal = error.localizedDescription
        }
    }
}
