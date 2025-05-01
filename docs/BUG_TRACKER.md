# 🐞 Bug Tracker

## Recently Fixed Issues
- ✅ Fixed: New habits showing undefined progress and incorrect completion status when initially created
- ✅ Fixed: Category filtering in calendar view implementation and integration
- ✅ Fixed: Calendar grid initialization and rendering issues
- ✅ Fixed: Progress initialization for new habits

## Known Issues
- ⚠️ BUG-001: Touch interactions need improvement on mobile devices
- ⚠️ BUG-002: Dark mode transition could be smoother
- ⚠️ BUG-003: Calendar view performance could be optimized for large habit histories
- ⚠️ BUG-004: Notification permissions could be handled more gracefully
- ⚠️ BUG-005: Weekly reset timing might need adjustment for different timezones
- ⚠️ BUG-006: Streak calculation edge cases need review
- ⚠️ BUG-007: LocalStorage limits could affect users with many habits
- ⚠️ BUG-008: Form validation feedback could be more user-friendly
- ⚠️ BUG-009: Category filter state persistence between views
- ⚠️ BUG-010: Need to replace generic icons with curated habit-specific icons

## Polish Tasks
- 🔧 POL-001: Add loading states for smoother transitions
- 🔧 POL-002: Improve error message styling
- 🔧 POL-003: Add more visual feedback for user actions
- 🔧 POL-004: Enhance button hover/active states
- 🔧 POL-005: Standardize spacing and margins
- 🔧 POL-006: Improve form field styling consistency
- 🔧 POL-007: Add subtle animations for state changes
- 🔧 POL-008: Enhance calendar day hover states
- 🔧 POL-009: Improve category filter button styling
- 🔧 POL-010: Add tooltips for better UX

## Accessibility Improvements
- ♿ ACC-001: Add proper ARIA labels
- ♿ ACC-002: Improve keyboard navigation
- ♿ ACC-003: Enhance screen reader compatibility
- ♿ ACC-004: Add skip links for navigation
- ♿ ACC-005: Improve color contrast ratios

# 🐛 Atomic Momentum - Bug Tracker

This file tracks known bugs, issues, and small polish tasks during development and testing.

## 🔥 Critical Bugs

| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| BUG-001 | Calendar view missing after restructure | ✅ Fixed | Created scripts/calendar.js and integrated with main.js |
| BUG-005 | Calendar global filter controls missing | ✅ Fixed | Added filter UI to calendar screen for filtering without day click |
| BUG-006 | Edit/delete icons too close together on habit cards | ✅ Fixed | Increased gap from 5px to 16px and improved touch targets |
| BUG-007 | Dark mode toggle overlaps container on small screens | ✅ Fixed | Added responsive layout with flexbox wrap and improved padding |
| BUG-008 | Excessive spacing in Habit Calendar view wastes vertical space | ✅ Fixed | Reduced margins and added responsive spacing using CSS classes |
| BUG-009 | Color Picker UI Not Ideal for Habit Creation | ✅ Fixed | Replaced full-spectrum picker with 8 preset color swatches + "Other" rainbow option |
| BUG-010 | Icon Picker Shows Irrelevant or Generic Icons | 🚧 To Do | Add curated set of habit-specific monochrome icons for common habit types |
| BUG-011 | Habit Count Updates Cause Full Habit List Re-render | ✅ Fixed | Fixed habit card update system - now properly updates only the changed habit without page reload, and maintains button functionality |
| BUG-012 | Calendar Navigation Arrows Are Stacked Vertically | ✅ Fixed | Fixed the month navigation arrows to appear side by side with flexbox layout |
| BUG-013 | Habits with valid categories not appearing under filters | ✅ Fixed | Fixed category comparison logic in filterHabitsByCategory and updateHabitCardInDOM |
| BUG-014 | Category filter buttons break after navigating away and returning home | ✅ Fixed | AI fixed somehow. ?setupCategoryFilters likely not re-invoked on route/page change |

## ⚡ Minor Bugs

| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| BUG-002 | Notifications test text does not immediately update after theme toggle | ✅ Fixed | Fixed by updating notificationsTitle.style.color in onchange handler |
| BUG-003 | Minor color mismatch between light/dark modes (small text color) | 🚧 To Do | Visual only — no functional issue |
| BUG-004 | Home page doesn't properly apply dark mode theme | ✅ Fixed | Fixed by adding data-theme attribute to body element in applyTheme() |

## 🎨 Polish Tasks
| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| POL-001 | Add loading states for smoother transitions | 🚧 To Do | Improve UX during data operations |
| POL-002 | Improve error message styling | 🚧 To Do | Make error feedback more user-friendly |
| POL-003 | Add more visual feedback for user actions | 🚧 To Do | Enhance interaction feedback |
| POL-004 | Enhance button hover/active states | 🚧 To Do | Improve button interactivity |
| POL-005 | Standardize spacing and margins | 🚧 To Do | Ensure consistent layout |
| POL-006 | Improve form field styling consistency | 🚧 To Do | Unify form element appearance |
| POL-007 | Add subtle animations for state changes | 🚧 To Do | Enhance visual transitions |
| POL-008 | Enhance calendar day hover states | 🚧 To Do | Improve calendar interactivity |
| POL-009 | Improve category filter button styling | 🚧 To Do | Make filters more visually appealing |
| POL-010 | Add tooltips for better UX | 🚧 To Do | Provide additional context for UI elements |

## ♿ Accessibility Improvements
| ID | Description | Status | Notes |
|:--|:------------|:------|:-----|
| ACC-001 | Add proper ARIA labels | 🚧 To Do | Improve screen reader support |
| ACC-002 | Improve keyboard navigation | 🚧 To Do | Enhance keyboard accessibility |
| ACC-003 | Enhance screen reader compatibility | 🚧 To Do | Better screen reader experience |
| ACC-004 | Add skip links for navigation | 🚧 To Do | Improve navigation accessibility |
| ACC-005 | Improve color contrast ratios | 🚧 To Do | Meet WCAG guidelines |

---

# 🧹 How to Update This File:

- When you discover a bug during testing, add a new entry under the appropriate section.
- Update the `Status` field as you work:
  - 🚧 To Do
  - 🛠️ In Progress
  - ✅ Fixed
- Move fixed bugs to the project's changelog once completed.

---

# 🛡️ Bug Tracker Last Updated:

`April 29, 2024`
