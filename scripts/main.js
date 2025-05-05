// Default habits to use if none are saved
const defaultHabits = {
    habit_water_default: { 
        progress: 5, 
        target: 8, 
        name: "Drink Water", 
        color: "#2196F3",
        category: "Body",
        lastUpdatedDate: new Date().toISOString(),
        resetFrequency: "weekly",
        history: {}, // Store habit history by date
        streak: 0,   // Current streak count
        lastStreakDate: null, // Last date the streak was updated
        reminderTime: null, // Optional time for daily reminder
        reminderEnabled: false // Whether notifications are enabled for this habit
    },
    habit_bible_default: { 
        progress: 3, 
        target: 7, 
        name: "Read Bible", 
        color: "#009688",
        category: "Spirit",
        lastUpdatedDate: new Date().toISOString(),
        resetFrequency: "weekly",
        history: {}, // Store habit history by date
        streak: 0,   // Current streak count
        lastStreakDate: null, // Last date the streak was updated
        reminderTime: null, // Optional time for daily reminder
        reminderEnabled: false // Whether notifications are enabled for this habit
    },
    habit_workout_default: { 
        progress: 7, 
        target: 7, 
        name: "Workout", 
        color: "#FF9800",
        category: "Body",
        lastUpdatedDate: new Date().toISOString(),
        resetFrequency: "weekly",
        history: {}, // Store habit history by date
        streak: 0,   // Current streak count
        lastStreakDate: null, // Last date the streak was updated
        reminderTime: null, // Optional time for daily reminder
        reminderEnabled: false // Whether notifications are enabled for this habit
    }
};

// Import the storage service
import { getHabits, saveHabits as saveHabitsToStorage } from './services/storageService.js';

// Initialize the app when this module is loaded
document.addEventListener('DOMContentLoaded', init);

// Our in-memory habits
let habits = {};

// Function to generate a unique ID for habits
function generateHabitId() {
    // Check if a counter exists in localStorage
    let habitCounter = parseInt(localStorage.getItem('habitCounter') || '0');
    
    // Increment the counter
    habitCounter++;
    
    // Store the updated counter
    localStorage.setItem('habitCounter', habitCounter.toString());
    
    // Return a unique ID with the counter
    return `habit_${habitCounter}_${Date.now()}`;
}

// Function to format date as YYYY-MM-DD for consistent history keys
function formatDate(date) {
    // Ensure we're working with a Date object
    const d = date instanceof Date ? date : new Date(date);
    // Get local date components
    const year = d.getFullYear();
    const month = d.getMonth() + 1; // getMonth() returns 0-11
    const day = d.getDate();
    // Format as YYYY-MM-DD using local date components
    return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

// Get today's date in YYYY-MM-DD format
function getTodayFormatted() {
    const now = new Date();
    return formatDate(now);
}

// Function to get a consistent date string for a specific year/month/day
function getLocalDateString(year, month, day) {
    // month is 0-based in JavaScript Date
    const localDate = new Date(year, month, day);
    return formatDate(localDate);
}

// Global theme management
function isDarkModeEnabled() {
    return localStorage.getItem('isDarkMode') === 'true';
}

// Theme change listeners (for reactive updates)
const themeListeners = [];

function addThemeListener(callback) {
    themeListeners.push(callback);
}

function notifyThemeChange() {
    const isDark = isDarkModeEnabled();
    themeListeners.forEach(listener => listener(isDark));
}

// Load habits from localStorage
function loadHabits() {
    // ... existing code ...
    
    // Try to load habits from localStorage
    const savedHabits = getHabits();
    if (Object.keys(savedHabits).length > 0) {
        habits = savedHabits;
        
        // Convert datestring fields back to Date objects
            Object.keys(habits).forEach(habitId => {
                const habit = habits[habitId];
                
            // Ensure that the ID is stored in the habit object for consistency
            if (!habit.id) {
                habit.id = habitId;
            }
            
            if (habit.lastUpdatedDate) {
                habit.lastUpdatedDate = new Date(habit.lastUpdatedDate);
            }
            if (habit.lastStreakDate) {
                habit.lastStreakDate = new Date(habit.lastStreakDate);
            }
        });
    } else {
        // If no habits found, use defaults
        habits = defaultHabits;
        console.log('No saved habits found, using defaults');
        
        // Ensure default habits have their ids set
        Object.keys(habits).forEach(habitId => {
            if (!habits[habitId].id) {
                habits[habitId].id = habitId;
            }
        });
        
        saveHabitsToStorage(habits); // Save the defaults
    }
    
    // Ensure habit objects have all required properties
    Object.keys(habits).forEach(habitId => {
        if (!habits[habitId].history) {
            habits[habitId].history = {};
        }
        if (!habits[habitId].streak) {
            habits[habitId].streak = 0;
        }
        if (!habits[habitId].lastStreakDate) {
            habits[habitId].lastStreakDate = null;
        }
        if (habits[habitId].reminderEnabled === undefined) {
            habits[habitId].reminderEnabled = false;
        }
        if (!habits[habitId].category) {
            habits[habitId].category = 'Other';
        }
    });
    
    // Setup event listeners after habits are loaded
    setupEventListeners();
    
    return habits;
}

// Save habits to localStorage with proper category capitalization
function saveHabits() {
    try {
        // Ensure all categories are properly capitalized before saving
        Object.values(habits).forEach(habit => {
            habit.category = capitalizeCategory(habit.category || "Other");
        });
        
        saveHabitsToStorage(habits);
    } catch (e) {
        console.error('Error saving habits:', e);
    }
}

// Load habit history from localStorage
function loadHabitHistory() {
    const savedHistory = localStorage.getItem('habit_history');
    if (savedHistory) {
        try {
            return JSON.parse(savedHistory);
        } catch (e) {
            console.error('Error loading habit history from localStorage:', e);
            return {};
        }
    }
    return {};
}

// Save habit history to localStorage
function saveHabitHistory(history) {
    try {
        localStorage.setItem('habit_history', JSON.stringify(history));
        console.log('Saved habit history to localStorage');
    } catch (e) {
        console.error('Error saving habit history to localStorage:', e);
    }
}

// Record daily habit status (for history tracking)
function recordDailyHabitStatus() {
    const currentDate = getTodayFormatted();
    const habitHistory = loadHabitHistory();
    
    // Ensure the date entry exists
    if (!habitHistory[currentDate]) {
        habitHistory[currentDate] = {};
    }
    
    // Loop through all habits and record their status
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        const isCompleted = habit.progress >= habit.target;
        
        // Update global history
        habitHistory[currentDate][habitId] = isCompleted ? "completed" : "not_completed";
        
        // Update habit's own history
        if (!habit.history) {
            habit.history = {};
        }
        habit.history[currentDate] = isCompleted ? "completed" : "not_completed";
    });
    
    // Save both global history and habits
    saveHabitHistory(habitHistory);
    saveHabitsToStorage(habits);
    
    console.log('Recorded habit status for', currentDate, habitHistory[currentDate]);
}

// Render all habits in the UI
function renderHabits() {
    // Get current category filter before clearing container
    const currentFilter = document.querySelector('.category-filter.active')?.dataset.category || 'All';
    
    const container = document.getElementById('habits-container');
    container.innerHTML = ''; // Clear existing habits
    container.style.padding = '0 10px'; // Ensure padding applies to dynamically generated content
    
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        const habitElement = createHabitElement(habitId, habit);
        container.appendChild(habitElement);
    });
    
    // Reapply current category filter if not "All"
    if (currentFilter !== 'All') {
        filterHabitsByCategory(currentFilter);
    }
    
    // Add debug output to confirm colors
    console.log("Rendered habits with colors:", 
        Object.keys(habits).map(id => ({ 
            name: habits[id].name, 
            color: habits[id].color 
        }))
    );
    
    // Update statistics
    updateStats();
}

// Create a habit card element
function createHabitElement(habitId, habit) {
    // Use the renderHabitCard function for consistency
    const card = renderHabitCard(habitId, habit);
    
    // Apply animations with slight delay based on index for staggered effect
    const index = Object.keys(habits).indexOf(habitId);
    card.style.animationDelay = `${index * 0.05}s`;
    card.style.animationName = 'slideIn';
    card.style.animationDuration = '0.3s';
    card.style.animationFillMode = 'backwards';
    
    // CRITICAL FIX: Always ensure the habit color is applied with highest priority
    // This overrides any theme-based styles that might be applied later
    card.style.setProperty('background-color', habit.color || '#4CAF50', 'important');
    
    // Debug output to verify color is set correctly
    console.log(`Created habit card: ${habit.name}, Color: ${habit.color}`);
    
    return card;
}

// Function to show success/error notifications to the user
function showToast(message, bgColor = 'var(--success-color)', duration = 1500) {
    // Check if it's a completed message and reduce the duration
    if (message.includes('Great job') || message.includes('Completed')) {
        duration = 800; // Shorter duration for completion notifications
    }
    
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.style.backgroundColor = bgColor;
    toast.textContent = message;
    
    document.body.appendChild(toast);
    
    // Make toast visible
    setTimeout(() => {
        toast.classList.add('visible');
    }, 10);
    
    // Remove toast after duration
    setTimeout(() => {
        toast.classList.remove('visible');
        setTimeout(() => {
            document.body.removeChild(toast);
        }, 300); // Wait for fade-out transition before removing
    }, duration);
}

// Add initialization code to run on page load
document.addEventListener('DOMContentLoaded', function() {
    // Apply theme from localStorage
    applyTheme();
    
    // Load habits from localStorage
    loadHabits();
    
    // CRITICAL FIX: Add additional check to ensure habit card colors are applied
    // This runs after all DOM elements are loaded and styled
    setTimeout(() => {
        const habitCards = document.querySelectorAll('.habit-card');
        habitCards.forEach(card => {
            const habitId = card.id.replace('habit-card-', '');
            if (habits[habitId] && habits[habitId].color) {
                card.style.setProperty('background-color', habits[habitId].color, 'important');
                console.log(`Applied color ${habits[habitId].color} to ${habits[habitId].name} after DOM load`);
            }
        });
    }, 10);
    
    // Check if notifications are enabled
    const storedNotificationsEnabled = localStorage.getItem('notificationsEnabled');
    
    if (storedNotificationsEnabled === 'true') {
        // Notifications are already enabled, start the reminder checker
        startReminderCheck();
    } else if (storedNotificationsEnabled === null) {
        // First time user, show permission request
        setTimeout(() => {
            if (confirm("Would you like to enable notifications for habit reminders?")) {
                requestNotificationPermission().then(granted => {
                    if (granted) {
                        showToast("Notifications enabled successfully!", "#4CAF50");
                        startReminderCheck();
                    } else {
                        showToast("Notifications disabled. You can enable them later in Settings.", "#FF9800");
                    }
                }).catch(error => {
                    console.error("Error requesting notification permissions:", error);
                    showToast("Browser blocked notification request", "#F44336");
                });
            } else {
                localStorage.setItem('notificationsEnabled', 'false');
                showToast("Notifications disabled. You can enable them later in Settings.", "#FF9800");
            }
        }, 2000); // Ask after 2 seconds so user can see the app first
    }
});

// Update habit progress
function updateProgress(habitId, change) {
    const habit = habits[habitId];
    const newProgress = habit.progress + change;
    
    if (newProgress >= 0 && newProgress <= habit.target) {
        // Store current theme state before any changes
        const currentIsDarkMode = isDarkModeEnabled();
        document.body.dataset.themeMode = currentIsDarkMode ? 'dark' : 'light';
        
        const oldProgress = habit.progress;
        habit.progress = newProgress;
        habit.lastUpdatedDate = new Date().toISOString();
        
        // Record habit progress in history
        const today = getTodayFormatted();
        const habitHistory = loadHabitHistory();
        
        // Ensure the date entry exists
        if (!habitHistory[today]) {
            habitHistory[today] = {};
        }
        
        // Update both global and per-habit history
        const isCompleted = newProgress >= habit.target;
        habitHistory[today][habitId] = isCompleted ? "completed" : "not_completed";
        
        // Save to global history
        saveHabitHistory(habitHistory);
        
        // Update habit's own history
        if (!habit.history) {
            habit.history = {};
        }
        habit.history[today] = isCompleted ? "completed" : "not_completed";
        
        // Save habits
        saveHabitsToStorage(habits);
        
        // Update streak if needed
        updateStreak(habit, today, isCompleted);
        
        // Update UI
        updateHabitCardInDOM(habitId, habit);
        
        // Show completion message if target reached
        if (oldProgress < habit.target && newProgress === habit.target) {
            showToast('Great job! 🎉', '#4CAF50');
            
            // Record daily status after completion
            recordDailyHabitStatus();
            
            // Show notification if enabled
            if (localStorage.getItem('notificationsEnabled') === 'true') {
                showNotification(habit);
            }
        }
        
        // Update statistics
        updateStats();
        
        // Force calendar redraw if we're on the calendar screen
        const calendarGrid = document.querySelector('.calendar-grid');
        if (calendarGrid) {
            renderCalendarDays();
        }
    }
}

// Global notification permission setting
let isNotificationsEnabled = false;

// Check if notifications are available in this browser
function areNotificationsSupported() {
    return 'Notification' in window;
}

// Request permission for notifications
function requestNotificationPermission() {
    if (!areNotificationsSupported()) {
        console.log('Notifications not supported in this browser');
        showToast("Notifications not supported in this browser", "#FF9800");
        return Promise.resolve(false);
    }
    
    if (Notification.permission === 'granted') {
        isNotificationsEnabled = true;
        localStorage.setItem('notificationsEnabled', 'true');
        return Promise.resolve(true);
    }
    
    if (Notification.permission === 'denied') {
        isNotificationsEnabled = false;
        localStorage.setItem('notificationsEnabled', 'false');
        showToast("Notification permission was denied by the browser", "#F44336");
        return Promise.resolve(false);
    }
    
    try {
        // Need to request permission
        return Notification.requestPermission()
            .then(permission => {
                isNotificationsEnabled = permission === 'granted';
                localStorage.setItem('notificationsEnabled', String(isNotificationsEnabled));
                
                if (!isNotificationsEnabled) {
                    showToast("Notification permission was denied. Enable in browser settings.", "#F44336");
                }
                
                return isNotificationsEnabled;
            })
            .catch(error => {
                console.error('Error requesting notification permission:', error);
                showToast("Browser blocked notification permission request", "#F44336");
                return false;
            });
    } catch (error) {
        console.error('Exception requesting notification permission:', error);
        showToast("Browser blocked notification permission request", "#F44336");
        return Promise.resolve(false);
    }
}

