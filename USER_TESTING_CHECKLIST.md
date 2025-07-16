# User Testing Checklist - Atomic Momentum Flutter App

**Date:** July 5, 2025  
**App Status:** Phase 2 Complete - Ready for User Testing  
**Test Environment:** Web build available at `build/web/index.html`

## 🚀 How to Run the App

### Option 1: Flutter Run (Recommended)
```bash
cd /Users/paulblake/code/atomic-momentum
./flutter/bin/flutter run -d chrome
```

### Option 2: Serve Built Files
```bash
cd /Users/paulblake/code/atomic-momentum/build/web
python3 -m http.server 8080
# Then open: http://localhost:8080
```

## ✅ Core Functionality Testing

### 1. App Launch & Navigation
- [ ] **App launches successfully** in browser
- [ ] **Tab navigation works** - Can switch between Habits, Calendar, Settings
- [ ] **iOS-style navigation** - Smooth transitions between screens
- [ ] **No loading errors** - All screens load without crashes
- [ ] **Theme consistency** - UI looks clean and professional

### 2. Habit Management (Primary Feature)
- [x] **Create new habit** - Tap + button, fill form, save successfully ✅ FIXED
- [x] **Habit appears in list** - New habit shows up on home screen ✅ FIXED
- [x] **Navigation after creation** - Returns to home screen after adding habit ✅ FIXED
- [x] **Units input** - Can specify units like "glasses", "minutes", "reps" ✅ FIXED
- [x] **Frequency selection** - Can choose Daily/Weekly/Monthly/Never ✅ NEW FEATURE
- [ ] **Edit existing habit** - Can modify name, target, color, category
- [ ] **Delete habit** - Can remove habits from the list
- [x] **Progress tracking** - Can increment/decrement habit progress ✅ FIXED
- [x] **Completion state** - Progress bar shows correctly, completion detected ✅ FIXED

### 3. Category System
- [ ] **Category filtering** - Filter buttons work on home screen
- [ ] **"All" category** - Shows all habits when selected
- [ ] **Specific categories** - Body, Spirit, Mind, Social, Career, Creative filters work
- [ ] **Visual indicators** - Selected filter is highlighted
- [ ] **Category assignment** - Can assign categories when creating habits

### 4. Calendar View
- [ ] **Calendar displays** - Monthly calendar loads correctly
- [ ] **Month navigation** - Can navigate between months
- [ ] **Habit visualization** - Habits show on calendar days
- [ ] **Day selection** - Can click on days to see habit details
- [ ] **Category filtering in calendar** - Filter buttons work in calendar view
- [ ] **Progress indicators** - Completed vs incomplete habits shown

### 5. Settings & Theme
- [ ] **Settings screen loads** - No errors when navigating to settings
- [ ] **Theme toggle** - Can switch between light and dark mode
- [ ] **Theme persistence** - Theme choice is remembered after refresh
- [ ] **Consistent styling** - All screens respect theme choice

## 🎨 UI/UX Testing

### Visual Design
- [ ] **Professional appearance** - App looks polished and modern
- [ ] **Consistent spacing** - Margins and padding look uniform
- [ ] **Readable text** - All text is clear and properly sized
- [ ] **Color contrast** - Good readability in both light/dark themes
- [ ] **Progress indicators** - Progress bars are clear and intuitive
- [ ] **Category chips** - Filter buttons are visually appealing

### User Experience
- [ ] **Intuitive navigation** - Easy to find main features
- [ ] **Clear form inputs** - Easy to create and edit habits
- [ ] **Responsive feedback** - Actions feel responsive (buttons, taps)
- [ ] **Error handling** - Graceful handling of invalid inputs
- [ ] **Loading states** - Smooth transitions, no jarring changes

## 🔧 Data Persistence Testing

### Data Integrity
- [ ] **Data survives refresh** - Habits persist after browser refresh
- [ ] **Progress tracking** - Progress changes are saved correctly
- [ ] **Category persistence** - Category assignments are maintained
- [ ] **Theme persistence** - Theme choice survives app restart
- [ ] **Calendar data** - Historical progress shows correctly in calendar

### Edge Cases
- [ ] **Empty state** - App handles having no habits gracefully
- [ ] **Multiple habits** - Can create and manage 5+ habits effectively
- [ ] **Long habit names** - Handles lengthy habit names properly
- [ ] **High progress values** - Can handle progress near or above target
- [ ] **Date boundaries** - Calendar works across month boundaries

## 📱 Platform Testing

### Browser Compatibility
- [ ] **Chrome** - Full functionality works
- [ ] **Safari** - All features working (if available for testing)
- [ ] **Firefox** - Core features functional (if available for testing)
- [ ] **Mobile browser** - Responsive design works on phone browsers

### Performance
- [ ] **Fast startup** - App loads within 3-5 seconds
- [ ] **Smooth interactions** - No lag when tapping buttons or navigating
- [ ] **Memory usage** - No significant slowdown after extended use
- [ ] **Calendar performance** - Month navigation is smooth

## 🚨 Critical Issues to Report

### Blocking Issues (Stop Testing)
- App fails to load or crashes immediately
- Cannot create or save habits
- Data loss (habits disappear after refresh)
- Navigation completely broken

### High Priority Issues
- Major UI elements not working (buttons, forms)
- Theme switching broken
- Calendar view not functioning
- Progress tracking not saving

### Medium Priority Issues
- Visual inconsistencies
- Minor navigation issues
- Performance slowdowns
- Edge case handling problems

## 📝 Testing Notes Template

```
## Test Session: [Date/Time]
**Browser:** [Chrome/Safari/Firefox]
**Platform:** [Desktop/Mobile/Tablet]

### Successful Features:
- [ ] Feature 1: [Works/Doesn't Work] - Notes
- [ ] Feature 2: [Works/Doesn't Work] - Notes

### Issues Found:
1. **[Priority Level]** - [Issue Description]
   - Steps to reproduce: 
   - Expected behavior:
   - Actual behavior:

### Overall Impression:
- Professional appearance: [1-5 scale]
- Ease of use: [1-5 scale]
- Feature completeness: [1-5 scale]
```

## 🎯 Success Criteria

The app passes user testing if:
- ✅ **Core functionality works** - Can create, edit, delete habits
- ✅ **Data persists** - Information saves correctly
- ✅ **Navigation flows** - Can access all main features
- ✅ **Professional appearance** - Looks polished and complete
- ✅ **No critical bugs** - App is stable during normal use

## 🚀 Ready for Phase 3

After successful user testing, the app will be ready for Phase 3 development:
- Notification system implementation
- Enhanced customization features
- Data migration tools
- Advanced analytics

**Note:** This is a Flutter web build for testing. The final product will be a native iOS app with even better performance and iOS-specific features.