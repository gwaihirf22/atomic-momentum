# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Atomic Momentum is a habit tracking application with dual implementations:
- **Web application** (primary/active): HTML/CSS/JavaScript with Python server
- **Flutter mobile app** (planned): Dart/Flutter implementation in development

The project focuses on helping users build and maintain positive daily habits with visual progress tracking, streak monitoring, and category-based organization.

## Development Commands

### Web Application (Primary)
```bash
# Start the development server
python server.py
# Server runs on http://localhost:8000

# Alternative server start (if needed)

```

### Flutter Application (Secondary)
```bash
# Install Flutter dependencies
flutter pub get

# Run Flutter app (development)
flutter run

# Build for production
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web

# Run Flutter linting
flutter analyze

# Run Flutter tests  
flutter test
```

## Architecture Overview

### Web Application Structure
- **Entry Point**: `templates/index.html` served via `server.py`
- **Core Logic**: Modular JavaScript in `scripts/` directory
  - `main.js` - Main application logic and habit management
  - `calendar.js` - Calendar view functionality  
  - `theme.js` - Dark/light mode management
  - `utils.js` - Utility functions and helpers
  - `services/storageService.js` - localStorage data persistence
- **Styling**: CSS files in `styles/` directory
- **Data Storage**: Browser localStorage (no backend database)
- **Server**: Simple Python HTTP server for static file serving

### Key Components
- **Habit Management**: Create, edit, delete habits with progress tracking
- **Calendar View**: Monthly calendar with habit completion visualization
- **Category System**: Organize habits by categories (Body, Spirit, etc.)
- **Streak Tracking**: Monitor consecutive completion streaks
- **Theme Support**: Light/dark mode toggle
- **Notifications**: Browser-based reminder system

### Data Flow
1. Habits stored in localStorage as JSON objects
2. Each habit includes: progress, target, name, color, category, history, streaks
3. Daily snapshots saved to habit history for calendar display
4. Category filtering applied to both main view and calendar

### Flutter App Structure
- **Entry Point**: `lib/main.dart`
- **Screens**: `lib/screens/` - UI screens (home, settings, add habit)
- **Models**: `lib/models/` - Data models (habit.dart)
- **Providers**: `lib/providers/` - State management (theme_provider.dart)
- **Services**: `lib/services/` - Business logic (habit_service.dart)

## Development Practices

### Code Organization Priorities
Based on `.cursorrules` and roadmap:
1. **High Priority**: Separate monolithic code into modular components
2. **Medium Priority**: Improve mobile responsiveness and error handling
3. **Future**: Migrate from localStorage to proper backend

### File Modifications
- **Primary Development**: Focus on `scripts/`, `styles/`, and `templates/` directories
- **Server Changes**: Modify `server.py` only for routing/serving needs
- **Flutter**: Work in `lib/` directory when developing mobile features

### Testing Strategy
- **Web App**: Manual testing via browser (no automated tests currently)
- **Flutter**: Use `flutter test` for unit tests
- **Integration**: Test on multiple devices/browsers for responsiveness

### Current Development Status
- **Active Issues**: See `docs/BUG_TRACKER.md` for known bugs and polish tasks
- **Roadmap**: See `docs/ROADMAP.md` for feature priorities and development timeline
- **Recently Completed**: Category filtering, habit initialization fixes, dark mode improvements

## Key Implementation Details

### Habit Data Structure
```javascript
{
  id: "unique_habit_id",
  name: "Habit Name",
  progress: 5,
  target: 8,
  color: "#2196F3",
  category: "Body",
  resetFrequency: "weekly",
  history: {}, // Date-based completion tracking
  streak: 0,
  lastStreakDate: null,
  reminderTime: null,
  reminderEnabled: false
}
```

### Storage Service Pattern
- Use `getHabits()` and `saveHabits()` from `storageService.js`
- Habit history stored separately via `loadHabitHistory()` and `saveHabitHistory()`
- All data persistence goes through storage service abstraction

### Theme System
- Theme state managed in `theme.js`
- Apply theme changes via `applyTheme()` function
- Dark/light mode preference stored in localStorage

### Common Development Tasks

#### Adding New Habit Features
1. Update habit data structure in `main.js` defaultHabits
2. Modify habit creation/editing logic in form handlers
3. Update display logic in habit rendering functions
4. Test with calendar view integration

#### Modifying Calendar Functionality
1. Calendar logic in `scripts/calendar.js`
2. Habit completion data retrieved from habit history
3. Category filtering integrated with main view filters
4. Day detail popups show habit-specific information

#### Styling Changes
1. Main styles in `styles/main.css`
2. Calendar-specific styles in `styles/calendar.css`
3. Theme variables defined for dark/light mode support
4. Responsive design considerations for mobile devices