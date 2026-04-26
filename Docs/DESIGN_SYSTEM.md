# Design System

> *Maintained by: Designer*

## 🎯 Design Principle: Paprika Alignment

This design system is derived from **Paprika Recipe Manager 3**. MealPlanner should feel like a natural extension of Paprika, providing visual and interaction continuity.

### Paprika Audit Status

| Element | Audited | Documented | Notes |
|---------|---------|------------|-------|
| Color Palette | ✅ Done | ✅ Done | Warm paprika-inspired palette |
| Typography | ✅ Done | ✅ Done | San Francisco system font |
| Spacing | ✅ Done | ✅ Done | 8pt base grid |
| Components | ✅ Done | ✅ Done | Recipe cards, lists documented |
| Iconography | ✅ Done | ✅ Done | SF Symbols throughout |
| Motion | ✅ Done | ✅ Done | iOS standard spring animations |

> **Audit completed**: 2026-04-17 by Designer Agent

---

## Design Tokens

### Colors

#### Paprika Brand Colors

The Paprika app uses a warm, earthy color palette inspired by the paprika spice:

| Token | Hex Value | Name | Usage |
|-------|-----------|------|-------|
| `paprika.deep` | #8D0227 | Paprika Deep | Badges, emphasis |
| `paprika.primary` | #D94A3A | Valencia | Primary CTAs, links, accents |
| `paprika.warm` | #F4A462 | Sandy Brown | Highlights, warm accents |
| `paprika.light` | #F7D3A1 | Maize | Subtle backgrounds |
| `paprika.cream` | #F2E5D4 | Parchment | Card backgrounds (light mode) |

#### Semantic Colors (Paprika-Aligned)

| Token | Light Mode | Dark Mode | Usage |
|-------|------------|-----------|-------|
| `primary` | #D94A3A | #E8A56A | CTAs, links, accents |
| `secondary` | System Gray | System Gray 2 | Secondary text, icons |
| `background` | #FFFFFF | #000000 | Main backgrounds |
| `surface` | #F2E5D4 | #1C1C1E | Cards, elevated surfaces |
| `error` | System Red | System Red | Error states |
| `success` | System Green | System Green | Success states |

```swift
// SwiftUI Color extension
extension Color {
    static let paprikaPrimary = Color(hex: "D94A3A")
    static let paprikaDeep = Color(hex: "8D0227")
    static let paprikaCream = Color(hex: "F2E5D4")
}
```

### Typography

#### Type Scale

| Style | Font | Size | Weight | Line Height | Usage |
|-------|------|------|--------|-------------|-------|
| `largeTitle` | System | 34pt | Bold | 41pt | Screen titles |
| `title` | System | 28pt | Bold | 34pt | Section headers |
| `headline` | System | 17pt | Semibold | 22pt | Card titles |
| `body` | System | 17pt | Regular | 22pt | Body text |
| `callout` | System | 16pt | Regular | 21pt | Callouts |
| `subheadline` | System | 15pt | Regular | 20pt | Secondary text |
| `footnote` | System | 13pt | Regular | 18pt | Captions |
| `caption` | System | 12pt | Regular | 16pt | Timestamps |

```swift
// Usage
Text("Title").font(.headline)
Text("Body").font(.body)
```

### Spacing

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 2pt | Tight gaps |
| `xs` | 4pt | Icon padding |
| `sm` | 8pt | Compact spacing |
| `md` | 16pt | Standard spacing |
| `lg` | 24pt | Section spacing |
| `xl` | 32pt | Major sections |
| `xxl` | 48pt | Page margins |

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `small` | 4pt | Badges, tags |
| `medium` | 8pt | Buttons, inputs |
| `large` | 12pt | Cards |
| `xl` | 16pt | Modal sheets |
| `full` | 9999pt | Pills, avatars |

---

## Components

### Buttons

#### Primary Button
```swift
Button("Action") { }
    .buttonStyle(.borderedProminent)
```

#### Secondary Button
```swift
Button("Action") { }
    .buttonStyle(.bordered)
```

