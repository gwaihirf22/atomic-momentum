# 🐛 Atomic Momentum - Bug Tracker

This file tracks known bugs, issues, and small polish tasks during development and testing.

---

## 🔥 Critical Bugs (Must Fix Before Release)

| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| BUG-001 | Calendar view missing after restructure | ✅ Fixed | Created scripts/calendar.js and integrated with main.js |
| BUG-005 | Calendar global filter controls missing | ✅ Fixed | Added filter UI to calendar screen for filtering without day click |

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
| ENH-002 | Add animations to habit cards (fade in/out) | 🕒 Future Sprint | Cosmetic upgrade |

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