// Function to show a notification
function showNotification(habit) {
    if (!isNotificationsEnabled) return;
    
    try {
        const icon = habit.icon || '⏰';
        const title = `${icon} ${habit.name} Reminder`;
        const options = {
            body: "Don't forget!",
            icon: '/favicon.ico' // Will use default icon if not found
        };
        
        const notification = new Notification(title, options);
        
        // Close the notification after 10 seconds
        setTimeout(() => {
            notification.close();
        }, 10000);
        
        // Add click event to focus the window when notification is clicked
        notification.onclick = function() {
            window.focus();
            notification.close();
        };
    } catch (error) {
        console.error('Error showing notification:', error);
    }
}

// Check for habits that need reminders
function checkReminders() {
    if (!isNotificationsEnabled) return;
    
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    
    // Format the current time in 24-hour format (HH:MM)
    const currentTime = `${String(currentHour).padStart(2, '0')}:${String(currentMinute).padStart(2, '0')}`;
    
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        
        // Skip if reminders aren't enabled for this habit or no time is set
        if (!habit.reminderEnabled || !habit.reminderTime) return;
        
        // Check if the current time matches the reminder time (checking only once per minute)
        if (currentTime === habit.reminderTime) {
            showNotification(habit);
        }
    });
}

// Set up a timer to check for reminders every minute
let reminderTimer = null;

function startReminderCheck() {
    // Clear any existing timer
    if (reminderTimer) {
        clearInterval(reminderTimer);
    }
    
    // Only start checking if notifications are enabled
    if (isNotificationsEnabled) {
        // Check once immediately
        checkReminders();
        
        // Set interval to check every minute (60000 ms)
        reminderTimer = setInterval(checkReminders, 60000);
    }
}

// Check if habits need to be reset based on their frequency
function checkHabitResets() {
    const currentDate = new Date();
    let hasChanges = false;
    let shouldRecordHistory = false;
    
    // Process each habit
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        
        // Make sure habit has lastUpdatedDate (backward compatibility)
        if (!habit.lastUpdatedDate) {
            habit.lastUpdatedDate = new Date().toISOString();
            habit.resetFrequency = habit.resetFrequency || "weekly";
            hasChanges = true;
            return; // Skip this iteration
        }
        
        const lastUpdated = new Date(habit.lastUpdatedDate);
        
        switch (habit.resetFrequency || "weekly") {
            case "daily":
                // Reset if it's a different calendar day
                if (currentDate.getDate() !== lastUpdated.getDate() ||
                    currentDate.getMonth() !== lastUpdated.getMonth() ||
                    currentDate.getFullYear() !== lastUpdated.getFullYear()) {
                    
                    // Record completion status for the last updated date
                    if (!habit.history) {
                        habit.history = {};
                    }
                    
                    const lastUpdateFormatted = formatDate(lastUpdated);
                    const wasCompleted = habit.progress >= habit.target;
                    
                    if (!habit.history[lastUpdateFormatted]) {
                        habit.history[lastUpdateFormatted] = {
                            completed: wasCompleted,
                            progress: habit.progress,
                            target: habit.target
                        };
                    }
                    
                    // Update streak information if habit was completed
                    if (wasCompleted) {
                        // Initialize streak properties if they don't exist
                        if (habit.streak === undefined) {
                            habit.streak = 0;
                        }
                        if (habit.lastStreakDate === undefined) {
                            habit.lastStreakDate = null;
                        }
                        
                        // Only update if we haven't already counted this day
                        if (!habit.lastStreakDate || habit.lastStreakDate !== lastUpdateFormatted) {
                            updateStreak(habit, lastUpdateFormatted, true);
                        }
                    }
                    
                    habit.progress = 0;
                    habit.lastUpdatedDate = currentDate.toISOString();
                    hasChanges = true;
                }
                break;
                
            case "weekly":
                // Get ISO week numbers (1-52)
                const getWeekNumber = (d) => {
                    // ISO week date weeks start on Monday, so correct the day number
                    const dayNum = d.getUTCDay() || 7;
                    
                    // Set the target date to the Thursday of this week
                    d = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate() + (4 - dayNum)));
                    
                    // Get first day of year
                    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
                    
                    // Calculate full weeks to nearest Thursday
                    const weekNum = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
                    
                    return weekNum;
                };
                
                const currentWeek = getWeekNumber(currentDate);
                const lastWeek = getWeekNumber(lastUpdated);
                const currentYear = currentDate.getFullYear();
                const lastYear = lastUpdated.getFullYear();
                
                // Reset if the week number changed
                if (currentWeek !== lastWeek || currentYear !== lastYear) {
                    // Record completion status for the last updated date
                    if (!habit.history) {
                        habit.history = {};
                    }
                    
                    const lastUpdateFormatted = formatDate(lastUpdated);
                    const wasCompleted = habit.progress >= habit.target;
                    
                    if (!habit.history[lastUpdateFormatted]) {
                        habit.history[lastUpdateFormatted] = {
                            completed: wasCompleted,
                            progress: habit.progress,
                            target: habit.target
                        };
                    }
                    
                    // Update streak information if habit was completed
                    if (wasCompleted) {
                        // Initialize streak properties if they don't exist
                        if (habit.streak === undefined) {
                            habit.streak = 0;
                        }
                        if (habit.lastStreakDate === undefined) {
                            habit.lastStreakDate = null;
                        }
                        
                        // Only update if we haven't already counted this day
                        if (!habit.lastStreakDate || habit.lastStreakDate !== lastUpdateFormatted) {
                            updateStreak(habit, lastUpdateFormatted, true);
                        }
                    }
                    
                    habit.progress = 0;
                    habit.lastUpdatedDate = currentDate.toISOString();
                    hasChanges = true;
                }
                break;
                
            case "monthly":
                // Reset if it's a different month
                if (currentDate.getMonth() !== lastUpdated.getMonth() ||
                    currentDate.getFullYear() !== lastUpdated.getFullYear()) {
                    // Record completion status for the last updated date
                    if (!habit.history) {
                        habit.history = {};
                    }
                    
                    const lastUpdateFormatted = formatDate(lastUpdated);
                    const wasCompleted = habit.progress >= habit.target;
                    
                    if (!habit.history[lastUpdateFormatted]) {
                        habit.history[lastUpdateFormatted] = {
                            completed: wasCompleted,
                            progress: habit.progress,
                            target: habit.target
                        };
                    }
                    
                    // Update streak information if habit was completed
                    if (wasCompleted) {
                        // Initialize streak properties if they don't exist
                        if (habit.streak === undefined) {
                            habit.streak = 0;
                        }
                        if (habit.lastStreakDate === undefined) {
                            habit.lastStreakDate = null;
                        }
                        
                        // Only update if we haven't already counted this day
                        if (!habit.lastStreakDate || habit.lastStreakDate !== lastUpdateFormatted) {
                            updateStreak(habit, lastUpdateFormatted, true);
                        }
                    }
                    
                    habit.progress = 0;
                    habit.lastUpdatedDate = currentDate.toISOString();
                    hasChanges = true;
                }
                break;
        }
    });
    
    // Save if changes were made
    if (hasChanges) {
        saveHabitsToStorage(habits);
        console.log('Habits were reset based on their reset frequency');
        
        // Record daily habit status in history when resets occur
        recordDailyHabitStatus();
        
        // Apply theme consistently after habits are reset
        applyTheme();
    }
}

// Update habit streak count
function updateStreak(habit, today, isCompleted) {
    // Initialize properties if needed
    if (habit.streak === undefined) habit.streak = 0;
    if (habit.lastStreakDate === undefined) habit.lastStreakDate = null;
    
    if (isCompleted) {
        // If it was completed, increase streak
        habit.streak += 1;
        habit.lastStreakDate = today;
    } else {
        // If not completed, reset streak
        habit.streak = 0;
        habit.lastStreakDate = null;
    }
}

