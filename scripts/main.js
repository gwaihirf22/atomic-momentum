// Default habits to use if none are saved
const defaultHabits = {
    water: { 
        progress: 5, 
        target: 8, 
        name: "Drink Water", 
        color: "#2196F3",
        lastUpdatedDate: new Date().toISOString(),
        resetFrequency: "weekly",
        history: {}, // Store habit history by date
        streak: 0,   // Current streak count
        lastStreakDate: null, // Last date the streak was updated
        reminderTime: null, // Optional time for daily reminder
        reminderEnabled: false // Whether notifications are enabled for this habit
    },
    bible: { 
        progress: 3, 
        target: 7, 
        name: "Read Bible", 
        color: "#009688",
        lastUpdatedDate: new Date().toISOString(),
        resetFrequency: "weekly",
        history: {}, // Store habit history by date
        streak: 0,   // Current streak count
        lastStreakDate: null, // Last date the streak was updated
        reminderTime: null, // Optional time for daily reminder
        reminderEnabled: false // Whether notifications are enabled for this habit
    },
    workout: { 
        progress: 7, 
        target: 7, 
        name: "Workout", 
        color: "#FF9800",
        lastUpdatedDate: new Date().toISOString(),
        resetFrequency: "weekly",
        history: {}, // Store habit history by date
        streak: 0,   // Current streak count
        lastStreakDate: null, // Last date the streak was updated
        reminderTime: null, // Optional time for daily reminder
        reminderEnabled: false // Whether notifications are enabled for this habit
    }
};

// Our in-memory habits
let habits = {};

// Function to format date as YYYY-MM-DD for consistent history keys
function formatDate(date) {
    const d = new Date(date);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Get today's date in YYYY-MM-DD format
function getTodayFormatted() {
    return formatDate(new Date());
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
    const savedHabits = localStorage.getItem('atomic_momentum_habits');
    if (savedHabits) {
        try {
            habits = JSON.parse(savedHabits);
            console.log('Loaded habits from localStorage:', habits);
            
            // Initialize history, streak, and reminder properties for habits that don't have them yet
            Object.keys(habits).forEach(habitId => {
                const habit = habits[habitId];
                if (!habit.history) {
                    habit.history = {};
                }
                if (habit.streak === undefined) {
                    habit.streak = 0;
                }
                if (habit.lastStreakDate === undefined) {
                    habit.lastStreakDate = null;
                }
                // Initialize reminder properties if they don't exist
                if (habit.reminderTime === undefined) {
                    habit.reminderTime = null;
                }
                if (habit.reminderEnabled === undefined) {
                    habit.reminderEnabled = false;
                }
            });
            
            // Check for habits that need to be reset based on their frequency
            checkHabitResets();
        } catch (e) {
            console.error('Error loading habits from localStorage:', e);
            habits = {...defaultHabits};
            saveHabits();
        }
    } else {
        // Use default habits if none are saved
        habits = {...defaultHabits};
        saveHabits();
    }
    
    // Update UI with loaded habits
    renderHabits();
    
    // Ensure theme is applied consistently after load
    applyTheme();
}

// Save habits to localStorage
function saveHabits() {
    try {
        localStorage.setItem('atomic_momentum_habits', JSON.stringify(habits));
        console.log('Saved habits to localStorage');
    } catch (e) {
        console.error('Error saving habits to localStorage:', e);
    }
}

// Load habit history from localStorage
function loadHabitHistory() {
    const savedHistory = localStorage.getItem('atomic_momentum_habit_history');
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
        localStorage.setItem('atomic_momentum_habit_history', JSON.stringify(history));
        console.log('Saved habit history to localStorage');
    } catch (e) {
        console.error('Error saving habit history to localStorage:', e);
    }
}

// Record daily habit status in habitHistory
function recordDailyHabitStatus() {
    const currentDate = formatDate(new Date());
    const habitHistory = loadHabitHistory();
    
    // Create entry for current date if it doesn't exist
    if (!habitHistory[currentDate]) {
        habitHistory[currentDate] = {};
    }
    
    // Record status for each habit
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        const isCompleted = habit.progress >= habit.target;
        
        // Store as "completed" or "not_completed"
        habitHistory[currentDate][habitId] = isCompleted ? "completed" : "not_completed";
    });
    
    // Save the updated history
    saveHabitHistory(habitHistory);
    console.log('Recorded habit status for', currentDate);
}

// Render all habits in the UI
function renderHabits() {
    const container = document.getElementById('habits-container');
    container.innerHTML = ''; // Clear existing habits
    container.style.padding = '0 10px'; // Ensure padding applies to dynamically generated content
    
    // Get current theme state
    const isDarkMode = isDarkModeEnabled();
    
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        const habitElement = createHabitElement(habitId, habit);
        
        // Apply theme-specific styling to the card
        if (isDarkMode) {
            habitElement.style.backgroundColor = '#1e1e1e';
            // Find progress bar and set its background
            const progressBar = habitElement.querySelector('.progress-bar');
            if (progressBar) {
                progressBar.style.backgroundColor = '#333';
            }
        } else {
            habitElement.style.backgroundColor = '#fff';
            // Find progress bar and set its background
            const progressBar = habitElement.querySelector('.progress-bar');
            if (progressBar) {
                progressBar.style.backgroundColor = '#e0e0e0';
            }
        }
        
        container.appendChild(habitElement);
    });
}

