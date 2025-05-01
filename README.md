# Atomic Momentum

A habit tracking app that helps you build consistency in your daily routines through intelligent tracking, visual progress indicators, and motivational features.

## 📋 Project Overview

Atomic Momentum is a habit tracking application designed to help users build and maintain positive daily habits. The app provides a clean, intuitive interface for tracking progress, viewing habit history, and receiving motivational feedback based on habit streaks.

This project was initially planned as a Flutter mobile application, but is currently implemented as a web application with equivalent functionality to accommodate development constraints.

## 🚀 Features

### ✅ Core Functionality
- [x] Track multiple habits with visual progress bars
- [x] Increment/decrement progress with simple +/- buttons
- [x] Add, edit, and delete habits
- [x] Customize habits with name, target goal, color, and emoji icon
- [x] Set weekly reset frequency for habits
- [x] View complete/incomplete habits at a glance
- [x] Light/dark theme support
- [x] Organize habits by categories
- [x] Filter habits by category in main view and calendar

### 🔥 Habit Streaks & Motivation
- [x] Track consecutive completion streaks for each habit
- [x] Visual streak indicators (🔥 + count) next to habit names
- [x] Motivational messages when streaks continue or break

### 🗖️ Calendar View
- [x] Monthly calendar view with habit completion indicators
- [x] Navigate between months to review past performance
- [x] Daily detail view showing which habits were completed on selected day
- [x] Filter calendar by habit categories
- [x] Category-based filtering synchronized with main view

### 🔔 Notifications & Reminders
- [x] Set time-based reminders for individual habits
- [x] Global toggle for all notifications in settings
- [x] Permission request with proper browser support detection
- [x] Custom notification testing environment (notifications-test.html)

### 📂 Data Management
- [x] Persistent storage via localStorage
- [x] Automatic daily/weekly habit reset
- [x] Comprehensive habit history tracking
- [x] Records daily snapshots of habit completion status

## ⚙️ Technical Details

The application uses the following technologies:

- Frontend: HTML, CSS, JavaScript (Vanilla)
- Backend: Python SimpleHTTPServer
- Data Storage: localStorage (browser-based)
- Notifications: Web Notifications API

## ▶️ Getting Started

1. Clone this repository:
```
git clone https://github.com/yourusername/atomic-momentum.git
```

2. Navigate to the project directory:
```
cd atomic-momentum
```

3. Run the server:
```
python server.py
```

4. Open your browser to `http://localhost:5000`

### 💡 Running on Replit

The application is configured to run on Replit with minimal setup. Simply:

1. Click "Run" in the Replit environment
2. Access the application via the provided URL

## 📂 Project Structure

- `scripts/`: Contains JavaScript files like main.js, calendar.js, etc.
- `styles/`: Contains CSS files for modular styling
- `docs/`: Contains project documentation
  - `BUG_TRACKER.md`: Tracks known bugs and fixes
  - `ROADMAP.md`: High-level vision, feature backlog, and dev priorities

### 🖼️ Screenshots (To Be Updated)

| Feature | Screenshot |
|---------|------------|
| Dashboard | |
| Calendar View | |
| Edit Habit Modal | |

Screenshots will be added in future updates.

## 🚣 Next Steps & Future Development

See the `docs/ROADMAP.md` for detailed priorities.

### 📌 High Priority
- [ ] Implement proper multi-file structure (separate JS, CSS, HTML)
- [ ] Consider backend data storage instead of localStorage
- [ ] Add user authentication for multi-user support
- [ ] Improve mobile responsiveness and touch interaction

### 🌟 Feature Enhancements
- [x] Implement habit categories and organization
- [ ] Add statistics and insights based on habit history
- [ ] Create data visualization for long-term habit tracking
- [ ] Add social sharing or accountability features
- [ ] Create export/import functionality for habit data

### 🛠 Technical Improvements
- [ ] Implement the full Flutter mobile app version for native experience
- [ ] Write automated tests for core functionality
- [ ] Improve accessibility for screen readers and keyboard navigation
- [ ] Optimize performance for large habit histories

### 🐞 Bug Tracker

For known issues and polish tasks, check out the `docs/BUG_TRACKER.md`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

Last updated: April 2024