// Show Add Habit Screen (fullscreen)
function showAddHabitScreen(habit = null) {
    // Get the app root element
    const appRoot = document.getElementById('app-root');
    
    // Clear app-root completely 
    appRoot.innerHTML = '';
    
    // Get current theme
    const isDarkMode = isDarkModeEnabled();
    
    // Create default habit values for new habits
    const defaultHabit = {
        name: '',
        icon: 'none',
        color: '#2196F3', // Default blue color
        category: '',
        target: 7 // Default weekly goal
    };
    
    // Use provided habit or default values
    habit = habit || defaultHabit;
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.className = 'app-screen';
    appScreen.style.height = '100vh';
    appScreen.style.display = 'flex';
    appScreen.style.flexDirection = 'column';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.className = 'app-bar';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.className = 'back-button';
    backButton.onclick = () => {
        // Use the showMainScreen function to return to the main screen
        showMainScreen();
    };
    
    // Title
    const title = document.createElement('h1');
    title.textContent = 'Add New Habit';
    title.className = 'screen-title';
    
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Create form container (scrollable)
    const formContainer = document.createElement('div');
    formContainer.style.flex = '1';
    formContainer.style.overflowY = 'auto';
    formContainer.style.padding = '20px';
    
    // Create form content
    const form = document.createElement('div');
    form.className = 'form-container';
    
    const heading = document.createElement('h2');
    heading.textContent = 'Add New Habit';
    heading.style.textAlign = 'center';
    heading.style.marginBottom = '20px';
    
    // Emoji icon selector
    const iconLabel = document.createElement('div');
    iconLabel.textContent = 'Choose an Icon (Optional)';
    iconLabel.style.fontSize = '16px';
    iconLabel.style.fontWeight = 'bold';
    iconLabel.style.marginBottom = '10px';
    
    // Create icon options
    const iconContainer = document.createElement('div');
    iconContainer.className = 'icon-container';
    iconContainer.style.display = 'grid';
    iconContainer.style.gridTemplateColumns = 'repeat(4, 1fr)';
    iconContainer.style.gap = '10px';
    iconContainer.style.marginBottom = '20px';
    iconContainer.style.justifyContent = 'center';
    
    // Habit-appropriate icons with their SVG paths
    // TODO: BUG-010 - Replace these generic icons with a curated set of habit-specific icons
    // Create a more comprehensive collection of monochrome icons for common habit types:
    // - Fitness/exercise (running, gym, yoga, etc.)
    // - Health (medication, sleep, water, vitamins)
    // - Learning (reading, studying, language)
    // - Mindfulness (meditation, prayer, journaling)
    // - Productivity (work, coding, writing)
    // Consider using an open-source icon library or creating custom SVG icons
    const icons = [
        { id: 'none', label: 'None', path: '' }, // Empty option
        
        // Health & Fitness Category
        { id: 'water', label: 'Water/Hydration', path: 'M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z' },
        { id: 'run', label: 'Running', path: 'M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9L7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3C14.8 12 16.8 13 19 13v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.56-.89-1.68-1.25-2.65-.84L6 8.3V13h2V9.6l1.8-.7' },
        { id: 'bike', label: 'Cycling', path: 'M5 20.5A3.5 3.5 0 0 1 1.5 17 3.5 3.5 0 0 1 5 13.5 3.5 3.5 0 0 1 8.5 17 3.5 3.5 0 0 1 5 20.5M19 20.5A3.5 3.5 0 0 1 15.5 17 3.5 3.5 0 0 1 19 13.5 3.5 3.5 0 0 1 22.5 17 3.5 3.5 0 0 1 19 20.5M12 17a2 2 0 0 1-2-2c0-1.08.87-1.96 1.95-1.97L13.5 12l-2.4-2.4c-.54.54-1.29.88-2.1.88-1.66 0-3-1.34-3-3s1.34-3 3-3c.95 0 1.8.45 2.33 1.14L13 7.25 14.75 9l-1.75 1.75L15 12.75 9 18V17z' },
        { id: 'gym', label: 'Strength', path: 'M20.57 14.86L22 13.43 20.57 12 17 15.57 8.43 7 12 3.43 10.57 2 9.14 3.43 7.71 2 5.57 4.14 4.14 2.71 2.71 4.14l1.43 1.43L2 7.71l1.43 1.43L2 10.57 3.43 12 7 8.43 15.57 17 12 20.57 13.43 22l1.43-1.43L16.29 22l2.14-2.14 1.43 1.43 1.43-1.43-1.43-1.43L22 16.29l-1.43-1.43z' },
        { id: 'meditation', label: 'Meditation', path: 'M12 4c1.11 0 2 .89 2 2s-.89 2-2 2-2-.89-2-2 .9-2 2-2m9 12v-2c0-2.66-5.33-4-8-4h-.25C9.75 10 4 11.34 4 14v2h17' },
        { id: 'yoga', label: 'Yoga', path: 'M13 2v9l3-2.94L19 11V2h-6m4 7V4h-2v5l-1-.99L13 9V4h-2v7.42l-3.07 3.88L10.6 21h2l-.6-6 3-3 1 8h2l-.5-9L21 9V7l-4 2z' },
        { id: 'sleep', label: 'Sleep', path: 'M2 12C2 17.5 6.5 22 12 22S22 17.5 22 12 17.5 2 12 2 2 6.5 2 12z' },
        
        // Mind & Knowledge
        { id: 'book', label: 'Reading', path: 'M21 5c-1.11-.35-2.33-.5-3.5-.5-1.95 0-4.05.4-5.5 1.5-1.45-1.1-3.55-1.5-5.5-1.5S2.45 4.9 1 6v14.65c0 .25.25.5.5.5.1 0 .15-.05.25-.05C3.1 20.45 5.05 20 6.5 20c1.95 0 4.05.4 5.5 1.5 1.35-.85 3.8-1.5 5.5-1.5 1.65 0 3.35.3 4.75 1.05.1.05.15.05.25.05.25 0 .5-.25.5-.5V6c-.6-.45-1.25-.75-2-1m0 13.5c-1.1-.35-2.3-.5-3.5-.5-1.7 0-4.15.65-5.5 1.5V8c1.35-.85 3.8-1.5 5.5-1.5 1.2 0 2.4.15 3.5.5v11.5z' },
        { id: 'study', label: 'Study', path: 'M12 3L1 9l4 2.18v6L12 21l7-3.82v-6l2-1.09V17h2V9L12 3m0 2.18L17.82 9 12 12.72 6.18 9 12 5.18M17 16l-5 2.72L7 16v-3.73L12 15l5-2.73V16z' },
        { id: 'language', label: 'Language', path: 'M12.87 15.07l-2.54-2.51.03-.03c1.74-1.94 2.98-4.17 3.71-6.53H17V4h-7V2H8v2H1v1.99h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8h-2c.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11.76-2.04zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z' },
        { id: 'journal', label: 'Journal', path: 'M19 5v14H5V5h14m0-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z M12 14l-4-4h8z' },
        { id: 'mindfulness', label: 'Mindfulness', path: 'M12 3c1.66 0 3 1.34 3 3-1.54.8-3 1.5-5 1.5-1 0-2-.67-2-1.5S10.34 3 12 3m3 7.5c2.32 0 4.5.4 6.5 1.38.34 1.12.5 2.34.5 3.62 0 2.2-.5 3.5-4 3.5v-2c2 0 2-.8 2-1.5 0-1.93-1.5-3.5-5-3.5-3.5 0-5 1.57-5 3.5 0 .7 0 1.5 2 1.5v2c-3.5 0-4-1.3-4-3.5 0-1.28.16-2.5.5-3.62C10.5 10.9 12.68 10.5 15 10.5m-.7 5.63c.7.07 1.07.3 1.23.57H17c0 .55-.47 1-1 1h-1c-.55 0-1-.45-1-1h2.3c-.17-.27-.53-.5-1.23-.57-.67-.06-1.35-.12-1.35-.62S15.3 14 16 14s1.43.38 1.5.88h.5c-.03-.83-.9-1.38-2-1.38s-1.97.55-2 1.38c0 .5.68.56 1.35.62z' },
        
        // Productivity & Work
        { id: 'code', label: 'Coding', path: 'M8,3A2,2 0 0,0 6,5V9A2,2 0 0,1 4,11H3V13H4A2,2 0 0,1 6,15V19A2,2 0 0,0 8,21H10V19H8V14A2,2 0 0,0 6,12A2,2 0 0,0 8,10V5H10V3M16,3A2,2 0 0,1 18,5V9A2,2 0 0,0 20,11H21V13H20A2,2 0 0,0 18,15V19A2,2 0 0,1 16,21H14V19H16V14A2,2 0 0,1 18,12A2,2 0 0,1 16,10V5H14V3H16Z' },
        { id: 'work', label: 'Work', path: 'M10 16v-1H3.01L3 19c0 1.11.89 2 2 2h14c1.11 0 2-.89 2-2v-4h-7v1h-4zm10-9h-4.01V5l-2-2h-4l-2 2v2H4c-1.1 0-2 .9-2 2v3c0 1.11.89 2 2 2h6v-2h4v2h6c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-6 0h-4V5h4v2z' },
        { id: 'write', label: 'Writing', path: 'M14.06 9.02l.92.92L5.92 19H5v-.92l9.06-9.06M17.66 3c-.25 0-.51.1-.7.29l-1.83 1.83 3.75 3.75 1.83-1.83c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.2-.2-.45-.29-.71-.29zm-3.6 3.19L3 17.25V21h3.75L17.81 9.94l-3.75-3.75z' },
        { id: 'music', label: 'Music', path: 'M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z' },
        { id: 'art', label: 'Art', path: 'M17.5 12c1.93 0 3.5-1.57 3.5-3.5S19.43 5 17.5 5 14 6.57 14 8.5s1.57 3.5 3.5 3.5zm-9 0c1.93 0 3.5-1.57 3.5-3.5S10.43 5 8.5 5 5 6.57 5 8.5 6.57 12 8.5 12zM3 21h18v-2c0-3.33-6-4-9-4s-9 .67-9 4v2z' },
        
        // Spiritual & Social
        { id: 'pray', label: 'Prayer', path: 'M10 3L8 5v2h2V5h2V3h-2M3 7v2h2c0 1.03.06 2.1.16 3H3v2h2.16c.24.84.7 1.62 1.38 2.26L5 18h2.13l1.73-1.73L10 17.5V21h2v-3.5l1.14-1.27L15 18h2l-1.55-1.74c.58-.54.96-1.22 1.24-1.96L19 14.5V21h2v-7.5l2-2.5V7h-7V5h-2v2H3z' },
        { id: 'family', label: 'Family', path: 'M12,5.5A3.5,3.5 0 0,1 15.5,9A3.5,3.5 0 0,1 12,12.5A3.5,3.5 0 0,1 8.5,9A3.5,3.5 0 0,1 12,5.5M5,8C5.56,8 6.08,8.15 6.53,8.42C6.38,9.85 6.8,11.27 7.66,12.38C7.16,13.34 6.16,14 5,14A3,3 0 0,1 2,11A3,3 0 0,1 5,8M19,8A3,3 0 0,1 22,11A3,3 0 0,1 19,14C17.84,14 16.84,13.34 16.34,12.38C17.2,11.27 17.62,9.85 17.47,8.42C17.92,8.15 18.44,8 19,8M5.5,18.25C5.5,16.18 8.41,14.5 12,14.5C15.59,14.5 18.5,16.18 18.5,18.25V20H5.5V18.25M0,20V18.5C0,17.11 1.89,15.94 4.45,15.6C3.86,16.28 3.5,17.22 3.5,18.25V20H0M24,20H20.5V18.25C20.5,17.22 20.14,16.28 19.55,15.6C22.11,15.94 24,17.11 24,18.5V20Z' },
        { id: 'connect', label: 'Connect', path: 'M16,13C15.71,13 15.38,13 15.03,13.05C16.19,13.89 17,15 17,16.5V19H23V16.5C23,14.17 18.33,13 16,13M8,13C5.67,13 1,14.17 1,16.5V19H15V16.5C15,14.17 10.33,13 8,13M8,11A3,3 0 0,0 11,8A3,3 0 0,0 8,5A3,3 0 0,0 5,8A3,3 0 0,0 8,11M16,11A3,3 0 0,0 19,8A3,3 0 0,0 16,5A3,3 0 0,0 13,8A3,3 0 0,0 16,11Z' },
        
        // Habits & Health
        { id: 'pill', label: 'Medication', path: 'M4.22,11.29L11.29,4.22C13.64,1.88 17.43,1.88 19.78,4.22C22.12,6.56 22.12,10.36 19.78,12.71L12.71,19.78C10.36,22.12 6.56,22.12 4.22,19.78C1.88,17.43 1.88,13.64 4.22,11.29M5.64,12.71C4.59,13.75 4.24,15.24 4.6,16.57L10.59,10.59L14.83,14.83L18.36,11.29C19.93,9.73 19.93,7.2 18.36,5.64C16.8,4.07 14.27,4.07 12.71,5.64L5.64,12.71Z' },
        { id: 'meal', label: 'Healthy Eating', path: 'M15.5,21L14,8H16.23L15.1,3.46L16.84,3L18.09,8H22L20.5,21H15.5M5,11H10A3,3 0 0,1 13,14H2A3,3 0 0,1 5,11M13,18A3,3 0 0,1 10,21H5A3,3 0 0,1 2,18H13M3,15H8L9.5,16.5L11,15H12A1,1 0 0,1 13,16A1,1 0 0,1 12,17H3A1,1 0 0,1 2,16A1,1 0 0,1 3,15Z' },
        { id: 'no-smoking', label: 'Quit Smoking', path: 'M2,6V18H22V6H2M16,14V16H14V10H16V8H20V6H18V10H17.58L17,11.41V12.57L14,16H12V14L14.88,9.78L14.11,9.11L13.65,10H10.88L12.73,6H14.69L15.81,6.13L16.27,5.67L17,6.11L16.15,8.12L17.08,8.96L18.92,6H20V8H18.92L18.33,9L19.25,9.87L20,8.87L19.92,16H18V14H16Z' },
        { id: 'no-alcohol', label: 'Quit Drinking', path: 'M20 10C20 7.33 18 5 15 5L14.5 5L14.5 3H15V1H9V3H9.5L9.5 5L9 5C6 5 4 7.33 4 10L4 11H14C15.11 11 16 11.9 16 13L16 19H8L8 21H17C18.11 21 19 20.11 19 19L19 14.89C20.24 14.07 21 12.62 21 11V10H20M9.5 7L9.5 5H14.5L14.5 7L13.5 8H10.5L9.5 7Z' },
        { id: 'track', label: 'Habit Tracking', path: 'M0.41,13.41L6,19L7.41,17.58L1.83,12M22.24,5.58L11.66,16.17L7.5,12L6.07,13.41L11.66,19L23.66,7M18,7L16.59,5.58L10.24,11.93L11.66,13.34L18,7Z' }
    ];
    
    let selectedIconId = '';
    
    icons.forEach(icon => {
        const iconBtn = document.createElement('div');
        iconBtn.className = 'icon-btn';
        iconBtn.title = icon.label;
        iconBtn.style.width = '42px';
        iconBtn.style.height = '42px';
        iconBtn.style.display = 'flex';
        iconBtn.style.alignItems = 'center';
        iconBtn.style.justifyContent = 'center';
        iconBtn.style.cursor = 'pointer';
        iconBtn.style.border = '1px solid #ccc';
        iconBtn.style.borderRadius = '8px';
        iconBtn.style.transition = 'all 0.3s ease';
        iconBtn.style.backgroundColor = isDarkMode ? '#333' : '#fff';
        
        // Add SVG icon or "None" text
        if (icon.id !== 'none' && icon.path) {
            const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            svg.setAttribute('width', '24');
            svg.setAttribute('height', '24');
            svg.setAttribute('viewBox', '0 0 24 24');
            svg.setAttribute('fill', 'none');
            svg.setAttribute('stroke', isDarkMode ? '#fff' : '#000');
            svg.setAttribute('stroke-width', '2');
            svg.setAttribute('stroke-linecap', 'round');
            svg.setAttribute('stroke-linejoin', 'round');
            
            const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            path.setAttribute('d', icon.path);
            
            svg.appendChild(path);
            iconBtn.appendChild(svg);
        } else {
            // None option
            const noneText = document.createElement('div');
            noneText.textContent = 'None';
            noneText.style.fontSize = '12px';
            iconBtn.appendChild(noneText);
        }
        
        // Handle selection click
        iconBtn.onclick = () => {
            selectedIconId = icon.id;
            
            // Update all buttons to reflect new selection
            iconContainer.querySelectorAll('.icon-btn').forEach(btn => {
                btn.style.backgroundColor = isDarkMode ? '#333' : '#fff';
                btn.style.transform = 'scale(1.0)';
                btn.style.boxShadow = 'none';
            });
            
            // Highlight selected icon
            iconBtn.style.backgroundColor = '#e0e0e0';
            iconBtn.style.transform = 'scale(1.1)';
            iconBtn.style.boxShadow = '0 2px 5px rgba(0,0,0,0.2)';
        };
        
        iconContainer.appendChild(iconBtn);
    });
    
    // Form inputs
    const nameInput = document.createElement('input');
    nameInput.type = 'text';
    nameInput.placeholder = 'Habit Name';
    nameInput.value = habit.name || '';
    nameInput.style.width = '100%';
    nameInput.style.padding = '16px';
    nameInput.style.fontSize = '16px';
    nameInput.style.marginBottom = '16px'; 
    nameInput.style.borderRadius = '8px';
    nameInput.style.border = '1px solid #ccc';
    nameInput.style.boxSizing = 'border-box';
    
    // Add category dropdown
    const categoryLabel = document.createElement('div');
    categoryLabel.textContent = 'Category (Optional)';
    categoryLabel.style.fontSize = '16px';
    categoryLabel.style.fontWeight = 'bold';
    categoryLabel.style.marginBottom = '10px';
    
    const categorySelect = document.createElement('select');
    categorySelect.id = 'habit-category-select'; // Consistent ID for easy reference
    categorySelect.style.width = '100%';
    categorySelect.style.padding = '16px';
    categorySelect.style.fontSize = '16px';
    categorySelect.style.marginBottom = '16px';
    categorySelect.style.borderRadius = '8px';
    categorySelect.style.border = '1px solid #ccc';
    categorySelect.style.boxSizing = 'border-box';
    categorySelect.style.backgroundColor = isDarkMode ? '#333' : '#fff';
    categorySelect.style.color = isDarkMode ? '#fff' : '#000';
    
    // Add category options
    const categories = [
        { value: '', label: 'Select a category (optional)' },
        { value: 'Mind', label: 'Mind' },
        { value: 'Body', label: 'Body' },
        { value: 'Spirit', label: 'Spirit' }
    ];
    
    categories.forEach(category => {
        const option = document.createElement('option');
        option.value = category.value;
        option.textContent = category.label;
        categorySelect.appendChild(option);
    });
    
    // Set the current category if it exists
    if (habit.category) {
        categorySelect.value = habit.category;
    }
    
    const targetInput = document.createElement('input');
    targetInput.type = 'number';
    targetInput.placeholder = 'Goal Number (weekly)';
    targetInput.min = '1';
    targetInput.max = '100';
    targetInput.value = habit.target || '7'; // Default to 7 if not set
    targetInput.style.width = '100%';
    targetInput.style.padding = '16px';
    targetInput.style.fontSize = '16px';
    targetInput.style.marginBottom = '16px';
    targetInput.style.borderRadius = '8px';
    targetInput.style.border = '1px solid #ccc';
    targetInput.style.boxSizing = 'border-box';
    
    // Color picker
    const colorLabel = document.createElement('div');
    colorLabel.textContent = 'Choose a Color';
    colorLabel.style.fontSize = '16px';
    colorLabel.style.fontWeight = 'bold';
    colorLabel.style.marginBottom = '10px';
    
    // Create color swatches container
    const colorSwatchesContainer = document.createElement('div');
    colorSwatchesContainer.style.display = 'flex';
    colorSwatchesContainer.style.flexWrap = 'wrap';
    colorSwatchesContainer.style.gap = '12px';
    colorSwatchesContainer.style.marginBottom = '16px';
    colorSwatchesContainer.style.justifyContent = 'center';
    
    // Define preset colors appropriate for habits
    const presetColors = [
        { value: '#2196F3', name: 'Blue' },
        { value: '#4CAF50', name: 'Green' },
        { value: '#9C27B0', name: 'Purple' },
        { value: '#F44336', name: 'Red' },
        { value: '#FF9800', name: 'Orange' },
        { value: '#009688', name: 'Teal' },
        { value: '#795548', name: 'Brown' },
        { value: '#607D8B', name: 'Gray Blue' }
    ];
    
    // Keep track of selected color - initialize with current habit color or default
    let selectedColor = habit.color || '#2196F3'; // Default to blue if not set
    
    // Create a color swatch for each preset color
    presetColors.forEach(color => {
        const swatch = document.createElement('div');
        swatch.className = 'color-swatch';
        swatch.title = color.name;
        swatch.style.width = '44px';
        swatch.style.height = '44px';
        swatch.style.backgroundColor = color.value;
        swatch.style.borderRadius = '50%';
        swatch.style.cursor = 'pointer';
        swatch.style.border = color.value === selectedColor ? '3px solid white' : '3px solid transparent';
        swatch.style.boxShadow = color.value === selectedColor ? '0 0 0 2px #673ab7' : '0 0 0 1px rgba(0,0,0,0.1)';
        swatch.style.transition = 'transform 0.2s ease, box-shadow 0.2s ease';
        
        // If this color is already the habit color, mark it as selected
        if (color.value === selectedColor) {
            swatch.style.border = '3px solid white';
            swatch.style.boxShadow = '0 0 0 2px #673ab7';
            swatch.style.transform = 'scale(1.1)';
        }
        
        // Select this color when clicked
        swatch.addEventListener('click', () => {
            selectedColor = color.value;
            
            // Update all swatches to reflect the new selection
            colorSwatchesContainer.querySelectorAll('.color-swatch').forEach(s => {
                s.style.border = '3px solid transparent';
                s.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
                s.style.transform = 'scale(1)';
            });
            
            // Highlight the selected swatch
            swatch.style.border = '3px solid white';
            swatch.style.boxShadow = '0 0 0 2px #673ab7';
            swatch.style.transform = 'scale(1.1)';
        });
        
        // Add hover effect
        swatch.addEventListener('mouseover', () => {
            if (color.value !== selectedColor) {
                swatch.style.transform = 'scale(1.1)';
                swatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.2)';
            }
        });
        
        swatch.addEventListener('mouseout', () => {
            if (color.value !== selectedColor) {
                swatch.style.transform = 'scale(1)';
                swatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
            }
        });
        
        colorSwatchesContainer.appendChild(swatch);
    });
    
    // Add a "custom color" option with rainbow indicator
    const customColorSwatch = document.createElement('div');
    customColorSwatch.className = 'color-swatch';
    customColorSwatch.title = 'Custom Color';
    customColorSwatch.style.width = '44px';
    customColorSwatch.style.height = '44px';
    customColorSwatch.style.borderRadius = '50%';
    customColorSwatch.style.cursor = 'pointer';
    customColorSwatch.style.border = '3px solid transparent';
    customColorSwatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
    customColorSwatch.style.position = 'relative';
    customColorSwatch.style.overflow = 'hidden';
    customColorSwatch.style.transition = 'transform 0.2s ease, box-shadow 0.2s ease';
    
    // Create rainbow gradient background for custom color picker
    customColorSwatch.style.background = 'linear-gradient(45deg, red, orange, yellow, green, blue, indigo, violet)';
    
    // Hidden native color picker
    const nativeColorPicker = document.createElement('input');
    nativeColorPicker.type = 'color';
    nativeColorPicker.style.opacity = '0';
    nativeColorPicker.style.position = 'absolute';
    nativeColorPicker.style.top = '0';
    nativeColorPicker.style.left = '0';
    nativeColorPicker.style.width = '100%';
    nativeColorPicker.style.height = '100%';
    nativeColorPicker.style.cursor = 'pointer';
    
    // Update when native color picker changes
    nativeColorPicker.addEventListener('input', (e) => {
        selectedColor = e.target.value;
        
        // Update all swatches to reflect the new selection
        colorSwatchesContainer.querySelectorAll('.color-swatch').forEach(s => {
            s.style.border = '3px solid transparent';
            s.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
            s.style.transform = 'scale(1)';
        });
        
        // Highlight the custom swatch
        customColorSwatch.style.border = '3px solid white';
        customColorSwatch.style.boxShadow = '0 0 0 2px #673ab7';
        customColorSwatch.style.transform = 'scale(1.1)';
    });
    
    // Add hover effect for custom swatch
    customColorSwatch.addEventListener('mouseover', () => {
        customColorSwatch.style.transform = 'scale(1.1)';
        customColorSwatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.2)';
    });
    
    customColorSwatch.addEventListener('mouseout', () => {
        if (customColorSwatch !== document.activeElement) {
            customColorSwatch.style.transform = 'scale(1)';
            customColorSwatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
        }
    });
    
    customColorSwatch.appendChild(nativeColorPicker);
    colorSwatchesContainer.appendChild(customColorSwatch);
    
    // Save button container
    const saveButtonContainer = document.createElement('div');
    saveButtonContainer.style.padding = '20px';
    saveButtonContainer.style.display = 'flex';
    saveButtonContainer.style.justifyContent = 'center';
    saveButtonContainer.style.marginTop = '20px';
    
    const createButton = document.createElement('button');
    createButton.textContent = 'Create Habit';
    createButton.style.backgroundColor = '#673ab7';
    createButton.style.color = 'white';
    createButton.style.padding = '16px 32px';
    createButton.style.borderRadius = '8px';
    createButton.style.border = 'none';
    createButton.style.fontSize = '18px';
    createButton.style.fontWeight = 'bold';
    createButton.style.cursor = 'pointer';
    createButton.style.width = '100%';
    createButton.style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)';
    
    // Add the button to the container
    saveButtonContainer.appendChild(createButton);
    
    // Create habit logic
    createButton.onclick = () => {
        // Validate form
        if (nameInput.value && targetInput.value && parseInt(targetInput.value) > 0) {
            // Generate unique ID for the habit - use existing ID if editing, otherwise create new one
            const habitId = habit && habit.id ? habit.id : generateHabitId();
            
            // Get selected category value
            const selectedCategory = categorySelect.value || 'Other';
            
            // Create or update the habit object
            habits[habitId] = {
                id: habitId, // Store ID within the habit object for reference
                name: nameInput.value,
                progress: 0,  // Always initialize progress to 0 for new habits
                target: parseInt(targetInput.value),
                color: selectedColor,
                icon: selectedIconId !== 'none' ? selectedIconId : '',
                lastUpdatedDate: new Date().toISOString(),
                resetFrequency: "weekly",
                history: {},
                streak: 0,
                lastStreakDate: null,
                reminderTime: null,
                reminderEnabled: false,
                category: selectedCategory
            };
            
            // Save to localStorage
            saveHabitsToStorage(habits);
            
            // Use the showMainScreen function instead of directly manipulating DOM
            showMainScreen();
        } else {
            alert('Please fill out all fields');
        }
    };
    
    // Assemble the form
    form.appendChild(heading);
    form.appendChild(iconLabel);
    form.appendChild(iconContainer);
    form.appendChild(nameInput);
    form.appendChild(categoryLabel);
    form.appendChild(categorySelect);
    form.appendChild(targetInput);
    form.appendChild(colorLabel);
    form.appendChild(colorSwatchesContainer);
    
    // Assemble the UI
    formContainer.appendChild(form);
    formContainer.appendChild(saveButtonContainer);
    
    appScreen.appendChild(appBar);
    appScreen.appendChild(formContainer);
    
    // Add to app-root instead of document.body
    appRoot.appendChild(appScreen);
    
    // Reset scroll position
    window.scrollTo(0, 0);
    
    // Focus the first input for better UX
    nameInput.focus();
}

