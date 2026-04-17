# Design System

> *Maintained by: Designer*

## 🎯 Design Principle: Paprika Alignment

This design system is derived from **Paprika Recipe Manager 3**. MealPlanner should feel like a natural extension of Paprika, providing visual and interaction continuity.

### Paprika Audit Status

| Element | Audited | Documented | Notes |
|---------|---------|------------|-------|
| Color Palette | ⚪ TODO | ⚪ TODO | Extract from Paprika screenshots |
| Typography | ⚪ TODO | ⚪ TODO | Document type scale |
| Spacing | ⚪ TODO | ⚪ TODO | Measure padding/margins |
| Components | ⚪ TODO | ⚪ TODO | Recipe cards, lists, buttons |
| Iconography | ⚪ TODO | ⚪ TODO | SF Symbols or custom? |
| Motion | ⚪ TODO | ⚪ TODO | Animation timing/curves |

> **Action Required**: Designer agent must audit Paprika app and populate this design system with extracted values.

---

## Design Tokens

### Colors

#### Paprika-Derived Colors

<!-- TODO: Extract these from Paprika app screenshots -->

| Token | Light Mode | Dark Mode | Paprika Reference | Usage |
|-------|------------|-----------|-------------------|-------|
| `paprika.primary` | #[TBD] | #[TBD] | Main accent color | CTAs, links |
| `paprika.background` | #[TBD] | #[TBD] | App background | Main backgrounds |
| `paprika.surface` | #[TBD] | #[TBD] | Card backgrounds | Cards, elevated surfaces |
| `paprika.text` | #[TBD] | #[TBD] | Primary text | Body text |
| `paprika.textSecondary` | #[TBD] | #[TBD] | Secondary text | Captions, metadata |

#### Semantic Colors (Paprika-Aligned)

| Token | Light Mode | Dark Mode | Usage |
|-------|------------|-----------|-------|
| `primary` | [From Paprika] | [From Paprika] | CTAs, links, accents |
| `secondary` | [From Paprika] | [From Paprika] | Secondary text, icons |
| `background` | [From Paprika] | [From Paprika] | Main backgrounds |
| `surface` | [From Paprika] | [From Paprika] | Cards, elevated surfaces |
| `error` | System Red | System Red | Error states |
| `success` | System Green | System Green | Success states |

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

### Recipe Card (TODO: Document from Paprika)

```
┌─────────────────────────────────┐
│  [Recipe Image]                 │
│                                 │
│  Recipe Title                   │
│  Category • Cook Time           │
└─────────────────────────────────┘
```

**Paprika Observations**:
- [ ] Card corner radius: [TBD]pt
- [ ] Image aspect ratio: [TBD]
- [ ] Title font: [TBD]
- [ ] Metadata font: [TBD]
- [ ] Padding: [TBD]pt

### List Styles (TODO: Document from Paprika)

- [ ] Row height: [TBD]pt
- [ ] Separator style: [TBD]
- [ ] Selection highlight: [TBD]

---

## Deviations from Paprika

Document any intentional deviations from Paprika's design with rationale:

| Element | Paprika Style | Our Style | Rationale |
|---------|---------------|-----------|-----------|
| *None yet* | | | |

---

## Designer Checklist

Before any UI ships:

- [ ] Colors match Paprika palette
- [ ] Typography matches Paprika scale
- [ ] Spacing follows Paprika rhythm
- [ ] Recipe cards are visually consistent with Paprika
- [ ] Dark mode tested against Paprika dark mode
- [ ] Any deviations documented with rationale