#### Destructive Button
```swift
Button("Delete", role: .destructive) { }
```

### Cards

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.md)
            .background(.regularMaterial)
            .cornerRadius(.large)
    }
}
```

### Input Fields

```swift
TextField("Placeholder", text: $value)
    .textFieldStyle(.roundedBorder)
```

### Lists

```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
.listStyle(.insetGrouped)
```

---

## Iconography

### System Symbols (SF Symbols)

| Purpose | Symbol | Usage |
|---------|--------|-------|
| Add | `plus` | Adding items |
| Delete | `trash` | Removing items |
| Edit | `pencil` | Editing |
| Settings | `gear` | Settings |
| Search | `magnifyingglass` | Search |
| Close | `xmark` | Dismissing |

```swift
Image(systemName: "plus")
    .imageScale(.large)
```

---

## Animation

### Duration Scale

| Token | Value | Usage |
|-------|-------|-------|
| `fast` | 0.15s | Micro-interactions |
| `normal` | 0.3s | Standard transitions |
| `slow` | 0.5s | Emphasis animations |

### Standard Animations

```swift
// Spring animation (default)
withAnimation(.spring()) { }

// Smooth transition
withAnimation(.easeInOut(duration: 0.3)) { }
```

---

## Accessibility

### Minimum Sizes
- Tap targets: **44×44pt** minimum
- Text: **11pt** minimum (use Dynamic Type)

### Color Contrast
- Normal text: **4.5:1** minimum
- Large text: **3:1** minimum

---

## Dark Mode

All components must support Dark Mode. Use semantic colors:

```swift
// ✅ Do
.foregroundStyle(.primary)
.background(.regularMaterial)

// ❌ Don't
.foregroundColor(.black)
.background(Color.white)
```

---

## Paprika Component Reference

### Recipe Card (Grid View)

```
┌─────────────────────────────────┐
│  ┌───────────────────────────┐  │
│  │                           │  │
│  │      Recipe Image         │  │
│  │        (1:1)              │  │
│  │                           │  │
│  └───────────────────────────┘  │
│  Recipe Title (17pt Semibold)   │
│  Category • 45 min (13pt Gray)  │
└─────────────────────────────────┘
```

**Paprika Specs**:
- Card corner radius: **12pt**
- Image aspect ratio: **1:1** (square)
- Title font: **17pt Semibold** (headline)
- Metadata font: **13pt Regular** (footnote), secondary color
- Card padding: **16pt** all sides
- Grid gap: **8pt** between cards
- Grid columns: **2-3** on iPhone, **3-4** on iPad

### Recipe Card (List View)

```
┌──────────────────────────────────────────────┐
│ ┌────┐                                       │
│ │    │  Recipe Title (17pt)            〉    │
│ │ 44 │  Category • 45 min (15pt gray)        │
│ └────┘                                       │
└──────────────────────────────────────────────┘
```

**List Specs**:
- Row height: **60-72pt** (with metadata)
- Thumbnail size: **44×44pt**
- Separator: Full-width, system gray
- Disclosure indicator: Chevron right

---

## Deviations from Paprika

Document any intentional deviations from Paprika's design with rationale:

| Element | Paprika Style | Our Style | Rationale |
|---------|---------------|-----------|-----------|
| Meal card thumbnail | 44×44pt | 80×80pt | Card-based layout benefits from larger images for meal planning context |
| Card layout | List-style rows | Card grid | Week view needs at-a-glance scanning; cards provide better visual separation |
| Hero image (detail) | N/A | 280pt edge-to-edge | RecipeDetailView is a new screen type; hero image provides visual impact |

---

## Designer Checklist

Before any UI ships:

- [ ] Colors match Paprika palette
- [ ] Typography matches Paprika scale
- [ ] Spacing follows Paprika rhythm
- [ ] Recipe cards are visually consistent with Paprika
- [ ] Dark mode tested against Paprika dark mode
- [ ] Any deviations documented with rationale