// Show Edit Habit Screen
function showEditHabitScreen(habitId, habit) {
    // Get the app root element
    const appRoot = document.getElementById('app-root');
    
    // Clear app-root completely
    appRoot.innerHTML = '';
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.className = 'app-screen';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.className = 'app-bar';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.className = 'app-bar-button';
    
    // Back button styling
    backButton.style.fontSize = '24px';
    backButton.style.marginRight = '10px';
    backButton.style.cursor = 'pointer';
    
    // Go back to main screen when clicked
    backButton.onclick = () => {
        showMainScreen();
    };
    
    // Title
    const title = document.createElement('div');
    title.textContent = 'Edit Habit';
    title.className = 'app-bar-title';
    title.style.color = 'white';
    title.style.fontSize = '20px';
    title.style.flex = '1';
    
    // AppBar styling
    appBar.style.backgroundColor = '#673ab7';
    appBar.style.color = 'white';
    appBar.style.padding = '16px';
    appBar.style.display = 'flex';
    appBar.style.alignItems = 'center';
    appBar.style.position = 'sticky';
    appBar.style.top = '0';
    appBar.style.zIndex = '1000';
    appBar.style.width = '100%';
    appBar.style.boxSizing = 'border-box';
    
    // Add elements to AppBar
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Form container
    const formContainer = document.createElement('div');
    formContainer.style.padding = '20px';
    formContainer.style.backgroundColor = 'var(--section-bg-color)';
    formContainer.style.borderRadius = '12px';
    formContainer.style.margin = '20px';
    formContainer.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.1)';
    
    // Create form
    const form = document.createElement('form');
    form.style.display = 'flex';
    form.style.flexDirection = 'column';
    form.style.gap = '16px';
    
    // Prevent form submission
    form.onsubmit = (e) => {
        e.preventDefault();
    };
    
    // Create heading
    const heading = document.createElement('h2');
    heading.textContent = 'Edit ' + habit.name;
    heading.style.margin = '0 0 10px 0';
    heading.style.color = 'var(--text-color)';
    
    // Icon selection
    const iconLabel = document.createElement('div');
    iconLabel.textContent = 'Choose an Icon';
    iconLabel.style.fontSize = '16px';
    iconLabel.style.fontWeight = 'bold';
    iconLabel.style.marginBottom = '10px';
    
    // Icon container
    const iconContainer = document.createElement('div');
    iconContainer.style.display = 'grid';
    iconContainer.style.gridTemplateColumns = 'repeat(4, 1fr)';
    iconContainer.style.gap = '12px';
    iconContainer.style.marginBottom = '16px';
    
    // Define icons for various habit categories
    const icons = [
        // Reading/Learning
        { id: 'book', emoji: '📚', category: 'mind' },
        { id: 'graduation', emoji: '🎓', category: 'mind' },
        { id: 'writing', emoji: '✍️', category: 'mind' },
        { id: 'laptop', emoji: '💻', category: 'mind' },
        
        // Fitness/Health
        { id: 'running', emoji: '🏃', category: 'body' },
        { id: 'dumbbell', emoji: '🏋️', category: 'body' },
        { id: 'bicycle', emoji: '🚴', category: 'body' },
        { id: 'yoga', emoji: '🧘', category: 'body' },
        
        // Nutrition
        { id: 'water', emoji: '💧', category: 'body' },
        { id: 'salad', emoji: '🥗', category: 'body' },
        { id: 'fruit', emoji: '🍎', category: 'body' },
        { id: 'cooking', emoji: '👨‍🍳', category: 'body' },
        
        // Productivity
        { id: 'clock', emoji: '⏰', category: 'other' },
        { id: 'chart', emoji: '📊', category: 'other' },
        { id: 'briefcase', emoji: '💼', category: 'other' },
        { id: 'pencil', emoji: '✏️', category: 'other' },
        
        // Mindfulness
        { id: 'meditation', emoji: '🧠', category: 'spirit' },
        { id: 'heart', emoji: '❤️', category: 'spirit' },
        { id: 'music', emoji: '🎵', category: 'spirit' },
        { id: 'nature', emoji: '🌿', category: 'spirit' },
        
        // Finance
        { id: 'money', emoji: '💰', category: 'other' },
        { id: 'chart_up', emoji: '📈', category: 'other' },
        { id: 'bank', emoji: '🏦', category: 'other' },
        { id: 'calculator', emoji: '🧮', category: 'other' },
        
        // Social
        { id: 'friends', emoji: '👥', category: 'spirit' },
        { id: 'phone', emoji: '📱', category: 'spirit' },
        { id: 'handshake', emoji: '🤝', category: 'spirit' },
        { id: 'gift', emoji: '🎁', category: 'spirit' },
        
        // Misc/Other
        { id: 'star', emoji: '⭐', category: 'other' },
        { id: 'check', emoji: '✅', category: 'other' }
    ];
    
    // Keep track of selected icon ID - initialize with current habit icon or default to none
    let selectedIconId = habit.icon || 'none';
    
    // Create and append icon options
    icons.forEach(icon => {
        const iconButton = document.createElement('div');
        iconButton.className = 'icon-button';
        iconButton.setAttribute('data-icon-id', icon.id);
        iconButton.style.display = 'flex';
        iconButton.style.justifyContent = 'center';
        iconButton.style.alignItems = 'center';
        iconButton.style.width = '100%';
        iconButton.style.aspectRatio = '1/1';
        iconButton.style.backgroundColor = 'var(--section-bg-color)';
        iconButton.style.borderRadius = '12px';
        iconButton.style.border = icon.id === selectedIconId ? '2px solid #673ab7' : '1px solid #e0e0e0';
        iconButton.style.fontSize = '24px';
        iconButton.style.cursor = 'pointer';
        iconButton.style.transition = 'transform 0.2s ease, box-shadow 0.2s ease';
        
        // Set the emoji as content
        iconButton.textContent = icon.emoji;
        
        // Select this icon when clicked
        iconButton.addEventListener('click', () => {
            selectedIconId = icon.id;
            
            // Update all icon buttons to reflect the new selection
            iconContainer.querySelectorAll('.icon-button').forEach(btn => {
                btn.style.border = '1px solid #e0e0e0';
                btn.style.transform = 'scale(1)';
                btn.style.boxShadow = 'none';
            });
            
            // Highlight the selected icon
            iconButton.style.border = '2px solid #673ab7';
            iconButton.style.transform = 'scale(1.05)';
            iconButton.style.boxShadow = '0 0 3px rgba(103, 58, 183, 0.5)';
        });
        
        // Add hover effect
        iconButton.addEventListener('mouseover', () => {
            if (icon.id !== selectedIconId) {
                iconButton.style.transform = 'scale(1.05)';
                iconButton.style.boxShadow = '0 0 5px rgba(0,0,0,0.1)';
            }
        });
        
        iconButton.addEventListener('mouseout', () => {
            if (icon.id !== selectedIconId) {
                iconButton.style.transform = 'scale(1)';
                iconButton.style.boxShadow = 'none';
            }
        });
        
        iconContainer.appendChild(iconButton);
    });
    
    // Habit name input
    const nameInput = document.createElement('input');
    nameInput.type = 'text';
    nameInput.placeholder = 'Habit Name';
    nameInput.value = habit.name || '';
    nameInput.style.width = '100%';
    nameInput.style.padding = '16px';
    nameInput.style.fontSize = '16px';
    nameInput.style.marginBottom = '16px'; 
    nameInput.style.borderRadius = '8px';
    nameInput.style.border = '1px solid #ccc';
    nameInput.style.boxSizing = 'border-box';
    
    // Category selection
    const categoryLabel = document.createElement('div');
    categoryLabel.textContent = 'Category (Optional)';
    categoryLabel.style.fontSize = '16px';
    categoryLabel.style.fontWeight = 'bold';
    categoryLabel.style.marginBottom = '10px';
    
    // Create dropdown for categories
    const categorySelect = document.createElement('select');
    categorySelect.style.width = '100%';
    categorySelect.style.padding = '16px';
    categorySelect.style.fontSize = '16px';
    categorySelect.style.marginBottom = '16px';
    categorySelect.style.borderRadius = '8px';
    categorySelect.style.border = '1px solid #ccc';
    categorySelect.style.boxSizing = 'border-box';
    categorySelect.style.backgroundColor = 'var(--section-bg-color)';
    categorySelect.style.color = 'var(--text-color)';
    categorySelect.style.appearance = 'none';
    categorySelect.style.backgroundImage = 'url("data:image/svg+xml;charset=UTF-8,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'14\' height=\'14\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'2\' stroke-linecap=\'round\' stroke-linejoin=\'round\'%3E%3Cpolyline points=\'6 9 12 15 18 9\'%3E%3C/polyline%3E%3C/svg%3E")';
    categorySelect.style.backgroundRepeat = 'no-repeat';
    categorySelect.style.backgroundPosition = 'right 16px center';
    
    // Add default option
    const defaultOption = document.createElement('option');
    defaultOption.value = '';
    defaultOption.text = 'Select a category (optional)';
    categorySelect.appendChild(defaultOption);
    
    // Category options
    const categories = [
        { id: 'mind', name: 'Mind' },
        { id: 'body', name: 'Body' },
        { id: 'spirit', name: 'Spirit' },
        { id: 'other', name: 'Other' }
    ];
    
    // Add category options
    categories.forEach(category => {
        const option = document.createElement('option');
        option.value = category.id;
        option.text = category.name;
        option.selected = habit.category === category.id;
        categorySelect.appendChild(option);
    });
    
    // Number input for target/frequency
    const targetInput = document.createElement('input');
    targetInput.type = 'number';
    targetInput.min = '1';
    targetInput.max = '99';
    targetInput.value = habit.target || '7';
    targetInput.placeholder = 'Days to track';
    targetInput.style.width = '100%';
    targetInput.style.padding = '16px';
    targetInput.style.fontSize = '16px';
    targetInput.style.marginBottom = '16px';
    targetInput.style.borderRadius = '8px';
    targetInput.style.border = '1px solid #ccc';
    targetInput.style.boxSizing = 'border-box';
    
    // Color picker
    const colorLabel = document.createElement('div');
    colorLabel.textContent = 'Choose a Color';
    colorLabel.style.fontSize = '16px';
    colorLabel.style.fontWeight = 'bold';
    colorLabel.style.marginBottom = '10px';
    
    // Create color swatches container
    const colorSwatchesContainer = document.createElement('div');
    colorSwatchesContainer.style.display = 'flex';
    colorSwatchesContainer.style.flexWrap = 'wrap';
    colorSwatchesContainer.style.gap = '12px';
    colorSwatchesContainer.style.marginBottom = '16px';
    colorSwatchesContainer.style.justifyContent = 'center';
    
    // Define preset colors appropriate for habits
    const presetColors = [
        { value: '#2196F3', name: 'Blue' },
        { value: '#4CAF50', name: 'Green' },
        { value: '#9C27B0', name: 'Purple' },
        { value: '#F44336', name: 'Red' },
        { value: '#FF9800', name: 'Orange' },
        { value: '#009688', name: 'Teal' },
        { value: '#795548', name: 'Brown' },
        { value: '#607D8B', name: 'Gray Blue' }
    ];
    
    // Keep track of selected color - initialize with current habit color or default
    let selectedColor = habit.color || '#2196F3';
    
    // Create a color swatch for each preset color
    presetColors.forEach(color => {
        const swatch = document.createElement('div');
        swatch.className = 'color-swatch';
        swatch.title = color.name;
        swatch.style.width = '44px';
        swatch.style.height = '44px';
        swatch.style.backgroundColor = color.value;
        swatch.style.borderRadius = '50%';
        swatch.style.cursor = 'pointer';
        swatch.style.border = color.value === selectedColor ? '3px solid white' : '3px solid transparent';
        swatch.style.boxShadow = color.value === selectedColor ? '0 0 0 2px #673ab7' : '0 0 0 1px rgba(0,0,0,0.1)';
        swatch.style.transition = 'transform 0.2s ease, box-shadow 0.2s ease';
        
        // If this color is already the habit color, mark it as selected
        if (color.value === selectedColor) {
            swatch.style.border = '3px solid white';
            swatch.style.boxShadow = '0 0 0 2px #673ab7';
            swatch.style.transform = 'scale(1.1)';
        }
        
        // Select this color when clicked
        swatch.addEventListener('click', () => {
            selectedColor = color.value;
            
            // Update all swatches to reflect the new selection
            colorSwatchesContainer.querySelectorAll('.color-swatch').forEach(s => {
                s.style.border = '3px solid transparent';
                s.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
                s.style.transform = 'scale(1)';
            });
            
            // Highlight the selected swatch
            swatch.style.border = '3px solid white';
            swatch.style.boxShadow = '0 0 0 2px #673ab7';
            swatch.style.transform = 'scale(1.1)';
        });
        
        // Add hover effect
        swatch.addEventListener('mouseover', () => {
            if (color.value !== selectedColor) {
                swatch.style.transform = 'scale(1.1)';
                swatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.2)';
            }
        });
        
        swatch.addEventListener('mouseout', () => {
            if (color.value !== selectedColor) {
                swatch.style.transform = 'scale(1)';
                swatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
            }
        });
        
        colorSwatchesContainer.appendChild(swatch);
    });
    
    // Add a "custom color" option with rainbow indicator
    const customColorSwatch = document.createElement('div');
    customColorSwatch.className = 'color-swatch';
    customColorSwatch.title = 'Custom Color';
    customColorSwatch.style.width = '44px';
    customColorSwatch.style.height = '44px';
    customColorSwatch.style.borderRadius = '50%';
    customColorSwatch.style.cursor = 'pointer';
    customColorSwatch.style.border = '3px solid transparent';
    customColorSwatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
    customColorSwatch.style.position = 'relative';
    customColorSwatch.style.overflow = 'hidden';
    customColorSwatch.style.transition = 'transform 0.2s ease, box-shadow 0.2s ease';
    
    // Create rainbow gradient background for custom color picker
    customColorSwatch.style.background = 'linear-gradient(45deg, red, orange, yellow, green, blue, indigo, violet)';
    
    // Hidden native color picker
    const nativeColorPicker = document.createElement('input');
    nativeColorPicker.type = 'color';
    nativeColorPicker.style.opacity = '0';
    nativeColorPicker.style.position = 'absolute';
    nativeColorPicker.style.top = '0';
    nativeColorPicker.style.left = '0';
    nativeColorPicker.style.width = '100%';
    nativeColorPicker.style.height = '100%';
    nativeColorPicker.style.cursor = 'pointer';
    
    // Update when native color picker changes
    nativeColorPicker.addEventListener('input', (e) => {
        selectedColor = e.target.value;
        
        // Update all swatches to reflect the new selection
        colorSwatchesContainer.querySelectorAll('.color-swatch').forEach(s => {
            s.style.border = '3px solid transparent';
            s.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
            s.style.transform = 'scale(1)';
        });
        
        // Highlight the custom swatch
        customColorSwatch.style.border = '3px solid white';
        customColorSwatch.style.boxShadow = '0 0 0 2px #673ab7';
        customColorSwatch.style.transform = 'scale(1.1)';
    });
    
    // Add hover effect for custom swatch
    customColorSwatch.addEventListener('mouseover', () => {
        customColorSwatch.style.transform = 'scale(1.1)';
        customColorSwatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.2)';
    });
    
    customColorSwatch.addEventListener('mouseout', () => {
        if (customColorSwatch !== document.activeElement) {
            customColorSwatch.style.transform = 'scale(1)';
            customColorSwatch.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
        }
    });
    
    customColorSwatch.appendChild(nativeColorPicker);
    colorSwatchesContainer.appendChild(customColorSwatch);
    
    // Save button container
    const saveButtonContainer = document.createElement('div');
    saveButtonContainer.style.padding = '20px';
    saveButtonContainer.style.display = 'flex';
    saveButtonContainer.style.justifyContent = 'space-between';
    
    // Button container for save and cancel
    const buttonRow = document.createElement('div');
    buttonRow.style.display = 'flex';
    buttonRow.style.gap = '15px';
    buttonRow.style.width = '100%';
    
    // Cancel button
    const cancelButton = document.createElement('button');
    cancelButton.textContent = 'Cancel';
    cancelButton.style.backgroundColor = '#9e9e9e';
    cancelButton.style.color = 'white';
    cancelButton.style.padding = '16px 32px';
    cancelButton.style.borderRadius = '8px';
    cancelButton.style.border = 'none';
    cancelButton.style.fontSize = '16px';
    cancelButton.style.cursor = 'pointer';
    cancelButton.style.flex = '1';
    
    cancelButton.onclick = () => {
        // Use the showMainScreen function instead of directly manipulating DOM
        showMainScreen();
    };
    
    // Save button
    const saveButton = document.createElement('button');
    saveButton.textContent = 'Save';
    saveButton.style.backgroundColor = '#673ab7';
    saveButton.style.color = 'white';
    saveButton.style.padding = '16px 32px';
    saveButton.style.borderRadius = '8px';
    saveButton.style.border = 'none';
    saveButton.style.fontSize = '16px';
    saveButton.style.cursor = 'pointer';
    saveButton.style.flex = '1';
    
    // Save habit logic
    saveButton.onclick = () => {
        // Validate form
        if (nameInput.value && targetInput.value && parseInt(targetInput.value) > 0) {
            // Get selected category value
            const selectedCategory = categorySelect.value || 'Other';
            
            // Update the habit object
            habits[habitId].name = nameInput.value;
            habits[habitId].target = parseInt(targetInput.value);
            habits[habitId].color = selectedColor;
            habits[habitId].icon = selectedIconId !== 'none' ? selectedIconId : '';
            habits[habitId].category = selectedCategory;
            
            // Ensure the ID is stored in the habit object as well
            if (!habits[habitId].id) {
                habits[habitId].id = habitId;
            }
            
            // Save to localStorage
            saveHabitsToStorage(habits);
            
            // Use the showMainScreen function instead of directly manipulating DOM
            showMainScreen();
        } else {
            alert('Please fill out all fields');
        }
    };
    
    // Add buttons to container
    buttonRow.appendChild(cancelButton);
    buttonRow.appendChild(saveButton);
    saveButtonContainer.appendChild(buttonRow);
    
    // Assemble the form
    form.appendChild(heading);
    form.appendChild(iconLabel);
    form.appendChild(iconContainer);
    form.appendChild(nameInput);
    form.appendChild(categoryLabel);
    form.appendChild(categorySelect);
    form.appendChild(targetInput);
    form.appendChild(colorLabel);
    form.appendChild(colorSwatchesContainer);
    
    // Assemble the UI
    formContainer.appendChild(form);
    formContainer.appendChild(saveButtonContainer);
    
    appScreen.appendChild(appBar);
    appScreen.appendChild(formContainer);
    
    // Add to app-root instead of document.body
    appRoot.appendChild(appScreen);
    
    // Reset scroll position
    window.scrollTo(0, 0);
    
    // Focus the first input for better UX
    nameInput.focus();
}

