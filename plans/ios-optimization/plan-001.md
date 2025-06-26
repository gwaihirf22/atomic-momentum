# Plan 001: Feature Migration from Web to Flutter

## Overview
Migrate critical features from the mature web application to the Flutter iOS app to achieve feature parity.

## Current Web Features Analysis

### Implemented in Web (Missing in Flutter)
1. **Calendar View**: Monthly calendar with habit completion visualization
2. **Category System**: Organize habits by categories (Body, Spirit, etc.)
3. **Streak Tracking**: Monitor consecutive completion streaks  
4. **Theme Support**: Dark/light mode toggle (partially in Flutter)
5. **Habit History**: Date-based completion tracking
6. **Category Filtering**: Filter habits by category in both main and calendar views
7. **Progress Visualization**: Visual progress bars and completion indicators
8. **Habit Management**: Full CRUD operations with rich editing
9. **Color Customization**: Custom color picker for habits
10. **Icon Selection**: Custom icon picker with habit-specific icons

### Partially Implemented in Flutter
- Basic habit display and progress tracking
- Theme switching (basic implementation)
- Add/edit habit screens (basic forms)

## Migration Priority

### Phase 1 (High Priority)
1. **Enhanced Habit Model**: Extend habit.dart to match web data structure
2. **Category System**: Add category management and filtering
3. **Streak Tracking**: Implement streak calculation and display
4. **Habit History**: Add date-based completion tracking

### Phase 2 (Medium Priority)  
1. **Calendar View**: Create Flutter calendar screen with habit visualization
2. **Advanced Theming**: Improve theme system to match web functionality
3. **Color/Icon Customization**: Add color picker and icon selector

### Phase 3 (Polish)
1. **Progress Animations**: Add smooth progress animations
2. **Enhanced UI**: Improve visual design and interactions
3. **Data Import**: Allow importing web app data

## Implementation Strategy

### 1. Data Model Extension
```dart
// Update lib/models/habit.dart to include:
- String category
- Map<String, bool> history  
- int streak
- DateTime? lastStreakDate
- TimeOfDay? reminderTime
- bool reminderEnabled
- String resetFrequency
```

### 2. Service Layer Enhancement
```dart
// Update lib/services/habit_service.dart to include:
- Category management methods
- Streak calculation logic
- History tracking methods
- Data import/export functionality
```

### 3. Screen Development
- Create CategoryScreen for category management
- Create CalendarScreen with habit visualization
- Enhance HomeScreen with category filtering
- Add habit statistics and streak displays

## Dependencies
- Requires completion of architecture plan for proper data layer
- Needs UI component library decisions for consistent theming
- Calendar widget selection (flutter_calendar_carousel, table_calendar, etc.)

## Success Metrics
- ✅ All web features available in Flutter app
- ✅ Data compatibility between web and Flutter versions
- ✅ Performance equal to or better than web version
- ✅ iOS-optimized user experience

## Estimated Timeline
- Phase 1: 1-2 weeks
- Phase 2: 2-3 weeks  
- Phase 3: 1 week
- **Total: 4-6 weeks**