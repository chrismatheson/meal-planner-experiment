import Foundation

/// What a slot-pinning rule constrains the day to
enum SlotConstraint: Equatable, Hashable {
    /// Pin to a specific recipe by uid
    case recipe(uid: String, name: String)
    /// Pin to any recipe in a Paprika category
    case category(uid: String, name: String)
    /// Freeform label (e.g. "Takeaway", "Leftovers") — not tied to Paprika data
    case freeform(label: String)
    
    var displayName: String {
        switch self {
        case .recipe(_, let name): return name
        case .category(_, let name): return name
        case .freeform(let label): return label
        }
    }
    
    var icon: String {
        switch self {
        case .recipe: return "book.closed"
        case .category: return "folder"
        case .freeform: return "tag"
        }
    }
    
    var subtitle: String {
        switch self {
        case .recipe: return "Specific recipe"
        case .category: return "Any from category"
        case .freeform: return "Custom label"
        }
    }
}

/// A single slot-pinning rule: "Every [dayOfWeek] → [constraint]"
struct SlotRule: Identifiable, Equatable, Hashable {
    let id: UUID
    /// 1 = Sunday, 2 = Monday, ..., 7 = Saturday (Calendar weekday)
    var dayOfWeek: Int
    var constraint: SlotConstraint
    
    init(id: UUID = UUID(), dayOfWeek: Int, constraint: SlotConstraint) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.constraint = constraint
    }
    
    /// Short day name: "Mon", "Tue", etc.
    var shortDayName: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "?" }
        return symbols[dayOfWeek - 1]
    }
    
    /// Full day name: "Monday", "Tuesday", etc.
    var fullDayName: String {
        let symbols = Calendar.current.weekdaySymbols
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "?" }
        return symbols[dayOfWeek - 1]
    }
}

// MARK: - Preview Data

extension SlotRule {
    static let previews: [SlotRule] = [
        SlotRule(dayOfWeek: 6, constraint: .freeform(label: "Takeaway")),
        SlotRule(dayOfWeek: 1, constraint: .category(uid: "cat-1", name: "Sunday Roast")),
        SlotRule(dayOfWeek: 4, constraint: .recipe(uid: "rec-1", name: "Spaghetti Carbonara")),
    ]
}
