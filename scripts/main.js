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
    // TODO: BUG-011 - This function currently re-renders ALL habit cards,
    // causing unnecessary DOM updates and potential flickering.
    // Refactor to support individual habit updates instead of full re-render.
    // Consider using a component-based approach or keeping references to habit cards.
    
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
    // Apply animations with slight delay based on index for staggered effect
    const index = Object.keys(habits).indexOf(habitId);
    card.style.animationDelay = `${index * 0.05}s`;
    card.style.animationName = 'slideIn';
    card.style.animationDuration = '0.3s';
    card.style.animationFillMode = 'backwards';
    
    // Set background color based on theme (the rest of styling is in CSS)
    card.style.backgroundColor = isDarkModeEnabled() ? '#1e1e1e' : '#fff';
    
    const title = document.createElement('div');
    title.className = 'habit-title';
    
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
    btnContainer.style.gap = '16px';
    
    // Add edit button (pencil icon)
    const editBtn = document.createElement('button');
    editBtn.innerHTML = '✏️'; // Pencil emoji
    editBtn.style.background = 'transparent';
    editBtn.style.border = 'none';
    editBtn.style.fontSize = '20px';
    editBtn.style.cursor = 'pointer';
    editBtn.style.padding = '5px';
    editBtn.title = 'Edit habit';
    editBtn.addEventListener('click', () => showEditHabitScreen(habitId, habit));
    
    // Add delete button (trash icon)
    const deleteBtn = document.createElement('button');
    deleteBtn.innerHTML = '🗑️'; // Trash emoji
    deleteBtn.style.background = 'transparent';
    deleteBtn.style.border = 'none';
    deleteBtn.style.fontSize = '20px';
    deleteBtn.style.cursor = 'pointer';
    deleteBtn.style.padding = '5px';
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
            
            // Add a subtle completion animation
            const habitCard = document.querySelector(`.habit-card:nth-child(${Object.keys(habits).indexOf(habitId) + 1})`);
            if (habitCard) {
                // Flash effect for completion
                const flashOverlay = document.createElement('div');
                flashOverlay.style.position = 'absolute';
                flashOverlay.style.top = '0';
                flashOverlay.style.left = '0';
                flashOverlay.style.width = '100%';
                flashOverlay.style.height = '100%';
                flashOverlay.style.backgroundColor = habit.color;
                flashOverlay.style.opacity = '0.1';
                flashOverlay.style.borderRadius = '12px';
                flashOverlay.style.pointerEvents = 'none';
                flashOverlay.style.animation = 'flash 0.6s forwards';
                
                // Create flash keyframes if they don't exist
                if (!document.getElementById('flash-animation')) {
                    const styleSheet = document.createElement('style');
                    styleSheet.id = 'flash-animation';
                    styleSheet.textContent = `
                        @keyframes flash {
                            0% { opacity: 0.2; }
                            50% { opacity: 0.3; }
                            100% { opacity: 0; }
                        }
                    `;
                    document.head.appendChild(styleSheet);
                }
                
                habitCard.appendChild(flashOverlay);
                setTimeout(() => {
                    if (flashOverlay.parentNode === habitCard) {
                        habitCard.removeChild(flashOverlay);
                    }
                }, 600);
            }
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
        
        // Animate the progress bar before re-rendering
        const habitCard = document.querySelector(`.habit-card:nth-child(${Object.keys(habits).indexOf(habitId) + 1})`);
        if (habitCard) {
            const progressFill = habitCard.querySelector('.progress-fill');
            if (progressFill) {
                const newWidth = Math.min((newProgress / habit.target) * 100, 100) + '%';
                progressFill.style.transition = 'width 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)';
                progressFill.style.width = newWidth;
                
                // Wait for animation to complete before re-rendering
                setTimeout(() => {
                    // TODO: BUG-011 - Instead of calling renderHabits() which rebuilds all cards,
                    // implement a updateHabitCard(habitId) function that only updates the changed card.
                    // This will improve performance and UX by avoiding unnecessary DOM operations.
                    renderHabits();
                }, 400);
            } else {
                // If progress fill not found, just re-render
                // TODO: BUG-011 - Replace with targeted updating of just this habit card
                renderHabits();
            }
        } else {
            // If card not found, just re-render
            // TODO: BUG-011 - Implement selective rendering of individual habit cards
            renderHabits();
        }
        
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
    
    // Keep track of selected color
    let selectedColor = presetColors[0].value;
    
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
                color: selectedColor, // Use the selected color from swatches
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
    form.appendChild(colorSwatchesContainer);
    
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
    // TODO: BUG-010 - Replace these generic icons with a curated set of habit-specific icons
    // Create a more comprehensive collection of monochrome icons for common habit types
    // Ensure the same icon set is used here as in the Add Habit screen
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
    
    // Keep track of selected color - initialize with current habit color
    let selectedColor = habit.color;
    
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
        if (color.value === habit.color) {
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
    nativeColorPicker.value = habit.color; // Set to current habit color
    nativeColorPicker.style.opacity = '0';
    nativeColorPicker.style.position = 'absolute';
    nativeColorPicker.style.top = '0';
    nativeColorPicker.style.left = '0';
    nativeColorPicker.style.width = '100%';
    nativeColorPicker.style.height = '100%';
    nativeColorPicker.style.cursor = 'pointer';
    
    // Check if current habit color is not in the presets - if so, select the custom option
    const isCustomColor = !presetColors.some(color => color.value === habit.color);
    if (isCustomColor) {
        customColorSwatch.style.border = '3px solid white';
        customColorSwatch.style.boxShadow = '0 0 0 2px #673ab7';
        customColorSwatch.style.transform = 'scale(1.1)';
    }
    
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
            habits[habitId].color = selectedColor;
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
    form.appendChild(colorSwatchesContainer);
    
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
    appearanceSection.style.boxSizing = 'border-box'; // Ensure padding is included in width calculation
    appearanceSection.style.borderRadius = '8px';
    appearanceSection.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    appearanceSection.style.marginBottom = '16px';
    
    // Media query equivalent for small screens
    if (window.innerWidth < 350) {
        appearanceSection.style.padding = '12px 10px'; // Reduce padding on small screens
    }
    
    const appearanceTitle = document.createElement('h3');
    appearanceTitle.textContent = 'Appearance';
    appearanceTitle.style.margin = '0 0 16px 0';
    
    // Dark Mode Switch
    const darkModeRow = document.createElement('div');
    darkModeRow.style.display = 'flex';
    darkModeRow.style.flexWrap = 'wrap'; // Add flex-wrap for small screens
    darkModeRow.style.alignItems = 'center';
    darkModeRow.style.justifyContent = 'space-between';
    darkModeRow.style.padding = '8px 0';
    darkModeRow.style.gap = '12px'; // Add gap for spacing when wrapped
    
    const darkModeLabel = document.createElement('div');
    darkModeLabel.style.flex = '1'; // Allow label to grow
    darkModeLabel.style.minWidth = '200px'; // Ensure good readability before wrapping
    darkModeLabel.style.marginRight = '8px'; // Add margin for spacing
    
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
    switchContainer.style.flexShrink = '0'; // Prevent the switch from shrinking
    
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
    notificationsSection.style.boxSizing = 'border-box'; // Ensure padding is included in width calculation
    notificationsSection.style.borderRadius = '8px';
    notificationsSection.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    notificationsSection.style.marginBottom = '16px';
    notificationsSection.style.color = isDarkMode ? '#fff' : '#000';
    
    // Media query equivalent for small screens
    if (window.innerWidth < 350) {
        notificationsSection.style.padding = '12px 10px'; // Reduce padding on small screens
    }
    
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
    
    // Add resize listener to handle responsive layout changes
    const updateResponsiveLayout = () => {
        const isNarrow = window.innerWidth < 350;
        appearanceSection.style.padding = isNarrow ? '12px 10px' : '16px';
        notificationsSection.style.padding = isNarrow ? '12px 10px' : '16px';
    };
    
    // Initial call and event listener
    updateResponsiveLayout();
    window.addEventListener('resize', updateResponsiveLayout);
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
    calendarContainer.style.padding = '14px'; // Reduce padding to tighten spacing
    
    // Create calendar content
    const calendarContent = document.createElement('div');
    calendarContent.className = 'calendar-content';
    calendarContent.style.backgroundColor = isDarkMode ? '#1e1e1e' : 'white';
    calendarContent.style.borderRadius = '8px';
    calendarContent.style.boxShadow = isDarkMode ? '0 1px 3px rgba(255,255,255,0.1)' : '0 1px 3px rgba(0,0,0,0.1)';
    
    const calendarHeading = document.createElement('h2');
    calendarHeading.className = 'calendar-heading';
    calendarHeading.textContent = 'Habit History';
    calendarHeading.style.marginTop = '0';
    calendarHeading.style.marginBottom = '8px';
    
    // Global habit filter
    const filterContainer = document.createElement('div');
    filterContainer.className = 'calendar-filter-container';
    filterContainer.style.marginTop = '4px';
    filterContainer.style.marginBottom = '8px';
    filterContainer.style.display = 'flex';
    filterContainer.style.flexDirection = 'column';
    filterContainer.style.gap = '4px';
    
    const filterLabel = document.createElement('div');
    filterLabel.textContent = 'Filter Calendar By:';
    filterLabel.style.fontWeight = 'bold';
    filterLabel.style.marginBottom = '2px';
    
    const filterButtonsContainer = document.createElement('div');
    filterButtonsContainer.className = 'filter-buttons-container';
    filterButtonsContainer.style.display = 'flex';
    filterButtonsContainer.style.flexWrap = 'wrap';
    filterButtonsContainer.style.gap = '6px';
    
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
    prevButton.style.backgroundColor = '#673ab7';
    prevButton.style.color = 'white';
    prevButton.style.border = 'none';
    prevButton.style.borderRadius = '4px';
    prevButton.style.padding = '5px 15px';
    prevButton.style.cursor = 'pointer';
    prevButton.style.marginRight = '8px';
    prevButton.style.flexShrink = '0';
    
    // Current month and year display
    const currentMonthDisplay = document.createElement('div');
    const currentDate = new Date();
    currentMonthDisplay.textContent = `${currentDate.toLocaleString('default', { month: 'long' })} ${currentDate.getFullYear()}`;
    currentMonthDisplay.style.fontSize = '18px';
    currentMonthDisplay.style.fontWeight = 'bold';
    currentMonthDisplay.style.textAlign = 'center';
    currentMonthDisplay.style.flex = '1';
    currentMonthDisplay.style.minWidth = '150px'; // Ensure month label has enough space
    currentMonthDisplay.style.padding = '0 10px'; // Add some padding
    
    // Next month button
    const nextButton = document.createElement('button');
    nextButton.className = 'month-nav-button';
    nextButton.innerHTML = '&rarr;';
    nextButton.style.backgroundColor = '#673ab7';
    nextButton.style.color = 'white';
    nextButton.style.border = 'none';
    nextButton.style.borderRadius = '4px';
    nextButton.style.padding = '5px 15px';
    nextButton.style.cursor = 'pointer';
    nextButton.style.marginLeft = '8px';
    nextButton.style.flexShrink = '0';
    
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
    
    // Add elements to month selector in the correct order - buttons on either side of month
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