# System Prompt / Project Specification: Local-First Sermon Management Application

---

## 1. Project Objective and Architecture

Develop a highly optimized, local-first Android application designed for sermon management and delivery. The primary constraint is cognitive load reduction; the target demographic possesses minimal technical literacy. The architecture must prioritize seamless offline operation, fault-tolerant data persistence, and an invisible state management lifecycle.

---

## 2. Core Technology Stack

- **Framework:** Flutter (target SDK: Android)
- **Database:** Isar Database. Selected for its highly performant NoSQL architecture, synchronous/asynchronous read/write support, and native full-text search indexing essential for querying sermon content.
- **State Management:** Riverpod with code generation (`@riverpod`). Preferred over Bloc for this scope — less ceremonial, faster to iterate, and sufficient for predictable UI rebuilds during real-time filtering and text input.

---

## 3. UX/UI Design Guidelines

### Design Reference
Follow **Material Design 3 (Material You)** — not Apple HIG. M3 ensures the app feels native to Android, respects the user's device dynamic color scheme, and provides better system integration out of the box. Apply generous whitespace, high-contrast typography for readability, and a strict visual hierarchy within M3 conventions.

### Navigation
Employ a flat navigation architecture. Avoid nested menus or hamburger drawers. The primary interface must surface a prominent Floating Action Button (FAB) for immediate sermon creation, alongside a clean, chronologically or dynamically sorted list of existing entries.

### Glassmorphism
Use frosted glass effects sparingly — limit to modal bottom sheets only. Avoid on primary surfaces. Prioritize readability in bright environments (e.g., a church sanctuary with natural light). Test against plain elevated cards as an alternative if legibility is affected.

### Dark Mode
Full dark mode support is required. Implement using M3 dynamic theming with `ThemeMode.system` as the default, plus a manual toggle in settings. Essential for evening services and low-light sermon preparation.

### Global Font Size Preference
A persistent font size setting with three steps: small, medium, large. Applied globally to the editor and list views. Stored in shared preferences. This is distinct from Pulpit Mode's dynamic scaling, which is contextual only.

---

## 4. Feature Specifications

### 4.1 Silent Auto-Save (Debouncer Pattern)
Explicit "Save" mechanisms are strictly prohibited. Implement a 1500ms debouncer attached to `TextEditingController` listeners. Upon execution, the debouncer triggers an asynchronous, non-blocking upsert transaction to the Isar database — ensuring zero data loss during session interruptions. The user should never be aware this is happening.

### 4.2 Robust Full-Text Search
Leverage Isar's native indexing to implement a real-time, low-latency search bar capable of querying sermon titles, tags, series names, and body content simultaneously. Search results update on every keystroke with no perceptible delay.

### 4.3 Pulpit Mode (Presentation State)
A dedicated presentation state toggled via a distinct UI element within the document view. Upon activation, the system must:

1. Strip all editing chrome and navigational elements from the UI.
2. Dynamically scale typography to a highly legible presentation size.
3. Invoke OS-level wakelock APIs via `wakelock_plus` to strictly prevent screen sleep or dimming during delivery.
4. Passively log the current timestamp to the sermon's `deliveryHistory` field.
5. Automatically transition sermon status from **Ready** → **Delivered** if not already in that state.

### 4.4 Constrained Rich Text Editing
Integrate `flutter_quill` with a **pinned version** (specify at project setup). Expose only the following formatting options: Bold, Italic, Underline, and limited Text Highlighting. All other toolbar items must be explicitly removed from the default configuration to prevent formatting inconsistencies and UI complexity.

### 4.5 Flat Tagging System
Discard nested folder architectures in favor of a flat, tag-based taxonomy. Implement actionable UI Chips allowing the user to assign and filter by contextual tags (e.g., Biblical books, thematic topics) directly from both the editor and the main dashboard.

### 4.6 Sermon Status
A single-tap status chip on each sermon with three states:

- **Draft** — work in progress
- **Ready** — prepared for delivery
- **Delivered** — has been preached at least once

Status is displayed as a colored chip on the dashboard card for instant visual scanning. Automatically transitions to Delivered on the first Pulpit Mode activation if the sermon is still in Ready state.

### 4.7 Series Grouping
Sermons can optionally belong to a named series (e.g., "Romans series", "Advent 2024"). Series is a flat label — not a folder or nested hierarchy. Displayed as a subtle subtitle on the dashboard card. Filterable from the dashboard alongside tags.