// Create a habit card element
function createHabitElement(habitId, habit) {
    const card = document.createElement('div');
    card.className = 'habit-card';
    // Add subtle shadow and increased spacing
    card.style.boxShadow = isDarkModeEnabled() ? '0 2px 8px rgba(255,255,255,0.05)' : '0 2px 8px rgba(0,0,0,0.1)';
    card.style.marginBottom = '15px'; // Increase vertical spacing between cards
    card.style.padding = '15px'; // Increase internal padding
    card.style.borderRadius = '10px'; // More rounded corners for a modern look
    
    const title = document.createElement('div');
    title.className = 'habit-title';
    title.style.display = 'flex';
    title.style.justifyContent = 'space-between';
    title.style.alignItems = 'center';
    
    const titleLeft = document.createElement('div');
    
    const heading = document.createElement('div');
    heading.style.display = 'flex';
    heading.style.alignItems = 'center';
    heading.style.marginBottom = '6px';
    
    // Add habit icon if one is specified
    if (habit.icon) {
        const iconWrapper = document.createElement('div');
        iconWrapper.className = 'habit-icon';
        iconWrapper.innerHTML = `<svg><use href="#icon-${habit.icon}"></use></svg>`;
        iconWrapper.querySelector('svg').style.stroke = habit.color;
        heading.appendChild(iconWrapper);
    }
    
    const habitName = document.createElement('h2');
    habitName.textContent = habit.name;
    habitName.style.margin = '0';
    habitName.style.fontSize = '18px';
    habitName.style.fontWeight = '600';
    habitName.style.color = habit.color;
    heading.appendChild(habitName);
    
    // Add streak badge if there's a streak
    if (habit.streak && habit.streak > 0) {
        const streakBadge = document.createElement('div');
        streakBadge.className = 'streak-badge';
        streakBadge.textContent = `🔥 ${habit.streak}`;
        streakBadge.title = `${habit.streak} day streak!`;
        heading.appendChild(streakBadge);
        
        // Add animation for milestone streaks
        if (habit.streak === 1 || habit.streak === 7 || habit.streak === 14 || 
            habit.streak === 21 || habit.streak === 30 || habit.streak === 60 || 
            habit.streak === 90 || habit.streak === 100) {
            streakBadge.style.animation = 'pulse 2s infinite';
            
            // Create keyframes for pulse animation if they don't exist yet
            if (!document.getElementById('streak-pulse-animation')) {
                const styleSheet = document.createElement('style');
                styleSheet.id = 'streak-pulse-animation';
                styleSheet.textContent = `
                    @keyframes pulse {
                        0% { transform: scale(1); }
                        50% { transform: scale(1.05); }
                        100% { transform: scale(1); }
                    }
                `;
                document.head.appendChild(styleSheet);
            }
        }
    }
    
    const progress = document.createElement('span');
    progress.textContent = `${habit.progress}/${habit.target}`;
    progress.style.color = habit.color;
    
    titleLeft.appendChild(heading);
    titleLeft.appendChild(progress);
    
    // Create button container for edit and delete
    const btnContainer = document.createElement('div');
    btnContainer.style.display = 'flex';
    btnContainer.style.gap = '5px';
    
    // Add edit button (pencil icon)
    const editBtn = document.createElement('button');
    editBtn.innerHTML = '✏️'; // Pencil emoji
    editBtn.style.background = 'transparent';
    editBtn.style.border = 'none';
    editBtn.style.fontSize = '20px';
    editBtn.style.cursor = 'pointer';
    editBtn.style.padding = '0 5px';
    editBtn.title = 'Edit habit';
    editBtn.addEventListener('click', () => showEditHabitScreen(habitId, habit));
    
    // Add delete button (trash icon)
    const deleteBtn = document.createElement('button');
    deleteBtn.innerHTML = '🗑️'; // Trash emoji
    deleteBtn.style.background = 'transparent';
    deleteBtn.style.border = 'none';
    deleteBtn.style.fontSize = '20px';
    deleteBtn.style.cursor = 'pointer';
    deleteBtn.style.padding = '0 5px';
    deleteBtn.title = 'Delete habit';
    deleteBtn.addEventListener('click', () => {
        if (confirm(`Are you sure you want to delete "${habit.name}"?`)) {
            delete habits[habitId];
            saveHabits();
            renderHabits();
        }
    });
    
    btnContainer.appendChild(editBtn);
    btnContainer.appendChild(deleteBtn);
    
    title.appendChild(titleLeft);
    title.appendChild(btnContainer);
    
    card.appendChild(title);
    
    const progressBar = document.createElement('div');
    progressBar.className = 'progress-bar';
    
    const progressFill = document.createElement('div');
    progressFill.className = 'progress-fill';
    const progressPercentage = (habit.progress / habit.target) * 100;
    progressFill.style.width = `${Math.min(progressPercentage, 100)}%`;
    progressFill.style.backgroundColor = habit.color;
    
    progressBar.appendChild(progressFill);
    
    card.appendChild(progressBar);
    
    const actions = document.createElement('div');
    actions.className = 'actions';
    
    const minusBtn = document.createElement('button');
    minusBtn.textContent = '-';
    minusBtn.addEventListener('click', () => updateProgress(habitId, -1));
    minusBtn.disabled = habit.progress <= 0;
    
    const plusBtn = document.createElement('button');
    plusBtn.textContent = '+';
    plusBtn.addEventListener('click', () => updateProgress(habitId, 1));
    plusBtn.disabled = habit.progress >= habit.target;
    
    actions.appendChild(minusBtn);
    actions.appendChild(plusBtn);
    
    card.appendChild(actions);
    
    return card;
}

