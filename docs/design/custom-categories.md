# Design: user-defined categories

Status: **approved** (decisions below, 2026-10-16). Not built yet.

## Goal
Users can add, edit, reorder and remove categories, each with a name, color and an icon picked from a built-in library. Today's six categories (Body, Spirit, Mind, Social, Career, Creative) become the defaults. Existing habits keep working without any visible change.

## Where we are today
- `HabitCategory` is a Dart `enum`. Its name, color and icon are fixed in code.
  - `HabitCategory` is referenced 78 times across 19 files in `lib/`, and 6 test files use it.
  - The most affected files are `category_provider.dart` (15), `create_habit_usecase.dart` (10), `habit_provider.dart` (9) and `category_icons.dart` (7).
- **Stored data:** habits store their category by name, e.g. `"category": "body"`.
- **Rings:** the category rings, the Add Habit chips and the Calendar filter all loop over `HabitCategory.values`. The rings are sized for exactly six.

## Data model
```dart
class Category extends Equatable {
  final String id;          // stable key stored on habits
  final String name;        // shown in the UI, editable
  final String iconKey;     // key into the icon library
  final int colorValue;     // ARGB
  final int sortOrder;      // position in rings, chips and filters
  final DateTime? deletedAt; // set while in Recently Deleted; null when active
  final bool builtIn;       // the original six (only controls default seeding)
}
```
- `Habit.category` becomes `Habit.categoryId` (a `String`).
- Screens look up the `Category` through a `CategoryRepository`.
- `HabitCategory` is removed once nothing references it.

## Migration (no data rewrite needed)
- The six built-in categories get ids equal to today's enum names: `body`, `spirit`, `mind`, `social`, `career`, `creative`. Every stored habit (`"category": "body"`) therefore resolves unchanged.
- **First launch after the update:** if no categories are stored, the six defaults are written, with today's names, colors and icons.
- **Unknown or missing ids** (corrupt data) fall back to a visible "Uncategorized" category, never a crash.
- **Tests:**
  - a fixture with today's JSON loads with the same categories
  - a round-trip through the repository

## Storage
`CategoryRepository` is backed by SharedPreferences under its own key (`categories_v1`), following `SharedPreferencesDataSource`.
- **Operations:** `getAll`, `save`, `reorder`, `delete` (sets `deletedAt`), `restore` (clears it) and `deletePermanently`.
- **Shared state:** a `CategoryProvider` (the existing class, extended) holds the list for the UI.

## Icon library
- **Contents:** a curated map of about 40 flat Cupertino icons keyed by stable strings, e.g. `heart`, `book`, `briefcase`, `paintbrush`, `music_note`, `cart`, `moon`, `drop`, `leaf`, `flame`, `dumbbell`.
- **Why string keys:** storing a key rather than a code point keeps saved data valid if Flutter's icon font changes.
- **Location:** this replaces the `HabitCategoryIcon` extension (`lib/presentation/widgets/category_icons.dart`).
- **Picker:** the same 44pt grid as the habit icon picker on Add Habit, so both feel the same.

## UI
- **Categories page** (its own screen), opened from **Settings → Categories** or by long-pressing the category rings on the Habits screen:
  - The list shows each category's icon, name and number of habits.
  - **Add** opens a sheet with name, color (the existing 20-color palette) and icon.
  - **Edit** uses the same sheet. All categories are fully editable, built-in ones included: rename, recolor, change icon, delete.
  - **Reorder** with drag handles.
  - **Delete** moves the category to a **Recently Deleted** section at the bottom of the page, the same pattern as Photos and Notes.
    - Its habits are kept, with their history and streaks, and show as **Uncategorized** until the category is restored or the habits are moved.
    - **Restore** brings the category back and its habits rejoin it.
    - **Delete Permanently** is offered only once a deleted category has no habits left, so it can never remove habits or history.
  - Deleted categories aren't offered in pickers, rings or filters.
- **Habits screen rings:**
  - Up to 6 categories: unchanged, a single row.
  - More than 6: a horizontally **paged** row of 6 per page, with page dots and a swipe. This avoids the old scrolling-chip problems (partly visible chips, a scrollbar drawn over them).
  - The "All habits" header row stays as it is.
- **Add Habit category chips:** these already wrap onto extra lines, so any number works. Deleted categories aren't offered.
- **Calendar filter:** the chips are already horizontally scrollable, so more categories need no change.

## Limits
- Up to 24 categories, so rings stay at 4 pages or fewer.
- Names: 1–20 characters, unique, ignoring case.

## Implementation order
1. `Category` entity, icon library, repository and default seeding (unit tests).
2. Switch `Habit` to `categoryId` with the backward-compatible JSON (migration tests).
3. Move each screen from `HabitCategory.values` to the provider's list (widget tests per screen).
4. The Categories page with add, edit, reorder, delete, restore and delete-permanently rules (widget tests).
5. Paged rings past 6 categories (a widget test at 375pt width with 7 and 13 categories).
6. Remove `HabitCategory`.

## Decisions
1. **Built-in categories are fully editable.** The user can rename, recolor, change the icon of, or delete them. "Built-in" only means they are seeded on first launch.
2. **Deleting is recoverable.** Deleted categories go to Recently Deleted on the Categories page and can be restored. Permanent deletion is only possible for categories with no habits.
3. **About 40 icons**, curated, growing as needed.
4. **The Categories page is its own screen**, reached from Settings and by long-pressing the rings.