### 4.8 Preaching History Log
Each time a sermon enters Pulpit Mode, a timestamp is passively recorded in the `deliveryHistory` list. A dedicated history view — accessible from the sermon detail screen — displays all past delivery dates in chronological order. No manual input is required. This answers "when did I last preach this?" without friction.

### 4.9 Scripture Auto-Detection
A background text parser detects Bible reference patterns in the editor body (e.g., "João 3:16", "Salmos 23", "Mateus 5:3–12"). On detection, a non-intrusive inline chip appears, offering to display the verse text in a compact dismissible card. Requires a bundled offline Bible (public domain translation — e.g., Almeida Revised or equivalent). The verse card is purely informational and does not alter document content.

### 4.10 Pinned Sermons
Long-press or swipe action on any sermon card to toggle pin. Pinned sermons appear in a dedicated horizontal scroll section at the top of the dashboard, above the main list. Limit to 5 pinned items to prevent clutter. Useful for recurring sermons or active series in progress.

### 4.11 Swipe to Archive
Swipe-left gesture on a sermon card triggers archive — not deletion. Archived sermons are hidden from the main list and search results by default. An "Archived" filter option in the dashboard surfaces them when needed. A brief undo snackbar appears after archiving (3-second timeout). Permanent deletion is only possible from within the archive view, behind a confirmation dialog, to prevent accidental loss for non-technical users.

---

## 5. Data Model

### Sermon (Isar Collection)

| Field | Type | Notes |
|---|---|---|
| `id` | `Id` | Auto-incremented Isar ID |
| `title` | `String` | Indexed |
| `bodyJson` | `String` | Quill delta stored as JSON string |
| `tags` | `List<String>` | Indexed |
| `series` | `String?` | Nullable, indexed |
| `status` | `SermonStatus` | Enum: `draft`, `ready`, `delivered` |
| `isPinned` | `bool` | Default: false |
| `isArchived` | `bool` | Default: false |
| `createdAt` | `DateTime` | Set on first save |
| `updatedAt` | `DateTime` | Updated on every upsert |
| `deliveryHistory` | `List<DateTime>` | Appended on Pulpit Mode activation |

### SermonStatus (Enum)
```dart
enum SermonStatus { draft, ready, delivered }
```

---

## 6. Explicitly Excluded Features

The following are out of scope for this version and must not be implemented:

- Cloud sync or Google Drive backup
- PDF or print export
- Audio recording
- Collaboration or sharing features
- Push notifications
- Social sharing
- Manuscript vs. outline toggle

These may be revisited in a future release.

---

## 7. Screen-by-Screen Navigation Flow

### Overview
The app follows a flat, three-level navigation model: **Dashboard → Sermon Detail → Pulpit Mode**. All secondary screens (Settings, Archive, Series filter) branch off the Dashboard without adding depth to the main flow.

```
Dashboard
├── [FAB] → New Sermon (Sermon Editor)
├── [Sermon card tap] → Sermon Detail / Editor
│   ├── [Pulpit Mode toggle] → Pulpit Mode (full-screen)
│   └── [History icon] → Preaching History Log
├── [Search bar] → Filtered results (inline, same screen)
├── [Filter chips] → Tag / Series / Status / Archived filter (inline)
├── [Long-press card] → Pin / Unpin action
├── [Swipe left on card] → Archive (with undo snackbar)
└── [Settings icon] → Settings Screen
    ├── Dark mode toggle
    └── Font size preference (small / medium / large)
```

---

### Screen 1 — Dashboard (Home)

**Purpose:** Primary entry point. Surfaces all active sermons and provides instant access to search, filtering, and creation.

**Layout:**
- Top bar: app name (left), Settings icon (right)
- Search bar: below top bar, always visible, real-time filtering
- Filter chip row: horizontal scroll — All, Draft, Ready, Delivered, [series names], [tags], Archived
- Pinned section: horizontal card scroll, visible only when at least one sermon is pinned (max 5)
- Main list: vertical scroll of sermon cards, sorted by `updatedAt` descending by default
- FAB: bottom-right, creates a new sermon and navigates to Sermon Editor

**Sermon card anatomy:**
- Title (primary text)
- Series label (subtle, below title — hidden if no series assigned)
- Status chip (Draft / Ready / Delivered — color coded)
- Last updated date (muted, bottom-right)
- Tag chips (up to 3 visible, overflow with "+N more")