// Function to show success/error notifications to the user
function showToast(message, bgColor = '#4CAF50', duration = 3000) {
    const toast = document.createElement('div');
    toast.textContent = message;
    toast.style.position = 'fixed';
    toast.style.bottom = '20px';
    toast.style.left = '50%';
    toast.style.transform = 'translateX(-50%)';
    toast.style.backgroundColor = bgColor;
    toast.style.color = 'white';
    toast.style.padding = '10px 20px';
    toast.style.borderRadius = '4px';
    toast.style.zIndex = '1000';
    toast.style.boxShadow = '0 2px 10px rgba(0,0,0,0.3)';
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.3s';
    
    document.body.appendChild(toast);
    
    // Animate toast
    setTimeout(() => {
        toast.style.opacity = '1';
    }, 10);
    
    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => {
            document.body.removeChild(toast);
        }, 300);
    }, duration);
}

// Add initialization code to run on page load
document.addEventListener('DOMContentLoaded', function() {
    // Apply theme from localStorage
    applyTheme();
    
    // Load habits from localStorage
    loadHabits();
    
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
        document.body.dataset.themeMode = currentIsDarkMode ? 'dark' : 'light'; // Additional backup
        
        const oldProgress = habit.progress;
        habit.progress = newProgress;
        habit.lastUpdatedDate = new Date().toISOString(); // Update the last modified date
        
        // Record habit progress in history
        const today = getTodayFormatted();
        
        // Initialize history object if needed
        if (!habit.history) {
            habit.history = {};
        }
        
        let isCompleted = false;
        
        // Record current date's completion status
        if (newProgress === habit.target) {
            // Habit completed for the day
            isCompleted = true;
            habit.history[today] = {
                completed: true,
                progress: newProgress,
                target: habit.target
            };
        } else if (oldProgress === habit.target && newProgress < habit.target) {
            // Habit was previously completed today but now uncompleted
            isCompleted = false;
            habit.history[today] = {
                completed: false,
                progress: newProgress,
                target: habit.target
            };
        } else {
            // Partial progress
            isCompleted = false;
            habit.history[today] = {
                completed: false,
                progress: newProgress,
                target: habit.target
            };
        }
        
        // Update streak information
        updateStreak(habit, today, isCompleted);
        
        // Save the updated state
        saveHabits();
        
        // Re-render all habits
        renderHabits();
        
        // Ensure theme is consistently applied after update
        if (currentIsDarkMode !== isDarkModeEnabled()) {
            console.log('Theme state changed unexpectedly, fixing...');
            localStorage.setItem('isDarkMode', String(currentIsDarkMode));
        } else if (document.body.dataset.themeMode === 'dark' && !isDarkModeEnabled()) {
            console.log('Theme state changed based on dataset check, fixing...');
            localStorage.setItem('isDarkMode', 'true');
        } else if (document.body.dataset.themeMode === 'light' && isDarkModeEnabled()) {
            console.log('Theme state changed based on dataset check, fixing...');
            localStorage.setItem('isDarkMode', 'false');
        }
        
        // Apply theme consistently
        applyTheme();
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
        saveHabits();
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
function showAddHabitScreen() {
    // Save current screen content
    const mainContent = document.body.innerHTML;
    
    // Get current theme
    const isDarkMode = isDarkModeEnabled();
    
    // Create full-screen form that simulates a navigation to a new screen
    document.body.innerHTML = '';
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.style.fontFamily = 'Arial, sans-serif';
    appScreen.style.maxWidth = '500px';
    appScreen.style.margin = '0 auto';
    appScreen.style.padding = '0';
    appScreen.style.backgroundColor = isDarkMode ? '#121212' : '#f5f5f5';
    appScreen.style.color = isDarkMode ? '#ffffff' : '#000000';
    appScreen.style.height = '100vh';
    appScreen.style.display = 'flex';
    appScreen.style.flexDirection = 'column';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.style.backgroundColor = '#673ab7';
    appBar.style.color = 'white';
    appBar.style.padding = '16px';
    appBar.style.display = 'flex';
    appBar.style.alignItems = 'center';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.style.marginRight = '16px';
    backButton.style.fontSize = '24px';
    backButton.style.cursor = 'pointer';
    backButton.onclick = () => {
        // Return to the main screen
        document.body.innerHTML = mainContent;
        
        // Re-initialize event listeners and state
        document.addEventListener('DOMContentLoaded', loadHabits);
        loadHabits();
        
        // Ensure theme is applied correctly when returning to main screen
        applyTheme();
    };
    
    // Title
    const title = document.createElement('h1');
    title.textContent = 'Add New Habit';
    title.style.margin = '0';
    title.style.fontSize = '20px';
    
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Create form container (scrollable)
    const formContainer = document.createElement('div');
    formContainer.style.flex = '1';
    formContainer.style.overflowY = 'auto';
    formContainer.style.padding = '20px';
    
    // Create form content
    const form = document.createElement('div');
    form.style.backgroundColor = isDarkMode ? '#1e1e1e' : 'white';
    form.style.padding = '20px';
    form.style.borderRadius = '8px';
    form.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    
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
    const icons = [
        { id: 'none', label: 'None', path: '' }, // Empty option
        { id: 'droplet', label: 'Water/Hydration', path: 'M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z' },
        { id: 'book-open', label: 'Reading', path: 'M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z' },
        { id: 'dumbbell', label: 'Exercise', path: 'M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5z' }
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
    nameInput.style.width = '100%';
    nameInput.style.padding = '16px';
    nameInput.style.fontSize = '16px';
    nameInput.style.marginBottom = '16px'; 
    nameInput.style.borderRadius = '8px';
    nameInput.style.border = '1px solid #ccc';
    nameInput.style.boxSizing = 'border-box';
    
    const targetInput = document.createElement('input');
    targetInput.type = 'number';
    targetInput.placeholder = 'Goal Number (weekly)';
    targetInput.min = '1';
    targetInput.max = '100';
    targetInput.style.width = '100%';
    targetInput.style.padding = '16px';
    targetInput.style.fontSize = '16px';
    targetInput.style.marginBottom = '16px';
    targetInput.style.borderRadius = '8px';
    targetInput.style.border = '1px solid #ccc';
    targetInput.style.boxSizing = 'border-box';
    targetInput.value = '7'; // Default weekly goal
    
    // Color picker
    const colorLabel = document.createElement('div');
    colorLabel.textContent = 'Choose a Color';
    colorLabel.style.fontSize = '16px';
    colorLabel.style.fontWeight = 'bold';
    colorLabel.style.marginBottom = '10px';
    
    const colorPicker = document.createElement('input');
    colorPicker.type = 'color';
    colorPicker.value = '#009688'; // Default color
    colorPicker.style.width = '100%';
    colorPicker.style.height = '40px';
    colorPicker.style.marginBottom = '16px';
    colorPicker.style.borderRadius = '8px';
    colorPicker.style.border = '1px solid #ccc';
    colorPicker.style.boxSizing = 'border-box';
    
    // Save button
    const saveButtonContainer = document.createElement('div');
    saveButtonContainer.style.padding = '20px';
    saveButtonContainer.style.display = 'flex';
    saveButtonContainer.style.justifyContent = 'center';
    
    const createButton = document.createElement('button');
    createButton.textContent = 'Create Habit';
    createButton.style.backgroundColor = '#673ab7';
    createButton.style.color = 'white';
    createButton.style.padding = '16px 32px';
    createButton.style.borderRadius = '8px';
    createButton.style.border = 'none';
    createButton.style.fontSize = '16px';
    createButton.style.cursor = 'pointer';
    
    // Create habit logic
    createButton.onclick = () => {
        // Validate form
        if (nameInput.value && targetInput.value && parseInt(targetInput.value) > 0) {
            // Generate unique ID for the habit
            const habitId = 'habit_' + new Date().getTime();
            
            // Create the habit object
            habits[habitId] = {
                name: nameInput.value,
                progress: 0,
                target: parseInt(targetInput.value),
                color: colorPicker.value,
                icon: selectedIconId !== 'none' ? selectedIconId : '',
                lastUpdatedDate: new Date().toISOString(),
                resetFrequency: "weekly",
                history: {},
                streak: 0,
                lastStreakDate: null,
                reminderTime: null,
                reminderEnabled: false
            };
            
            // Save to localStorage
            saveHabits();
            
            // Return to the main screen
            document.body.innerHTML = mainContent;
            
            // Re-initialize event listeners and state
            document.addEventListener('DOMContentLoaded', loadHabits);
            loadHabits();
            
            // Ensure theme is applied correctly when returning to main screen
            applyTheme();
        } else {
            alert('Please fill out all fields');
        }
    };
    
    // Assemble the form
    form.appendChild(heading);
    form.appendChild(iconLabel);
    form.appendChild(iconContainer);
    form.appendChild(nameInput);
    form.appendChild(targetInput);
    form.appendChild(colorLabel);
    form.appendChild(colorPicker);
    
    // Assemble the UI
    formContainer.appendChild(form);
    saveButtonContainer.appendChild(createButton);
    
    appScreen.appendChild(appBar);
    appScreen.appendChild(formContainer);
    appScreen.appendChild(saveButtonContainer);
    
    document.body.appendChild(appScreen);
    
    // Focus the first input for better UX
    nameInput.focus();
}

// Show Edit Habit Screen
function showEditHabitScreen(habitId, habit) {
    // Save current screen content
    const mainContent = document.body.innerHTML;
    
    // Get current theme
    const isDarkMode = isDarkModeEnabled();
    
    // Create full-screen form that simulates a navigation to a new screen
    document.body.innerHTML = '';
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.style.fontFamily = 'Arial, sans-serif';
    appScreen.style.maxWidth = '500px';
    appScreen.style.margin = '0 auto';
    appScreen.style.padding = '0';
    appScreen.style.backgroundColor = isDarkMode ? '#121212' : '#f5f5f5';
    appScreen.style.color = isDarkMode ? '#ffffff' : '#000000';
    appScreen.style.height = '100vh';
    appScreen.style.display = 'flex';
    appScreen.style.flexDirection = 'column';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.style.backgroundColor = '#673ab7';
    appBar.style.color = 'white';
    appBar.style.padding = '16px';
    appBar.style.display = 'flex';
    appBar.style.alignItems = 'center';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.style.marginRight = '16px';
    backButton.style.fontSize = '24px';
    backButton.style.cursor = 'pointer';
    backButton.onclick = () => {
        // Return to the main screen
        document.body.innerHTML = mainContent;
        
        // Re-initialize event listeners and state
        document.addEventListener('DOMContentLoaded', loadHabits);
        loadHabits();
        
        // Ensure theme is applied correctly when returning to main screen
        applyTheme();
    };
    
    // Title
    const title = document.createElement('h1');
    title.textContent = 'Edit Habit';
    title.style.margin = '0';
    title.style.fontSize = '20px';
    
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Create form container (scrollable)
    const formContainer = document.createElement('div');
    formContainer.style.flex = '1';
    formContainer.style.overflowY = 'auto';
    formContainer.style.padding = '20px';
    
    // Create form content
    const form = document.createElement('div');
    form.style.backgroundColor = isDarkMode ? '#1e1e1e' : 'white';
    form.style.padding = '20px';
    form.style.borderRadius = '8px';
    form.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    
    const heading = document.createElement('h2');
    heading.textContent = 'Edit Habit';
    heading.style.textAlign = 'center';
    heading.style.marginBottom = '20px';
    
    // Icon selector
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
    const icons = [
        { id: 'none', label: 'None', path: '' }, // Empty option
        { id: 'droplet', label: 'Water/Hydration', path: 'M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z' },
        { id: 'book-open', label: 'Reading', path: 'M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z' },
        { id: 'dumbbell', label: 'Exercise', path: 'M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5z' }
    ];
    
    let selectedIconId = habit.icon || 'none';
    
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
        iconBtn.style.backgroundColor = icon.id === selectedIconId ? '#e0e0e0' : (isDarkMode ? '#333' : '#fff');
        iconBtn.style.transform = icon.id === selectedIconId ? 'scale(1.1)' : 'scale(1.0)';
        iconBtn.style.boxShadow = icon.id === selectedIconId ? '0 2px 5px rgba(0,0,0,0.2)' : 'none';
        
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
    nameInput.value = habit.name;
    nameInput.style.width = '100%';
    nameInput.style.padding = '16px';
    nameInput.style.fontSize = '16px';
    nameInput.style.marginBottom = '16px'; 
    nameInput.style.borderRadius = '8px';
    nameInput.style.border = '1px solid #ccc';
    nameInput.style.boxSizing = 'border-box';
    
    const targetInput = document.createElement('input');
    targetInput.type = 'number';
    targetInput.placeholder = 'Goal Number (weekly)';
    targetInput.min = '1';
    targetInput.max = '100';
    targetInput.value = habit.target;
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
    
    const colorPicker = document.createElement('input');
    colorPicker.type = 'color';
    colorPicker.value = habit.color;
    colorPicker.style.width = '100%';
    colorPicker.style.height = '40px';
    colorPicker.style.marginBottom = '16px';
    colorPicker.style.borderRadius = '8px';
    colorPicker.style.border = '1px solid #ccc';
    colorPicker.style.boxSizing = 'border-box';
    
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
        // Just go back without saving
        document.body.innerHTML = mainContent;
        
        // Re-initialize event listeners and state
        document.addEventListener('DOMContentLoaded', loadHabits);
        loadHabits();
        
        // Ensure theme is applied correctly when returning to main screen
        applyTheme();
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
            // Update the habit object
            habits[habitId].name = nameInput.value;
            habits[habitId].target = parseInt(targetInput.value);
            habits[habitId].color = colorPicker.value;
            habits[habitId].icon = selectedIconId !== 'none' ? selectedIconId : '';
            
            // Save to localStorage
            saveHabits();
            
            // Return to the main screen
            document.body.innerHTML = mainContent;
            
            // Re-initialize event listeners and state
            document.addEventListener('DOMContentLoaded', loadHabits);
            loadHabits();
            
            // Ensure theme is applied correctly when returning to main screen
            applyTheme();
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
    form.appendChild(targetInput);
    form.appendChild(colorLabel);
    form.appendChild(colorPicker);
    
    // Assemble the UI
    formContainer.appendChild(form);
    
    appScreen.appendChild(appBar);
    appScreen.appendChild(formContainer);
    appScreen.appendChild(saveButtonContainer);
    
    document.body.appendChild(appScreen);
    
    // Focus the first input for better UX
    nameInput.focus();
}

// Settings screen with dark mode toggle
function showSettingsScreen() {
    // Save current screen content
    const mainContent = document.body.innerHTML;
    
    // Load current theme setting
    const isDarkMode = isDarkModeEnabled();
    
    // Create full-screen settings page
    document.body.innerHTML = '';
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.style.fontFamily = 'Arial, sans-serif';
    appScreen.style.maxWidth = '500px';
    appScreen.style.margin = '0 auto';
    appScreen.style.padding = '0';
    appScreen.style.backgroundColor = isDarkMode ? '#121212' : '#f5f5f5';
    appScreen.style.color = isDarkMode ? '#ffffff' : '#000000';
    appScreen.style.height = '100vh';
    appScreen.style.display = 'flex';
    appScreen.style.flexDirection = 'column';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.style.backgroundColor = '#673ab7';
    appBar.style.color = 'white';
    appBar.style.padding = '16px';
    appBar.style.display = 'flex';
    appBar.style.alignItems = 'center';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.style.marginRight = '16px';
    backButton.style.fontSize = '24px';
    backButton.style.cursor = 'pointer';
    backButton.onclick = () => {
        // Return to the main screen
        document.body.innerHTML = mainContent;
        
        // Re-initialize event listeners and state
        document.addEventListener('DOMContentLoaded', loadHabits);
        loadHabits();
        
        // Apply theme if it was changed
        applyTheme();
    };
    
    // Title
    const title = document.createElement('h1');
    title.textContent = 'Settings';
    title.style.margin = '0';
    title.style.fontSize = '20px';
    
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Create settings container
    const settingsContainer = document.createElement('div');
    settingsContainer.style.flex = '1';
    settingsContainer.style.overflowY = 'auto';
    settingsContainer.style.padding = '20px';
    
    // Settings section: Appearance
    const appearanceSection = document.createElement('div');
    appearanceSection.style.backgroundColor = isDarkMode ? '#1e1e1e' : 'white';
    appearanceSection.style.padding = '16px';
    appearanceSection.style.borderRadius = '8px';
    appearanceSection.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    appearanceSection.style.marginBottom = '16px';
    
    const appearanceTitle = document.createElement('h3');
    appearanceTitle.textContent = 'Appearance';
    appearanceTitle.style.margin = '0 0 16px 0';
    
    // Dark Mode Switch
    const darkModeRow = document.createElement('div');
    darkModeRow.style.display = 'flex';
    darkModeRow.style.alignItems = 'center';
    darkModeRow.style.justifyContent = 'space-between';
    darkModeRow.style.padding = '8px 0';
    
    const darkModeLabel = document.createElement('div');
    
    const darkModeLabelTitle = document.createElement('div');
    darkModeLabelTitle.textContent = 'Dark Mode';
    darkModeLabelTitle.style.fontWeight = 'bold';
    
    const darkModeLabelDesc = document.createElement('div');
    darkModeLabelDesc.textContent = 'Switch between light and dark themes';
    darkModeLabelDesc.style.fontSize = '14px';
    darkModeLabelDesc.style.color = '#757575';
    darkModeLabelDesc.style.marginTop = '4px';
    
    darkModeLabel.appendChild(darkModeLabelTitle);
    darkModeLabel.appendChild(darkModeLabelDesc);
    
    // Switch component
    const switchContainer = document.createElement('label');
    switchContainer.style.position = 'relative';
    switchContainer.style.display = 'inline-block';
    switchContainer.style.width = '60px';
    switchContainer.style.height = '34px';
    
    const switchInput = document.createElement('input');
    switchInput.type = 'checkbox';
    switchInput.checked = isDarkMode;
    switchInput.style.opacity = '0';
    switchInput.style.width = '0';
    switchInput.style.height = '0';
    
    const switchSlider = document.createElement('span');
    switchSlider.style.position = 'absolute';
    switchSlider.style.cursor = 'pointer';
    switchSlider.style.top = '0';
    switchSlider.style.left = '0';
    switchSlider.style.right = '0';
    switchSlider.style.bottom = '0';
    switchSlider.style.backgroundColor = isDarkMode ? '#673ab7' : '#ccc';
    switchSlider.style.borderRadius = '34px';
    switchSlider.style.transition = '.4s';
    
    // Slider button
    const sliderButton = document.createElement('span');
    sliderButton.style.position = 'absolute';
    sliderButton.style.content = '""';
    sliderButton.style.height = '26px';
    sliderButton.style.width = '26px';
    sliderButton.style.left = isDarkMode ? '30px' : '4px';
    sliderButton.style.bottom = '4px';
    sliderButton.style.backgroundColor = 'white';
    sliderButton.style.borderRadius = '50%';
    sliderButton.style.transition = '.4s';
    
    switchSlider.appendChild(sliderButton);
    switchContainer.appendChild(switchInput);
    switchContainer.appendChild(switchSlider);
    
    // Toggle dark mode
    switchInput.onchange = (e) => {
        const checked = e.target.checked;
        switchSlider.style.backgroundColor = checked ? '#673ab7' : '#ccc';
        sliderButton.style.left = checked ? '30px' : '4px';
        
        // Save the theme preference
        localStorage.setItem('isDarkMode', checked);
        
        // Apply theme immediately to settings screen
        appScreen.style.backgroundColor = checked ? '#121212' : '#f5f5f5';
        appScreen.style.color = checked ? '#fff' : '#000';
        appearanceSection.style.backgroundColor = checked ? '#1e1e1e' : '#ffffff';
        darkModeLabelDesc.style.color = checked ? '#aaa' : '#757575';
        notificationsSection.style.backgroundColor = checked ? '#1e1e1e' : '#ffffff';
        notificationsTitle.style.color = checked ? '#fff' : '#000';
        
        // Notify all theme listeners
        notifyThemeChange();
    };
    
    darkModeRow.appendChild(darkModeLabel);
    darkModeRow.appendChild(switchContainer);
    
    appearanceSection.appendChild(appearanceTitle);
    appearanceSection.appendChild(darkModeRow);
    
    // Notifications Section
    const notificationsSection = document.createElement('div');
    notificationsSection.style.backgroundColor = isDarkMode ? '#1e1e1e' : 'white';
    notificationsSection.style.padding = '16px';
    notificationsSection.style.borderRadius = '8px';
    notificationsSection.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    notificationsSection.style.marginBottom = '16px';
    notificationsSection.style.color = isDarkMode ? '#fff' : '#000';
    
    const notificationsTitle = document.createElement('h3');
    notificationsTitle.textContent = 'Notifications';
    notificationsTitle.style.margin = '0 0 16px 0';
    
    notificationsSection.appendChild(notificationsTitle);
    
    // Add sections to container
    settingsContainer.appendChild(appearanceSection);
    settingsContainer.appendChild(notificationsSection);
    
    // Add button to test notifications
    const testNotifButton = document.createElement('button');
    testNotifButton.textContent = 'Test Notification';
    testNotifButton.style.backgroundColor = '#673ab7';
    testNotifButton.style.color = 'white';
    testNotifButton.style.border = 'none';
    testNotifButton.style.padding = '10px 15px';
    testNotifButton.style.borderRadius = '4px';
    testNotifButton.style.margin = '10px 0';
    testNotifButton.style.cursor = 'pointer';
    testNotifButton.onclick = () => {
        // Show a test notification
        showToast('Test notification shown!');
    };
    
    notificationsSection.appendChild(testNotifButton);
    
    // Assemble the screen
    appScreen.appendChild(appBar);
    appScreen.appendChild(settingsContainer);
    
    document.body.appendChild(appScreen);
}

// Show Calendar Screen
function showCalendarScreen() {
    // Save current screen content
    const mainContent = document.body.innerHTML;
    
    // Get current theme
    const isDarkMode = isDarkModeEnabled();
    
    // Create full-screen view that simulates a navigation to a new screen
    document.body.innerHTML = '';
    
    // Create app elements
    const appScreen = document.createElement('div');
    appScreen.style.fontFamily = 'Arial, sans-serif';
    appScreen.style.maxWidth = '500px';
    appScreen.style.margin = '0 auto';
    appScreen.style.padding = '0';
    appScreen.style.backgroundColor = isDarkMode ? '#121212' : '#f5f5f5';
    appScreen.style.color = isDarkMode ? '#ffffff' : '#000000';
    appScreen.style.height = '100vh';
    appScreen.style.display = 'flex';
    appScreen.style.flexDirection = 'column';
    
    // Create AppBar
    const appBar = document.createElement('div');
    appBar.style.backgroundColor = '#673ab7';
    appBar.style.color = 'white';
    appBar.style.padding = '16px';
    appBar.style.display = 'flex';
    appBar.style.alignItems = 'center';
    
    // Back button
    const backButton = document.createElement('div');
    backButton.innerHTML = '&larr;';
    backButton.style.marginRight = '16px';
    backButton.style.fontSize = '24px';
    backButton.style.cursor = 'pointer';
    backButton.onclick = () => {
        // Return to the main screen
        document.body.innerHTML = mainContent;
        
        // Re-initialize event listeners and state
        document.addEventListener('DOMContentLoaded', loadHabits);
        loadHabits();
        
        // Ensure theme is applied correctly when returning to main screen
        applyTheme();
    };
    
    // Title
    const title = document.createElement('h1');
    title.textContent = 'Habit Calendar';
    title.style.margin = '0';
    title.style.fontSize = '20px';
    
    appBar.appendChild(backButton);
    appBar.appendChild(title);
    
    // Create calendar container (scrollable)
    const calendarContainer = document.createElement('div');
    calendarContainer.style.flex = '1';
    calendarContainer.style.overflowY = 'auto';
    calendarContainer.style.padding = '20px';
    
    // Create calendar content
    const calendarContent = document.createElement('div');
    calendarContent.style.backgroundColor = isDarkMode ? '#1e1e1e' : 'white';
    calendarContent.style.padding = '20px';
    calendarContent.style.borderRadius = '8px';
    calendarContent.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    
    const calendarHeading = document.createElement('h2');
    calendarHeading.textContent = 'Habit History';
    calendarHeading.style.textAlign = 'center';
    calendarHeading.style.marginBottom = '20px';
    
    // Global habit filter
    const filterContainer = document.createElement('div');
    filterContainer.style.marginBottom = '20px';
    filterContainer.style.display = 'flex';
    filterContainer.style.flexDirection = 'column';
    filterContainer.style.gap = '10px';
    
    const filterLabel = document.createElement('div');
    filterLabel.textContent = 'Filter Calendar By:';
    filterLabel.style.fontWeight = 'bold';
    filterLabel.style.marginBottom = '5px';
    
    const filterButtonsContainer = document.createElement('div');
    filterButtonsContainer.style.display = 'flex';
    filterButtonsContainer.style.flexWrap = 'wrap';
    filterButtonsContainer.style.gap = '8px';
    
    // Add "All Habits" button
    const allHabitsButton = document.createElement('button');
    allHabitsButton.textContent = 'All Habits';
    allHabitsButton.style.backgroundColor = window.calendarCurrentFilterHabit === null ? '#673ab7' : (isDarkMode ? '#333' : '#f0f0f0');
    allHabitsButton.style.color = window.calendarCurrentFilterHabit === null ? 'white' : (isDarkMode ? '#ddd' : '#333');
    allHabitsButton.style.border = 'none';
    allHabitsButton.style.borderRadius = '4px';
    allHabitsButton.style.padding = '8px 12px';
    allHabitsButton.style.cursor = 'pointer';
    
    allHabitsButton.onclick = () => {
        window.calendarCurrentFilterHabit = null;
        
        // Update button styles
        filterButtonsContainer.querySelectorAll('button').forEach(btn => {
            btn.style.backgroundColor = isDarkMode ? '#333' : '#f0f0f0';
            btn.style.color = isDarkMode ? '#ddd' : '#333';
        });
        allHabitsButton.style.backgroundColor = '#673ab7';
        allHabitsButton.style.color = 'white';
        
        // Redraw calendar with new filter
        renderCalendarDays();
    };
    
    filterButtonsContainer.appendChild(allHabitsButton);
    
    // Add a button for each habit
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        
        const habitButton = document.createElement('button');
        habitButton.textContent = habit.name;
        habitButton.style.backgroundColor = window.calendarCurrentFilterHabit === habitId ? habit.color : (isDarkMode ? '#333' : '#f0f0f0');
        habitButton.style.color = window.calendarCurrentFilterHabit === habitId ? 'white' : (isDarkMode ? '#ddd' : '#333');
        habitButton.style.border = 'none';
        habitButton.style.borderRadius = '4px';
        habitButton.style.padding = '8px 12px';
        habitButton.style.cursor = 'pointer';
        
        habitButton.onclick = () => {
            window.calendarCurrentFilterHabit = habitId;
            
            // Update button styles
            filterButtonsContainer.querySelectorAll('button').forEach(btn => {
                btn.style.backgroundColor = isDarkMode ? '#333' : '#f0f0f0';
                btn.style.color = isDarkMode ? '#ddd' : '#333';
            });
            habitButton.style.backgroundColor = habit.color;
            habitButton.style.color = 'white';
            
            // Redraw calendar with new filter
            renderCalendarDays();
        };
        
        filterButtonsContainer.appendChild(habitButton);
    });
    
    filterContainer.appendChild(filterLabel);
    filterContainer.appendChild(filterButtonsContainer);
    
    // Create month selector for calendar
    const monthSelector = document.createElement('div');
    monthSelector.style.display = 'flex';
    monthSelector.style.justifyContent = 'space-between';
    monthSelector.style.alignItems = 'center';
    monthSelector.style.marginBottom = '20px';
    
    // Previous month button
    const prevButton = document.createElement('button');
    prevButton.innerHTML = '&larr;';
    prevButton.style.backgroundColor = '#673ab7';
    prevButton.style.color = 'white';
    prevButton.style.border = 'none';
    prevButton.style.borderRadius = '4px';
    prevButton.style.padding = '5px 15px';
    prevButton.style.cursor = 'pointer';
    
    // Current month and year display
    const currentMonthDisplay = document.createElement('div');
    const currentDate = new Date();
    currentMonthDisplay.textContent = `${currentDate.toLocaleString('default', { month: 'long' })} ${currentDate.getFullYear()}`;
    currentMonthDisplay.style.fontSize = '18px';
    currentMonthDisplay.style.fontWeight = 'bold';
    
    // Next month button
    const nextButton = document.createElement('button');
    nextButton.innerHTML = '&rarr;';
    nextButton.style.backgroundColor = '#673ab7';
    nextButton.style.color = 'white';
    nextButton.style.border = 'none';
    nextButton.style.borderRadius = '4px';
    nextButton.style.padding = '5px 15px';
    nextButton.style.cursor = 'pointer';
    
    // Add buttons to month selector
    monthSelector.appendChild(prevButton);
    monthSelector.appendChild(currentMonthDisplay);
    monthSelector.appendChild(nextButton);
    
    // Calendar grid
    const calendarGrid = document.createElement('div');
    calendarGrid.style.display = 'grid';
    calendarGrid.style.gridTemplateColumns = 'repeat(7, 1fr)';
    calendarGrid.style.gap = '5px';
    
    // Add day headers (Sun, Mon, Tue, etc.)
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    days.forEach(day => {
        const dayHeader = document.createElement('div');
        dayHeader.textContent = day;
        dayHeader.style.textAlign = 'center';
        dayHeader.style.fontWeight = 'bold';
        dayHeader.style.padding = '5px';
        calendarGrid.appendChild(dayHeader);
    });
    
    // Current month and year for calendar navigation
    let currentViewMonth = currentDate.getMonth();
    let currentViewYear = currentDate.getFullYear();
    
    // Function to render calendar days, referencing the function from calendar.js
    function renderCalendarDays() {
        // Call the renderCalendarDays function from calendar.js
        window.renderCalendarDays(calendarGrid, currentMonthDisplay, currentViewMonth, currentViewYear, habits);
    }
    
    // Initialize calendar
    renderCalendarDays();
    
    // Month navigation handlers
    prevButton.onclick = () => {
        currentViewMonth--;
        if (currentViewMonth < 0) {
            currentViewMonth = 11;
            currentViewYear--;
        }
        renderCalendarDays();
    };
    
    nextButton.onclick = () => {
        currentViewMonth++;
        if (currentViewMonth > 11) {
            currentViewMonth = 0;
            currentViewYear++;
        }
        renderCalendarDays();
    };
    
    // Assemble the calendar components
    calendarContent.appendChild(calendarHeading);
    calendarContent.appendChild(filterContainer);  // Add filter UI
    calendarContent.appendChild(monthSelector);
    calendarContent.appendChild(calendarGrid);
    calendarContainer.appendChild(calendarContent);
    
    // Assemble the screen
    appScreen.appendChild(appBar);
    appScreen.appendChild(calendarContainer);
    
    document.body.appendChild(appScreen);
}

// Function to apply the current theme to the app
function applyTheme() {
    const isDarkMode = isDarkModeEnabled();
    document.body.classList.toggle('dark-mode', isDarkMode);
    document.body.setAttribute('data-theme', isDarkMode ? 'dark' : 'light');
    
    // Notify any components that need to adjust to theme changes
    notifyThemeChange();
} 