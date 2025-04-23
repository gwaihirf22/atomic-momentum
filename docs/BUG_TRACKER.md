# 🐛 Atomic Momentum - Bug Tracker

This file tracks known bugs, issues, and small polish tasks during development and testing.

---

## 🔥 Critical Bugs (Must Fix Before Release)

| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| BUG-001 | Calendar view missing after restructure | ✅ Fixed | Created scripts/calendar.js and integrated with main.js |
| BUG-005 | Calendar global filter controls missing | ✅ Fixed | Added filter UI to calendar screen for filtering without day click |
| BUG-006 | Edit/delete icons too close together on habit cards | ✅ Fixed | Increased gap from 5px to 16px and improved touch targets |
| BUG-007 | Dark mode toggle overlaps container on small screens | ✅ Fixed | Added responsive layout with flexbox wrap and improved padding |
| BUG-008 | Excessive spacing in Habit Calendar view wastes vertical space | ✅ Fixed | Reduced margins and added responsive spacing using CSS classes |
| BUG-009 | Color Picker UI Not Ideal for Habit Creation | ✅ Fixed | Replaced full-spectrum picker with 8 preset color swatches + "Other" rainbow option |
| BUG-010 | Icon Picker Shows Irrelevant or Generic Icons | 🚧 To Do | Add curated set of habit-specific monochrome icons for common habit types |
| BUG-011 | Habit Count Updates Cause Full Habit List Re-render | 🚧 To Do | Optimize updates to only re-render the modified habit card instead of the full list |
| BUG-012 | Calendar Navigation Arrows Are Stacked Vertically | ✅ Fixed | Fixed the month navigation arrows to appear side by side with flexbox layout |

---

## ⚡ Minor Bugs (Polish Later)

| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| BUG-002 | Notifications test text does not immediately update after theme toggle | ✅ Fixed | Fixed by updating notificationsTitle.style.color in onchange handler |
| BUG-003 | Minor color mismatch between light/dark modes (small text color) | 🚧 To Do | Visual only — no functional issue |
| BUG-004 | Home page doesn't properly apply dark mode theme | ✅ Fixed | Fixed by adding data-theme attribute to body element in applyTheme() |

---

## 📈 Enhancements (Not bugs, but improvement ideas)

| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| ENH-001 | Replace dynamic JS hardcoded colors with CSS variables | 🕒 Future Sprint | Not critical now |
| ENH-002 | Add animations to habit cards (fade in/out) | ✅ Completed | Added hover effects, transitions, and staggered load animations |
| ENH-003 | Enhance progress bar with animated transitions | ✅ Completed | Added smooth animations, subtle gradient pattern, and completion flash effect |

---

# 🧹 How to Update This File:

- When you discover a bug during testing, add a new entry under Critical or Minor sections.
- Update the `Status` field as you work:
  - 🚧 To Do
  - 🛠️ In Progress
  - ✅ Fixed
- Move old fixed bugs to a "Historical Bugs" section if desired.

---

# 🛡️ Bug Tracker Last Updated:

`April 22, 2025`
