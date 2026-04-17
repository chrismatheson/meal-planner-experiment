import SwiftUI
import SwiftData

struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MealPlanViewModel()
    @State private var selectedDate: Date = .now
    @State private var showingRecipePicker = false
    @State private var dateForNewMeal: Date?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week header
                weekHeader
                
                // Day list
                dayList
            }
            .navigationTitle("Meal Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedDate = .now
                    } label: {
                        Text("Today")
                    }
                }
            }
            .sheet(isPresented: $showingRecipePicker) {
                RecipePickerView { recipe in
                    if let date = dateForNewMeal {
                        viewModel.assignRecipe(recipe, to: date, context: modelContext)
                    }
                    showingRecipePicker = false
                }
            }
            .task {
                viewModel.loadMealSlots(for: weekDates, context: modelContext)
            }
            .onChange(of: selectedDate) { _, _ in
                viewModel.loadMealSlots(for: weekDates, context: modelContext)
            }
        }
    }
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    private var weekHeader: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(weekRangeText)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }
    
    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekDates.first ?? .now)
        let end = formatter.string(from: weekDates.last ?? .now)
        return "\(start) - \(end)"
    }
    
    private var dayList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(weekDates, id: \.self) { date in
                    DayRow(
                        date: date,
                        mealSlot: viewModel.mealSlot(for: date),
                        isToday: Calendar.current.isDateInToday(date),
                        onTapEmpty: {
                            dateForNewMeal = date
                            showingRecipePicker = true
                        },
                        onReplace: {
                            dateForNewMeal = date
                            showingRecipePicker = true
                        },
                        onRemove: {
                            viewModel.removeMeal(for: date, context: modelContext)
                        }
                    )
                }
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - Day Row

struct DayRow: View {
    let date: Date
    let mealSlot: MealSlotModel?
    let isToday: Bool
    let onTapEmpty: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Date column
            VStack {
                Text(dayName.prefix(3).uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isToday ? .paprikaPrimary : .secondary)
                
                Text(dayNumber)
                    .font(.title2)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? .paprikaPrimary : .primary)
            }
            .frame(width: 50)
            
            // Meal slot
            if let slot = mealSlot {
                mealSlotView(slot)
            } else {
                emptySlotView
            }
        }
        .padding(Spacing.sm)
        .background(isToday ? Color.paprikaCream.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    private func mealSlotView(_ slot: MealSlotModel) -> some View {
        Text(slot.name)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .swipeActions(edge: .trailing) {
                Button("Replace", systemImage: "arrow.triangle.2.circlepath") {
                    onReplace()
                }
                .tint(.blue)
            }
            .swipeActions(edge: .leading) {
                Button("Remove", systemImage: "trash", role: .destructive) {
                    onRemove()
                }
            }
    }
    
    private var emptySlotView: some View {
        Button {
            onTapEmpty()
        } label: {
            HStack {
                Image(systemName: "plus.circle.dashed")
                Text("Add meal")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(.secondary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MealPlanView()
        .modelContainer(for: [RecipeModel.self, MealSlotModel.self], inMemory: true)
}
