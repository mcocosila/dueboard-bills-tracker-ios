import HouseholdCore
import SwiftUI

/// The Household's Categories, in their order: created with the plus button, renamed by tapping
/// a row, reordered by dragging in Edit, and deleted by swiping. The household core decides each
/// change: a refusal to delete, such as for a Category that still holds Bills, is shown in an alert,
/// and a refused name under the name being entered.
struct CategoriesView: View {
    @Binding var household: Household
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingCategory = false
    @State private var categoryBeingRenamed: HouseholdCore.Category?
    @State private var refusal: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(household.categories) { category in
                    Button(category.name) { categoryBeingRenamed = category }
                }
                .onMove { source, destination in
                    var order = household.categories.map(\.id)
                    order.move(fromOffsets: source, toOffset: destination)
                    change { try $0.reorderCategories(order) }
                }
                .onDelete { offsets in
                    let categories = offsets.map { household.categories[$0] }
                    change { household in
                        for category in categories {
                            try household.deleteCategory(category.id)
                        }
                    }
                }
            }
            // Rows are buttons only to rename, so they keep the look of plain rows.
            .tint(.primary)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add a Category", systemImage: "plus") { isAddingCategory = true }
                }
            }
            .sheet(isPresented: $isAddingCategory) {
                CategoryNameForm(title: "New Category", name: "") { try household.addCategory(named: $0) }
            }
            .sheet(item: $categoryBeingRenamed) { category in
                CategoryNameForm(title: "Rename Category", name: category.name) {
                    try household.renameCategory(category.id, to: $0)
                }
            }
            .alert(
                "Not changed", isPresented: Binding(get: { refusal != nil }, set: { if !$0 { refusal = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(refusal ?? "")
            }
        }
    }

    /// Sends a command to the household core, showing its refusal if it has one.
    private func change(_ command: (inout Household) throws -> Void) {
        do {
            try command(&household)
        } catch {
            refusal = error.localizedDescription
        }
    }
}

/// The name of a new Category, or of one being renamed. The household core decides whether it
/// is saved; a refusal is shown under the name and the form stays open.
private struct CategoryNameForm: View {
    let title: String
    /// Sends the name entered to the household core.
    let save: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var refusal: String?

    init(title: String, name: String, save: @escaping (String) throws -> Void) {
        self.title = title
        self.save = save
        _name = State(initialValue: name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                } footer: {
                    if let refusal {
                        Text(refusal)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try save(name)
                            dismiss()
                        } catch {
                            refusal = error.localizedDescription
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    @Previewable @State var household = try! Household.open(in: InMemoryHouseholdStore(), clock: .system)
    CategoriesView(household: $household)
        .task {
            _ = try? household.addBill(NewBill(
                name: "City Power", categoryID: household.categories[0].id, dueDay: 17, dueMonth: .sameMonth,
                defaultAmount: nil
            ))
        }
}