// Settings screen with dark mode toggle
function showSettingsScreen() {
    // Get the app root element
    const appRoot = document.getElementById('app-root');
    
    // Clear app-root completely
    appRoot.innerHTML = '';
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.className = 'app-screen';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.className = 'app-bar';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.className = 'back-button';
    backButton.onclick = () => {
        // Return to the main screen using the consistent pattern
        showMainScreen();
    };
    
    // Title
    const title = document.createElement('h1');
    title.textContent = 'Settings';
    title.className = 'screen-title';
    
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Create settings container
    const settingsContainer = document.createElement('div');
    settingsContainer.className = 'scrollable-container';
    
    // Settings section: Appearance
    const appearanceSection = document.createElement('div');
    appearanceSection.className = 'settings-section';
    
    const appearanceTitle = document.createElement('h3');
    appearanceTitle.textContent = 'Appearance';
    appearanceTitle.className = 'settings-section-title';
    
    // Dark Mode Switch
    const darkModeRow = document.createElement('div');
    darkModeRow.className = 'settings-row';
    
    const darkModeLabel = document.createElement('div');
    darkModeLabel.className = 'settings-label';
    
    const darkModeLabelTitle = document.createElement('div');
    darkModeLabelTitle.textContent = 'Dark Mode';
    darkModeLabelTitle.className = 'settings-label-title';
    
    const darkModeLabelDesc = document.createElement('div');
    darkModeLabelDesc.textContent = 'Switch between light and dark themes';
    darkModeLabelDesc.className = 'settings-label-desc';
    
    darkModeLabel.appendChild(darkModeLabelTitle);
    darkModeLabel.appendChild(darkModeLabelDesc);
    
    // Switch component
    const switchContainer = document.createElement('label');
    switchContainer.className = 'theme-switch';
    
    const switchInput = document.createElement('input');
    switchInput.type = 'checkbox';
    switchInput.checked = isDarkModeEnabled();
    
    const switchSlider = document.createElement('span');
    switchSlider.className = 'theme-switch-slider';
    
    switchContainer.appendChild(switchInput);
    switchContainer.appendChild(switchSlider);
    
    // Toggle dark mode
    switchInput.onchange = (e) => {
        const checked = e.target.checked;
        
        // Save the theme preference
        localStorage.setItem('isDarkMode', checked);
        
        // Apply theme consistently
        document.body.setAttribute('data-theme', checked ? 'dark' : 'light');
        
        // Notify all theme listeners
        notifyThemeChange();
    };
    
    darkModeRow.appendChild(darkModeLabel);
    darkModeRow.appendChild(switchContainer);
    
    appearanceSection.appendChild(appearanceTitle);
    appearanceSection.appendChild(darkModeRow);
    
    // Notifications Section
    const notificationsSection = document.createElement('div');
    notificationsSection.className = 'settings-section';
    
    const notificationsTitle = document.createElement('h3');
    notificationsTitle.textContent = 'Notifications';
    notificationsTitle.className = 'settings-section-title';
    
    // Notification test button
    const testNotificationButton = document.createElement('button');
    testNotificationButton.textContent = 'Test Notification';
    testNotificationButton.className = 'btn btn-primary';
    
    notificationsSection.appendChild(notificationsTitle);
    notificationsSection.appendChild(testNotificationButton);
    
    // Add sections to container
    settingsContainer.appendChild(appearanceSection);
    settingsContainer.appendChild(notificationsSection);
    
    // Assemble the screen
    appScreen.appendChild(appBar);
    appScreen.appendChild(settingsContainer);
    
    // Add to app-root
    appRoot.appendChild(appScreen);
    
    // Scroll to top of the page
    window.scrollTo(0, 0);
    
    // Apply theme immediately to ensure new elements have proper styles
    applyTheme();
    
    // Setup event listeners for the settings screen
    setupEventListeners();
}