**Interactions:**
- Tap card → Sermon Detail
- Long-press card → Pin / Unpin contextual action
- Swipe left → Archive with undo snackbar
- Swipe right (optional) → Quick status cycle (Draft → Ready → Delivered)

---

### Screen 2 — Sermon Editor / Detail

**Purpose:** Create or edit a sermon. All changes are auto-saved silently via debouncer.

**Layout:**
- Back arrow (top-left) → returns to Dashboard
- Title field: large, prominent, top of screen
- Series field: small input below title (optional, with autocomplete from existing series)
- Tag chips row: below series — existing tags shown as chips, "+" chip to add new
- Status chip: tap to cycle through states (Draft / Ready / Delivered)
- Rich text editor body: occupies the remaining screen height
- Constrained toolbar: Bold, Italic, Underline, Highlight — pinned above the keyboard
- Pulpit Mode button: top-right icon (e.g., a podium or presentation icon)
- History icon: top-right (alongside Pulpit Mode) — navigates to Preaching History Log
- Scripture chip: appears inline when a Bible reference is detected — tap to expand verse card, dismiss with swipe or tap outside

**Behavior:**
- Auto-save triggers 1500ms after the last keystroke — no save button present
- Status auto-transitions to Delivered on first Pulpit Mode activation if currently Ready
- Back navigation is always safe — no unsaved state possible

---

### Screen 3 — Pulpit Mode (Full-Screen Presentation)

**Purpose:** Distraction-free reading view optimized for live sermon delivery.

**Layout:**
- Full-screen, all system UI and app chrome hidden
- Large, high-contrast typography (dynamically scaled)
- Sermon title at top in a slightly smaller weight
- Body text occupies the full screen with comfortable line height and padding
- Single exit button: small, unobtrusive icon (bottom-center or top corner) — tap to exit Pulpit Mode
- No editing controls, no navigation, no status bar

**Behavior:**
- OS wakelock activated on entry — screen will not sleep or dim
- Wakelock released on exit
- Delivery timestamp logged to `deliveryHistory` on entry
- Supports vertical scroll for long sermons
- Font size inherits the global preference setting, scaled up further for presentation

---

### Screen 4 — Preaching History Log

**Purpose:** Passive delivery record for a specific sermon.

**Layout:**
- Back arrow (top-left) → returns to Sermon Editor
- Screen title: "Delivery history"
- Sermon title (subtitle, muted)
- Chronological list of delivery timestamps — date and time, most recent first
- Empty state: "This sermon hasn't been preached yet" with a subtle illustration

**Behavior:**
- Read-only — no manual entry or editing
- Populated automatically by Pulpit Mode activations

---

### Screen 5 — Settings

**Purpose:** User preferences. Minimal — only what's necessary.

**Layout:**
- Back arrow (top-left) → returns to Dashboard
- Screen title: "Settings"
- Dark mode: toggle switch (default: system)
- Font size: segmented control — Small / Medium / Large (default: Medium)

**Behavior:**
- All changes apply immediately and persist via shared preferences
- No save button needed

---

### Screen 6 — Archive View

**Purpose:** Holds archived sermons, separated from the active list.

**Accessed via:** "Archived" filter chip on the Dashboard, or directly as a filtered state of the main list.

**Layout:**
- Identical card layout to the Dashboard main list
- Top label indicating "Archived sermons"
- Each card shows a "Restore" swipe action (swipe right) to unarchive
- Each card shows a "Delete permanently" action (swipe left or long-press) with a confirmation dialog

**Behavior:**
- Archived sermons are excluded from all search results and filter views by default
- Permanent deletion requires explicit confirmation dialog: "This sermon will be permanently deleted. This cannot be undone."
- Restore returns the sermon to its previous status and makes it visible in the main list

---

### Navigation Summary

| From | Action | Destination |
|---|---|---|
| Dashboard | Tap sermon card | Sermon Editor |
| Dashboard | Tap FAB | New Sermon (Sermon Editor) |
| Dashboard | Tap Settings icon | Settings |
| Dashboard | Tap "Archived" chip | Archive View |
| Sermon Editor | Tap Pulpit Mode icon | Pulpit Mode |
| Sermon Editor | Tap History icon | Preaching History Log |
| Sermon Editor | Tap back | Dashboard |
| Pulpit Mode | Tap exit button | Sermon Editor |
| Preaching History Log | Tap back | Sermon Editor |
| Settings | Tap back | Dashboard |
| Archive View | Tap back | Dashboard |