// Function to show the main screen
function showMainScreen() {
    // Get the app root element
    const appRoot = document.getElementById('app-root');
    
    // Clear app-root completely 
    appRoot.innerHTML = '';
    
    // Rebuild the main UI from scratch based on the index.html template
    appRoot.innerHTML = `
        <div class="app-header">
            <h1>Momentum</h1>
            <div class="header-icons">
                <div class="calendar-icon" onclick="showCalendarScreen()" style="margin-right: 15px;">📅</div>
                <div class="settings-icon" onclick="showSettingsScreen()">⚙️</div>
            </div>
        </div>
        
        <!-- Category filters -->
        <div id="category-filters" class="category-filters" style="display: flex; overflow-x: auto; padding: 10px; gap: 10px; scrollbar-width: none; -ms-overflow-style: none;">
            <!-- Category filter buttons will be added by JavaScript -->
        </div>
        
        <div id="habits-container" style="padding: 0 10px;">
            <!-- Habits will be dynamically inserted here by JavaScript -->
        </div>
        
        <div class="add-button" onclick="showAddHabitScreen()">+</div>
    `;
    
    // Reset scroll position
    window.scrollTo(0, 0);
    
    // Use requestAnimationFrame to ensure DOM is ready before manipulating it
    requestAnimationFrame(() => {
        // Load habits from storage
        loadHabits();
        
        // Render habits to the DOM
        renderHabits();
        
        // Set up category filters
        setupCategoryFilters();
        
        // Apply the current theme
        applyTheme();
        
        // Set up event listeners
        setupEventListeners();
        
        // Update statistics
        updateStats();
    });
}

// Show Calendar Screen
function showCalendarScreen() {
    // Get the app root
    const appRoot = document.getElementById('app-root');
    
    // Clear app-root completely
    appRoot.innerHTML = '';
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.className = 'app-screen';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.className = 'app-bar';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.className = 'back-button';
    backButton.onclick = () => {
        // Show the main screen instead of restoring from mainContent
        showMainScreen();
    };
    
    // Title
    const title = document.createElement('h1');
    title.textContent = 'Habit Calendar';
    title.className = 'screen-title';
    
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Create calendar container (scrollable)
    const calendarContainer = document.createElement('div');
    calendarContainer.className = 'calendar-container';
    
    // Create calendar content
    const calendarContent = document.createElement('div');
    calendarContent.className = 'calendar-section';
    
    const calendarHeading = document.createElement('h2');
    calendarHeading.className = 'settings-section-title';
    calendarHeading.textContent = 'Habit History';
    
    // Add category filter container
    const categoryFiltersContainer = document.createElement('div');
    categoryFiltersContainer.className = 'category-filters';
    categoryFiltersContainer.style.display = 'flex';
    categoryFiltersContainer.style.flexWrap = 'wrap';
    categoryFiltersContainer.style.gap = '8px';
    categoryFiltersContainer.style.marginBottom = '16px';
    
    // Add "All Habits" filter button
    const allButton = document.createElement('button');
    allButton.className = 'filter-button';
    allButton.setAttribute('data-category', 'all');
    allButton.textContent = 'All Habits';
    
    // Set initial state
    if (!window.calendarCurrentCategory || window.calendarCurrentCategory === 'all') {
        allButton.classList.add('active');
    }
    
    allButton.onclick = () => {
        window.calendarCurrentCategory = 'all';
        updateCalendarCategoryFilter('all');
    };
    
    categoryFiltersContainer.appendChild(allButton);
    
    // Get unique categories from habits
    const categories = new Set();
    Object.values(habits).forEach(habit => {
        if (habit.category) {
            categories.add(capitalizeCategory(habit.category));
        } else {
            categories.add('Other');
        }
    });
    
    // Add a button for each category
    Array.from(categories).sort().forEach(category => {
        const categoryButton = document.createElement('button');
        categoryButton.className = 'filter-button';
        categoryButton.setAttribute('data-category', category);
        categoryButton.textContent = category;
        
        // Set initial state
        if (window.calendarCurrentCategory === category) {
            categoryButton.classList.add('active');
        }
        
        categoryButton.onclick = () => {
            window.calendarCurrentCategory = category;
            updateCalendarCategoryFilter(category);
        };
        
        categoryFiltersContainer.appendChild(categoryButton);
    });
    
    // Create month selector for calendar
    const monthSelector = document.createElement('div');
    monthSelector.className = 'month-selector';
    monthSelector.style.marginTop = '12px';
    monthSelector.style.marginBottom = '15px';
    monthSelector.style.display = 'flex';
    monthSelector.style.justifyContent = 'space-between';
    monthSelector.style.alignItems = 'center';
    monthSelector.style.width = '100%';
    
    // Previous month button
    const prevButton = document.createElement('button');
    prevButton.className = 'month-nav-button';
    prevButton.innerHTML = '&larr;';
    prevButton.style.marginRight = '8px';
    
    // Current month and year display
    const currentMonthDisplay = document.createElement('div');
    const currentDate = new Date();
    currentMonthDisplay.textContent = `${currentDate.toLocaleString('default', { month: 'long' })} ${currentDate.getFullYear()}`;
    currentMonthDisplay.style.fontSize = '18px';
    currentMonthDisplay.style.fontWeight = 'bold';
    currentMonthDisplay.style.textAlign = 'center';
    currentMonthDisplay.style.flex = '1';
    currentMonthDisplay.style.minWidth = '150px';
    currentMonthDisplay.style.padding = '0 10px';
    
    // Next month button
    const nextButton = document.createElement('button');
    nextButton.className = 'month-nav-button';
    nextButton.innerHTML = '&rarr;';
    nextButton.style.marginLeft = '8px';
    
    // Month navigation handlers
    const currentViewDate = new Date();
    let currentViewMonth = currentViewDate.getMonth();
    let currentViewYear = currentViewDate.getFullYear();
    
    prevButton.onclick = () => {
        if (currentViewMonth === 0) {
            currentViewMonth = 11;
            currentViewYear--;
        } else {
            currentViewMonth--;
        }
        renderCalendarDays();
    };
    
    nextButton.onclick = () => {
        if (currentViewMonth === 11) {
            currentViewMonth = 0;
            currentViewYear++;
        } else {
            currentViewMonth++;
        }
        renderCalendarDays();
    };
    
    monthSelector.appendChild(prevButton);
    monthSelector.appendChild(currentMonthDisplay);
    monthSelector.appendChild(nextButton);
    
    // Create calendar grid
    const calendarGrid = document.createElement('div');
    calendarGrid.className = 'calendar-grid';
    
    // Add day headers (Sun-Sat)
    const daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    daysOfWeek.forEach(day => {
        const dayHeader = document.createElement('div');
        dayHeader.textContent = day;
        dayHeader.style.textAlign = 'center';
        dayHeader.style.fontWeight = 'bold';
        dayHeader.style.padding = '5px';
        calendarGrid.appendChild(dayHeader);
    });
    
    // Function to render calendar days for the current view
    function renderCalendarDays() {
        // Clear existing days
        while (calendarGrid.childElementCount > 7) {
            calendarGrid.removeChild(calendarGrid.lastChild);
        }
        
        // Update month display
        currentMonthDisplay.textContent = `${new Date(currentViewYear, currentViewMonth, 1).toLocaleString('default', { month: 'long' })} ${currentViewYear}`;
        
        // First day of the month (0-6, where 0 is Sunday)
        const firstDay = new Date(currentViewYear, currentViewMonth, 1).getDay();
        
        // Number of days in the month
        const daysInMonth = new Date(currentViewYear, currentViewMonth + 1, 0).getDate();
        
        // Add empty cells for days before the start of the month
        for (let i = 0; i < firstDay; i++) {
            const emptyCell = document.createElement('div');
            emptyCell.className = 'calendar-day empty';
            calendarGrid.appendChild(emptyCell);
        }
        
        // Add days of the month
        for (let day = 1; day <= daysInMonth; day++) {
            const dayCell = document.createElement('div');
            dayCell.className = 'calendar-day';
            
            // Check if this is today
            const today = new Date();
            if (today.getDate() === day && 
                today.getMonth() === currentViewMonth && 
                today.getFullYear() === currentViewYear) {
                dayCell.classList.add('today');
            }
            
            // Add day number
            const dayNumber = document.createElement('div');
            dayNumber.className = 'date-number';
            dayNumber.textContent = day;
            dayCell.appendChild(dayNumber);
            
            // Add completion indicators
            const dateStr = getLocalDateString(currentViewYear, currentViewMonth, day);
            addCompletionIndicators(dayCell, dateStr);
            
            // Store the date string as a data attribute
            dayCell.dataset.date = dateStr;
            
            // Add click handler to show details
            dayCell.onclick = () => {
                // Call calendar.js showDayDetails with the habits object
                if (typeof window.showDayDetails === 'function') {
                    // Call the function from calendar.js
                    window.showDayDetails(dateStr, isDarkModeEnabled(), habits);
                } else {
                    // Fallback to local function
                    showDayDetails(dateStr);
                }
            };
            
            calendarGrid.appendChild(dayCell);
        }
    }
    
    // Helper function to add completion indicators to a day cell
    function addCompletionIndicators(cell, dateStr) {
        const habitHistory = loadHabitHistory();
        const dateHistory = habitHistory[dateStr] || {};
        
        // Add indicators container
        const indicators = document.createElement('div');
        indicators.className = 'habit-indicators';
        
        // If we have a category filter, only show habits in that category
        const filteredHabits = Object.entries(habits).filter(([_, habit]) => {
            return !window.calendarCurrentCategory || 
                   window.calendarCurrentCategory === 'all' || 
                   capitalizeCategory(habit.category || 'Other') === window.calendarCurrentCategory;
        });
        
        // Count completed and not completed habits
        let completedCount = 0;
        let notCompletedCount = 0;
        
        filteredHabits.forEach(([habitId, habit]) => {
            const status = checkHabitCompletion(habit, dateStr, habitHistory);
            if (status === "completed") {
                completedCount++;
                
                // Add an indicator for this completed habit
                if (completedCount <= 3) { // Limit to 3 indicators to avoid overflow
                    const indicator = document.createElement('span');
                    indicator.className = 'habit-indicator completed';
                    indicator.style.color = habit.color; // Use habit color
                    indicators.appendChild(indicator);
                }
            } else if (status === "not_completed") {
                notCompletedCount++;
                
                // Add an indicator for this not-completed habit
                if (notCompletedCount <= 3) { // Limit to 3 indicators to avoid overflow
                    const indicator = document.createElement('span');
                    indicator.className = 'habit-indicator not-completed';
                    indicators.appendChild(indicator);
                }
            }
        });
        
        // Add "more" indicator if we have more than 3 habits
        if (completedCount + notCompletedCount > 3) {
            const moreIndicator = document.createElement('span');
            moreIndicator.className = 'more-indicator';
            moreIndicator.textContent = '+';
            indicators.appendChild(moreIndicator);
        }
        
        cell.appendChild(indicators);
    }
    
    // Assemble the calendar components
    calendarContent.appendChild(calendarHeading);
    calendarContent.appendChild(categoryFiltersContainer);
    calendarContent.appendChild(monthSelector);
    calendarContent.appendChild(calendarGrid);
    calendarContainer.appendChild(calendarContent);
    
    // Assemble the screen
    appScreen.appendChild(appBar);
    appScreen.appendChild(calendarContainer);
    
    // Add to app-root instead of body
    appRoot.appendChild(appScreen);
    
    // Scroll to top of the page
    window.scrollTo(0, 0);
    
    // Function to update category filters
    function updateCalendarCategoryFilter(selectedCategory) {
        // Update active state on buttons
        const filterButtons = categoryFiltersContainer.querySelectorAll('.filter-button');
        filterButtons.forEach(btn => {
            if (btn.getAttribute('data-category') === selectedCategory) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        });
        
        // Re-render calendar with new filter
        renderCalendarDays();
    }
    
    // Render the calendar days initially
    renderCalendarDays();
    
    // Setup event listeners for the calendar screen
    setupEventListeners();
}

// Function to apply the current theme to the app
function applyTheme() {
    const isDarkMode = isDarkModeEnabled();
    
    // Set data-theme attribute for CSS variables - critical for theme inheritance
    document.body.setAttribute('data-theme', isDarkMode ? 'dark' : 'light');
    
    // Keep the dark-mode class for backward compatibility
    document.body.classList.toggle('dark-mode', isDarkMode);
    
    // Process any elements with habit indicators that used inline styles
    const habitIndicators = document.querySelectorAll('.habit-indicator.completed');
    habitIndicators.forEach(indicator => {
        // If the indicator has a data-color attribute, use it for the indicator's color
        if (indicator.dataset.color) {
            indicator.style.backgroundColor = indicator.dataset.color;
        }
    });
    
    // Process any category filter buttons to ensure they use CSS variables instead of inline styles
    const categoryButtons = document.querySelectorAll('.category-filter-btn');
    categoryButtons.forEach(button => {
        // Remove any inline styles
        button.removeAttribute('style');
        
        // Apply active class if it's the current filter
        if ((button.getAttribute('data-category') === window.currentCategoryFilter) ||
            (capitalizeCategory(window.currentCategoryFilter) === button.getAttribute('data-category'))) {
            button.classList.add('active');
        } else {
            button.classList.remove('active');
        }
    });
    
    // Notify any components that need to adjust to theme changes
    notifyThemeChange();
}

function renderHabitCard(habitId, habit) {
    const habitCard = document.createElement('div');
    habitCard.className = 'habit-card';
    habitCard.id = `habit-card-${habitId}`;
    // Add data-category attribute for filtering
    habitCard.dataset.category = capitalizeCategory(habit.category || 'Other');
    
    // Always apply the habit's custom color directly with high specificity
    habitCard.style.setProperty('background-color', habit.color || '#4CAF50', 'important');
    
    // Set color RGB variables for animations and effects
    const colorRGB = hexToRgb(habit.color || '#4CAF50');
    if (colorRGB) {
        habitCard.style.setProperty('--habit-color-rgb', `${colorRGB.r}, ${colorRGB.g}, ${colorRGB.b}`);
    }
    
    // Determine if the background color is dark to set appropriate text color
    const isDarkBackground = isColorDark(habit.color || '#4CAF50');
    
    // Create the habit content
    const habitContent = document.createElement('div');
    habitContent.className = 'habit-content';
    habitContent.style.color = isDarkBackground ? '#FFFFFF' : '#000000';
    habitContent.style.position = 'relative';
    habitContent.style.zIndex = '1';
    
    // Add habit icon and name
    const habitHeader = document.createElement('div');
    habitHeader.className = 'habit-header';
    habitHeader.innerHTML = `
        <span class="habit-icon">${habit.icon || '⭐'}</span>
        <span class="habit-name">${habit.name}</span>
    `;
    
    // Add progress text
    const progressText = document.createElement('div');
    progressText.className = 'progress-text';
    progressText.textContent = `${habit.progress}/${habit.target}`;
    progressText.dataset.habitProgress = habit.progress;
    progressText.dataset.habitTarget = habit.target;
    progressText.style.color = isDarkBackground ? '#FFFFFF' : '#000000';
    
    // Create progress bar
    const progressBar = document.createElement('div');
    progressBar.className = 'progress-bar';
    progressBar.style.backgroundColor = isDarkBackground ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.1)';
    
    const progressFill = document.createElement('div');
    progressFill.className = 'progress-fill';
    progressFill.style.width = Math.min((habit.progress / habit.target) * 100, 100) + '%';
    progressFill.style.backgroundColor = isDarkBackground ? '#FFFFFF' : 'rgba(0,0,0,0.7)';
    progressBar.appendChild(progressFill);
    
    // Add buttons container
    const buttonsContainer = document.createElement('div');
    buttonsContainer.className = 'habit-buttons';
    buttonsContainer.style.display = 'flex';
    buttonsContainer.style.justifyContent = 'space-between';
    
    // Add progress buttons container (- and +)
    const progressButtonsContainer = document.createElement('div');
    progressButtonsContainer.style.display = 'flex';
    progressButtonsContainer.style.gap = '10px';
    
    // Add decrement button with proper event listener
    const decrementButton = document.createElement('button');
    decrementButton.className = 'habit-button decrement';
    decrementButton.innerHTML = '<span>-</span>';
    decrementButton.style.color = isDarkBackground ? '#FFFFFF' : '#000000';
    decrementButton.disabled = habit.progress <= 0;
    decrementButton.addEventListener('click', (e) => {
        e.stopPropagation(); // Prevent event bubbling
        if (habit.progress > 0) {
            decrementButton.classList.add('button-clicked');
            setTimeout(() => decrementButton.classList.remove('button-clicked'), 300);
            updateProgress(habitId, -1);
        }
    });
    
    // Add increment button with proper event listener
    const incrementButton = document.createElement('button');
    incrementButton.className = 'habit-button increment';
    incrementButton.innerHTML = '<span>+</span>';
    incrementButton.style.color = isDarkBackground ? '#FFFFFF' : '#000000';
    incrementButton.disabled = habit.progress >= habit.target;
    incrementButton.addEventListener('click', (e) => {
        e.stopPropagation(); // Prevent event bubbling
        if (habit.progress < habit.target) {
            incrementButton.classList.add('button-clicked');
            setTimeout(() => incrementButton.classList.remove('button-clicked'), 300);
            updateProgress(habitId, 1);
        }
    });
    
    // Add admin buttons container (settings and delete)
    const adminButtonsContainer = document.createElement('div');
    adminButtonsContainer.style.display = 'flex';
    adminButtonsContainer.style.gap = '16px';
    
    // Add edit button with proper event listener
    const editButton = document.createElement('button');
    editButton.className = 'habit-button edit';
    editButton.innerHTML = '⚙️';
    editButton.addEventListener('click', (e) => {
        e.stopPropagation(); // Prevent event bubbling
        showEditHabitScreen(habitId, habit);
    });
    
    // Add delete button with proper event listener
    const deleteButton = document.createElement('button');
    deleteButton.className = 'habit-button delete';
    deleteButton.innerHTML = '🗑️';
    deleteButton.style.color = isDarkBackground ? '#FFFFFF' : '#000000';
    deleteButton.addEventListener('click', (e) => {
        e.stopPropagation(); // Prevent event bubbling
        deleteHabit(habitId);
    });
    
    // Assemble the buttons in their respective containers
    progressButtonsContainer.appendChild(decrementButton);
    progressButtonsContainer.appendChild(incrementButton);
    
    adminButtonsContainer.appendChild(editButton);
    adminButtonsContainer.appendChild(deleteButton);
    
    // Add button containers to the main buttons container
    buttonsContainer.appendChild(progressButtonsContainer);
    buttonsContainer.appendChild(adminButtonsContainer);
    
    // Assemble all components
    habitContent.appendChild(habitHeader);
    habitContent.appendChild(progressText);
    habitContent.appendChild(progressBar);
    habitContent.appendChild(buttonsContainer);
    
    // Add streak information if available
    if (habit.currentStreak > 0 || habit.bestStreak > 0) {
        const streakInfo = document.createElement('div');
        streakInfo.className = 'streak-info';
        streakInfo.innerHTML = `
            <span class="current-streak">🔥 ${habit.currentStreak || 0}</span>
            <span class="best-streak">⭐ ${habit.bestStreak || 0}</span>
        `;
        habitContent.appendChild(streakInfo);
    }
    
    habitCard.appendChild(habitContent);
    return habitCard;
}

// Helper function to determine if a color is dark (for text contrast)
function isColorDark(hexColor) {
    const rgb = hexToRgb(hexColor);
    if (!rgb) return false;
    
    // Calculate perceived brightness using YIQ formula
    const brightness = (rgb.r * 299 + rgb.g * 587 + rgb.b * 114) / 1000;
    return brightness < 128; // If less than 128, consider it dark
}

// Helper function to convert hex color to RGB values for CSS variables
function hexToRgb(hex) {
    // Remove the # if present
    hex = hex.replace(/^#/, '');
    
    // Handle shorthand hex (e.g., #FFF)
    if (hex.length === 3) {
        hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    }
    
    // Parse the hex values
    const bigint = parseInt(hex, 16);
    
    // Only parse valid colors
    if (isNaN(bigint)) return null;
    
    // Extract r, g, b components
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    
    return { r, g, b };
}

function updateHabitCardInDOM(habitId, habit) {
    const existingCard = document.getElementById(`habit-card-${habitId}`);
    if (existingCard) {
        // Get current category filter
        const currentFilter = document.querySelector('.category-filter.active')?.dataset.category || 'All';
        
        // Create new card with updated data
        const newCard = renderHabitCard(habitId, habit);
        
        // Add animation class for smooth transition
        newCard.classList.add('card-update-animation');
        
        // Add completion flash animation if habit is completed
        if (habit.progress === habit.target) {
            newCard.classList.add('completion-flash');
        }
        
        // Ensure category data attribute is properly set
        const category = capitalizeCategory(habit.category || 'Other');
        newCard.dataset.category = category;
        console.log(`Updated habit card category: ${habit.name} - Category: ${category}`);
        
        // Replace the old card with the new one
        existingCard.replaceWith(newCard);
        
        // Apply current category filter
        if (currentFilter !== 'All') {
            newCard.style.display = (category === currentFilter) ? 'block' : 'none';
        }
        
        // Add necessary CSS if not already present
        if (!document.getElementById('card-animations')) {
            const styleSheet = document.createElement('style');
            styleSheet.id = 'card-animations';
            styleSheet.textContent = `
                .card-update-animation {
                    animation: cardUpdate 0.3s ease-out;
                }
                
                .completion-flash {
                    animation: completionFlash 0.6s ease-out;
                }
                
                .button-clicked {
                    transform: scale(0.9);
                    opacity: 0.8;
                    transition: transform 0.3s, opacity 0.3s;
                }
                
                @keyframes cardUpdate {
                    0% { transform: scale(0.98); opacity: 0.8; }
                    100% { transform: scale(1); opacity: 1; }
                }
                
                @keyframes completionFlash {
                    0% { box-shadow: 0 0 0 0 rgba(var(--habit-color-rgb), 0.4); }
                    70% { box-shadow: 0 0 0 10px rgba(var(--habit-color-rgb), 0); }
                    100% { box-shadow: 0 0 0 0 rgba(var(--habit-color-rgb), 0); }
                }
            `;
            document.head.appendChild(styleSheet);
        }
        
        // Log update for debugging
        console.log(`Updated habit card: ${habit.name} - Progress: ${habit.progress}/${habit.target}`);
        
        // Remove animation classes after they complete
        setTimeout(() => {
            newCard.classList.remove('card-update-animation', 'completion-flash');
        }, 600);
    }
}

// Delete a habit
function deleteHabit(habitId) {
    const habit = habits[habitId];
    
    // Confirm before deleting
    if (confirm(`Are you sure you want to delete "${habit.name}"?`)) {
        // Remove from memory
        delete habits[habitId];
        
        // Save to localStorage
        saveHabitsToStorage(habits);
        
        // Show toast notification
        showToast(`Habit "${habit.name}" deleted successfully.`, '#FF5722');
        
        // Re-render habits list
        renderHabits();
    }
}

// Reset habit progress function
function resetHabitProgress(habitId) {
    const habit = habits[habitId];
    
    if (confirm(`Are you sure you want to reset progress for "${habit.name}"?`)) {
        // Store the current progress for undo
        const previousProgress = habit.progress;
        
        // Reset progress
        habit.progress = 0;
        
        // Save to localStorage
        saveHabitsToStorage(habits);
        
        // Update the habit card in the DOM
        updateHabitCardInDOM(habitId, habit);
        
        // Show toast with undo option
        const message = `Progress for "${habit.name}" has been reset.`;
        const undoAction = () => {
            habit.progress = previousProgress;
            saveHabitsToStorage(habits);
            updateHabitCardInDOM(habitId, habit);
            showToast(`Progress for "${habit.name}" has been restored.`);
        };
        
        showToastWithUndo(message, undoAction);
    }
}

// Show toast message with undo option
function showToastWithUndo(message, undoAction, bgColor = '#333', duration = 5000) {
    const toast = document.createElement('div');
    toast.className = 'toast-with-undo';
    toast.style.position = 'fixed';
    toast.style.bottom = '20px';
    toast.style.left = '50%';
    toast.style.transform = 'translateX(-50%)';
    toast.style.backgroundColor = bgColor;
    toast.style.color = '#fff';
    toast.style.padding = '12px 20px';
    toast.style.borderRadius = '4px';
    toast.style.boxShadow = '0 3px 10px rgba(0, 0, 0, 0.2)';
    toast.style.zIndex = '1000';
    toast.style.display = 'flex';
    toast.style.alignItems = 'center';
    toast.style.justifyContent = 'space-between';
    toast.style.minWidth = '250px';
    toast.style.maxWidth = '90%';
    
    const messageText = document.createElement('span');
    messageText.textContent = message;
    
    const undoButton = document.createElement('button');
    undoButton.textContent = 'UNDO';
    undoButton.style.marginLeft = '15px';
    undoButton.style.backgroundColor = 'transparent';
    undoButton.style.border = 'none';
    undoButton.style.color = '#4CAF50';
    undoButton.style.fontWeight = 'bold';
    undoButton.style.cursor = 'pointer';
    undoButton.style.padding = '5px';
    
    undoButton.addEventListener('click', () => {
        if (undoAction) undoAction();
        toast.remove();
        clearTimeout(timeoutId);
    });
    
    toast.appendChild(messageText);
    toast.appendChild(undoButton);
    document.body.appendChild(toast);
    
    // Remove the toast after the duration
    const timeoutId = setTimeout(() => {
        if (document.body.contains(toast)) {
            toast.style.opacity = '0';
            toast.style.transform = 'translate(-50%, 100%)';
            toast.style.transition = 'opacity 0.3s, transform 0.3s';
            setTimeout(() => {
                if (document.body.contains(toast)) {
                    toast.remove();
                }
            }, 300);
        }
    }, duration);
}

// Show reminder settings for a habit
function showReminderSettings(habitId, habit) {
    if (!areNotificationsSupported()) {
        showToast('Notifications are not supported in this browser.', '#FF5722');
        return;
    }
    
    // Request notification permission if not already granted
    if (Notification.permission !== 'granted') {
        requestNotificationPermission().then(permission => {
            if (permission !== 'granted') {
                showToast('Notification permission is required for reminders.', '#FF5722');
                return;
            } else {
                // Continue with reminder setup
                setupReminderDialog();
            }
        });
    } else {
        // Permission already granted, show reminder dialog
        setupReminderDialog();
    }
    
    function setupReminderDialog() {
        // Create a simple prompt for time input
        const reminderTime = prompt('Enter reminder time (HH:MM):', habit.reminderTime || '09:00');
        
        // Validate input or cancel
        if (!reminderTime) return;
        
        // Simple validation for time format
        const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
        if (!timeRegex.test(reminderTime)) {
            showToast('Invalid time format. Please use HH:MM format.', '#FF5722');
            return;
        }
        
        // Save the reminder settings
        habit.reminderEnabled = true;
        habit.reminderTime = reminderTime;
        saveHabitsToStorage(habits);
        
        // Start checking reminders
        startReminderCheck();
        
        showToast(`Reminder set for "${habit.name}" at ${reminderTime}`, '#4CAF50');
    }
}

// Global variables
window.currentCategoryFilter = window.currentCategoryFilter || 'all';

// Helper function to capitalize category names
function capitalizeCategory(category) {
    // Handle null, undefined, or empty string
    if (!category) return 'Other';
    
    // Normalize whitespace and trim
    const trimmedCategory = category.trim();
    if (trimmedCategory === '') return 'Other';
    
    // Split by spaces and capitalize each word
    return trimmedCategory
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');
}

// Filter habits by category
function filterHabitsByCategory(categoryId) {
    console.log(`Filtering by category: ${categoryId}`);
    
    // Convert both the filter and habit categories to the same case for case-insensitive comparison
    const filterCategory = categoryId ? categoryId.toLowerCase() : 'all';
    window.currentCategoryFilter = filterCategory;
    
    // If no habits in the DOM yet, return early
    if (!document.querySelector('.habit-card')) {
        console.warn('No habits found in DOM for filtering');
        return;
    }
    
    // Update active class on category buttons
    const categoryButtons = document.querySelectorAll('.category-filter-btn');
    categoryButtons.forEach(btn => {
        const buttonCategory = btn.getAttribute('data-category').toLowerCase();
        if (buttonCategory === filterCategory) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
    
    // Get all habit cards
    const habitCards = document.querySelectorAll('.habit-card');
    let visibleCount = 0;
    
    // Loop through each habit card
        habitCards.forEach(card => {
        // Get the category of this habit card
        const cardCategory = card.dataset.category ? card.dataset.category.toLowerCase() : 'other';
        
        // For debugging
        console.log(`Checking card with category: ${cardCategory} against filter: ${filterCategory}`);
        
        // Show all if filter is 'all', otherwise show only matching categories
        if (filterCategory === 'all' || cardCategory === filterCategory) {
            card.style.display = '';
                visibleCount++;
                
            // Add a nice animation
            card.style.animation = 'fadeInUp 0.3s forwards';
            } else {
                card.style.display = 'none';
            }
        });
    
    // Show message if no habits match the filter
    let noHabitsMessage = document.querySelector('.no-habits-message');
    if (visibleCount === 0) {
        if (!noHabitsMessage) {
            noHabitsMessage = document.createElement('div');
    noHabitsMessage.className = 'no-habits-message';
            noHabitsMessage.textContent = filterCategory === 'all' 
                ? 'You have no habits yet. Add one with the + button below.' 
                : `No habits found in the "${capitalizeCategory(filterCategory)}" category.`;
        
        const habitsContainer = document.getElementById('habits-container');
            habitsContainer.appendChild(noHabitsMessage);
        }
    } else if (noHabitsMessage) {
        document.querySelector('.no-habits-message').remove();
    }
    
    // Update stats to reflect the currently visible habits
    updateStats();
    
    // Save current filter to localStorage for persistence
    localStorage.setItem('currentCategoryFilter', filterCategory);
}

// Function to set up category filters
function setupCategoryFilters() {
    // Wait for DOM to be ready
    if (!document.getElementById('habits-container')) {
        console.warn('Habits container not found, deferring category filter setup');
        return;
    }
    
    // Find or create the category filters container
    let categoryFiltersContainer = document.querySelector('.category-filters');
    if (!categoryFiltersContainer) {
        categoryFiltersContainer = document.createElement('div');
        categoryFiltersContainer.className = 'category-filters';
        
        // Insert before the habits container
        const habitsContainer = document.getElementById('habits-container');
        habitsContainer.parentNode.insertBefore(categoryFiltersContainer, habitsContainer);
    }
    
    // Clear existing filters
    categoryFiltersContainer.innerHTML = '';
    
    // Add "All" filter button
    const allButton = document.createElement('button');
    allButton.className = 'category-filter-btn';
    allButton.setAttribute('data-category', 'all');
    allButton.textContent = 'All Habits';
    
    // Set initial state based on window.currentCategoryFilter
    if (window.currentCategoryFilter === 'all') {
        allButton.classList.add('active');
    }
    
    allButton.onclick = () => {
        filterHabitsByCategory('all');
    };
    
    categoryFiltersContainer.appendChild(allButton);
    
    // Get unique categories from habits
    const categories = new Set();
    Object.values(habits).forEach(habit => {
        if (habit.category) {
            categories.add(capitalizeCategory(habit.category));
        } else {
            categories.add('Other');
        }
    });
    
    // Add a button for each category
    Array.from(categories).sort().forEach(category => {
        const categoryButton = document.createElement('button');
        categoryButton.className = 'category-filter-btn';
        categoryButton.setAttribute('data-category', category);  // Use the properly capitalized category
        categoryButton.textContent = category;
        
        // Set initial state based on window.currentCategoryFilter
        const currentFilterCap = capitalizeCategory(window.currentCategoryFilter);
        if (currentFilterCap === category) {  // Compare with capitalized category
            categoryButton.classList.add('active');
        }
        
        categoryButton.onclick = () => {
            filterHabitsByCategory(category);  // Use the properly capitalized category
        };
        
        categoryFiltersContainer.appendChild(categoryButton);
    });
    
    // Apply current filter
    filterHabitsByCategory(window.currentCategoryFilter);
}

// Initialize the app
function initApp() {
    // Load saved category filter or default to 'all'
    window.currentCategoryFilter = localStorage.getItem('currentCategoryFilter') || 'all';
    
    // Use requestAnimationFrame to ensure DOM is ready
    requestAnimationFrame(() => {
    loadHabits();
    renderHabits();
    
    // Ensure DOM is loaded before setting up filters
            setupCategoryFilters();
            filterHabitsByCategory(window.currentCategoryFilter);
    
    setupEventListeners();
    updateStats();
        
        // Only call checkStreaks if it exists
        if (typeof checkStreaks === 'function') {
    checkStreaks();
        }
    });
}

// Add global event listener for navigation
window.addEventListener('popstate', () => {
    const route = window.location.hash.slice(1) || 'home';
    handleRouteChange(route);
});

// Initialize on page load
document.addEventListener('DOMContentLoaded', init);

// Update the init function to include category filters and button handlers
function init() {
    // Call the new consolidated init function
    initApp();
    
    // Apply theme
    applyTheme();
    
    // Set up all event listeners, including the calendar and settings icons
    setupEventListeners();
    
    // Handle initial route
    const route = window.location.hash.slice(1) || 'home';
    handleRouteChange(route);
    
    // Show main screen as default
    showMainScreen();
}

// Update stats and analytics
function updateStats() {
    // Find or create analytics container
    let analyticsContainer = document.querySelector('.analytics-summary');
    if (!analyticsContainer) {
        analyticsContainer = document.createElement('div');
        analyticsContainer.className = 'analytics-summary';
        
        // Insert before the habits container
        const habitsContainer = document.getElementById('habits-container');
        habitsContainer.parentNode.insertBefore(analyticsContainer, habitsContainer);
    }
    
    // Calculate stats
    const habitCount = Object.keys(habits).length;
    let completedCount = 0;
    let totalProgress = 0;
    let totalTarget = 0;
    let streakSum = 0;
    
    Object.values(habits).forEach(habit => {
        totalProgress += habit.progress;
        totalTarget += habit.target;
        streakSum += habit.streak || 0;
        if (habit.progress >= habit.target) {
            completedCount++;
        }
    });
    
    const completionRate = habitCount > 0 ? Math.round((completedCount / habitCount) * 100) : 0;
    const averageProgress = totalTarget > 0 ? Math.round((totalProgress / totalTarget) * 100) : 0;
    const averageStreak = habitCount > 0 ? Math.round(streakSum / habitCount) : 0;
    
    // Create analytics content
    analyticsContainer.innerHTML = `
        <div class="analytics-header">
            <h3>Habit Stats</h3>
        </div>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${completionRate}%</div>
                <div class="stat-label">Completion Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${averageProgress}%</div>
                <div class="stat-label">Average Progress</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${averageStreak}</div>
                <div class="stat-label">Avg. Streak</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${habitCount}</div>
                <div class="stat-label">Total Habits</div>
            </div>
        </div>
    `;
    
    // Update analytics based on theme
    applyThemeToAnalytics();
}

// Apply theme to analytics
function applyThemeToAnalytics() {
    const isDark = isDarkModeEnabled();
    const analyticsContainer = document.querySelector('.analytics-summary');
    if (analyticsContainer) {
        analyticsContainer.style.backgroundColor = isDark ? '#333' : '#f8f8f8';
        analyticsContainer.style.color = isDark ? '#fff' : '#333';
    }
}

// Function to setup all event listeners
function setupEventListeners() {
    console.log('Setting up event listeners');
    
    // Calendar and Settings icon navigation
    const calendarIcon = document.querySelector('.calendar-icon');
    if (calendarIcon) {
        calendarIcon.onclick = () => {
            showCalendarScreen();
        };
    }
    
    const settingsIcon = document.querySelector('.settings-icon');
    if (settingsIcon) {
        settingsIcon.onclick = () => {
            showSettingsScreen();
        };
    }
    
    // Dark mode toggle in settings
    const darkModeToggle = document.querySelector('.theme-switch input[type="checkbox"]');
    if (darkModeToggle) {
        darkModeToggle.onchange = (e) => {
            const checked = e.target.checked;
            
            // Save the theme preference
            localStorage.setItem('isDarkMode', checked);
            
            // Apply theme consistently
            document.body.setAttribute('data-theme', checked ? 'dark' : 'light');
            
            // Notify all theme listeners
            notifyThemeChange();
        };
    }
    
    // Test notification button in settings
    const testNotificationButton = document.querySelector('.settings-section button.btn-primary');
    if (testNotificationButton) {
        testNotificationButton.onclick = () => {
            showToast('This is a test notification!', '#4CAF50', 1500);
        };
    }
    
    // Back buttons on settings and calendar screens
    const backButton = document.querySelector('.back-button');
    if (backButton) {
        // The onclick event is already defined in the element creation
        // But we'll make sure the event is properly attached
        if (!backButton.onclick) {
            backButton.onclick = () => {
                window.history.back();
            };
        }
    }
    
    // Add habit button (floating action button)
    const addButton = document.querySelector('.add-button');
    if (addButton) {
        addButton.onclick = () => {
            showAddHabitScreen();
        };
    }
}

// Function to show details for a selected calendar day
function showDayDetails(dateString) {
    const habitHistory = loadHabitHistory();
    console.log('Showing details for date:', dateString);
    
    // Create overlay for popup
    const overlay = document.createElement('div');
    overlay.className = 'dialog-overlay';
    
    // Create popup container
    const popup = document.createElement('div');
    popup.className = 'calendar-popup';
    
    // Format date for display
    const [year, month, day] = dateString.split('-').map(Number);
    const displayDate = new Date(year, month - 1, day);
    
    // Popup title
    const title = document.createElement('h3');
    title.className = 'calendar-popup-title';
    title.textContent = displayDate.toLocaleDateString(undefined, {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    
    // Close button
    const closeButton = document.createElement('div');
    closeButton.innerHTML = '&times;';
    closeButton.className = 'popup-close-button';
    
    closeButton.onclick = () => {
        document.body.removeChild(overlay);
    };
    
    // Habits list
    const habitsList = document.createElement('div');
    habitsList.className = 'habit-list';
    
    // Show habits
    let hasAnyData = false;
    
    // Sort habits by name and show all
    const sortedHabits = Object.entries(habits).sort(([,a], [,b]) => a.name.localeCompare(b.name));
    
    sortedHabits.forEach(([habitId, habit]) => {
        // Check if this habit has data for this date
        const status = checkHabitCompletion(habit, dateString, habitHistory);
        if (status) {
            hasAnyData = true;
            
            // Create habit item
            const habitItem = document.createElement('div');
            habitItem.className = 'habit-item';
            
            // Habit name
            const habitName = document.createElement('div');
            habitName.className = 'habit-name';
            habitName.textContent = habit.name;
            
            // Habit status
            const habitStatus = document.createElement('div');
            habitStatus.className = `habit-status ${status}`;
            habitStatus.textContent = status === 'completed' ? '✓ Completed' : '✗ Not Completed';
            
            habitItem.appendChild(habitName);
            habitItem.appendChild(habitStatus);
            habitsList.appendChild(habitItem);
        }
    });
    
    if (!hasAnyData) {
        const noDataMsg = document.createElement('div');
        noDataMsg.className = 'no-data-message';
        noDataMsg.textContent = 'No habits recorded for this date.';
        habitsList.appendChild(noDataMsg);
    }
    
    // Assemble popup
    popup.appendChild(closeButton);
    popup.appendChild(title);
    popup.appendChild(habitsList);
    overlay.appendChild(popup);
    
    // Close popup when clicking overlay
    overlay.onclick = (e) => {
        if (e.target === overlay) {
            document.body.removeChild(overlay);
        }
    };
    
    document.body.appendChild(overlay);
}

// Helper function to check habit completion status
function checkHabitCompletion(habit, dateStr, habitHistory) {
    if (!habit || !dateStr) return null;
    
    // Per-habit history check
    if (habit.history && habit.history[dateStr]) {
        return habit.history[dateStr];
    }
    
    // Global history fallback
    if (habitHistory[dateStr] && habitHistory[dateStr][habit.id]) {
        return habitHistory[dateStr][habit.id];
    }
    
    return null;
}

// When a new habit is added
function saveNewHabit(habitName, target, color, category, reminderTime, reminderEnabled) {
    // ... existing code ...
    
    // Save to localStorage
    saveHabitsToStorage(habits);
    
    // ... existing code ...
}

// Export important functions for global access
export { showCalendarScreen, showSettingsScreen, showMainScreen, showAddHabitScreen };