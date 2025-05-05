// Calendar functionality for Atomic Momentum
import { getHabits, saveHabits } from './services/storageService.js';

// Global filter state
window.calendarCurrentFilterHabit = null;

// Helper function to check habit completion status
function checkHabitCompletion(habit, dateStr, habitHistory) {
    if (!habit || !dateStr) {
        console.log('Missing habit or date in checkHabitCompletion');
        return null;
    }
    
    // Debug output
    console.log(`Checking completion for habit: ${habit.name}, date: ${dateStr}`);
    
    // Per-habit history check
    if (habit.history && typeof habit.history === 'object') {
        if (dateStr in habit.history) {
            console.log(`Found in habit.history: ${habit.history[dateStr]}`);
            return habit.history[dateStr];
        }
    }
    
    // Global history fallback
    if (habitHistory && typeof habitHistory === 'object' && 
        habitHistory[dateStr] && typeof habitHistory[dateStr] === 'object') {
        
        // Check using habit.id first
        if (habit.id && habitHistory[dateStr][habit.id]) {
            console.log(`Found in global history by habit.id: ${habitHistory[dateStr][habit.id]}`);
            return habitHistory[dateStr][habit.id];
        }
        
        // If that fails, try to find by iterating through the date's entries
        const entries = Object.entries(habitHistory[dateStr]);
        for (const [id, status] of entries) {
            if (id === habit.id || id === habit.name) {
                console.log(`Found in global history by alternative id: ${status}`);
                return status;
            }
        }
    }
    
    console.log(`No completion status found for ${habit.name} on ${dateStr}`);
    return null;
}

// Helper function to get a consistent date string
function getLocalDateString(year, month, day) {
    const localDate = new Date(year, month, day);
    const yyyy = localDate.getFullYear();
    const mm = String(localDate.getMonth() + 1).padStart(2, '0');
    const dd = String(localDate.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
}

// Helper function to get today's date in YYYY-MM-DD format
function getTodayFormatted() {
    const today = new Date();
    return getLocalDateString(today.getFullYear(), today.getMonth(), today.getDate());
}

// Function to render calendar days
function renderCalendarDays(calendarGrid, currentMonthDisplay, currentViewMonth, currentViewYear, habits) {
    // Validate required parameters
    if (!calendarGrid || !(calendarGrid instanceof Element)) {
        console.warn('Calendar grid element is missing or invalid');
        return;
    }
    
    if (!currentMonthDisplay || !(currentMonthDisplay instanceof Element)) {
        console.warn('Month display element is missing or invalid');
        return;
    }
    
    // Clear existing calendar days
    calendarGrid.innerHTML = '';
    
    // Update month display using local date
    const monthDate = new Date(currentViewYear, currentViewMonth, 1);
    currentMonthDisplay.textContent = monthDate.toLocaleDateString(undefined, {
        month: 'long',
        year: 'numeric'
    });
    
    // First day of the month (using local date)
    const firstDay = new Date(currentViewYear, currentViewMonth, 1);
    const lastDay = new Date(currentViewYear, currentViewMonth + 1, 0);
    const firstDayOfWeek = firstDay.getDay();
    
    // Create empty cells for days before the first of the month
    for (let i = 0; i < firstDayOfWeek; i++) {
        const emptyCell = document.createElement('div');
        emptyCell.style.height = '40px';
        emptyCell.style.backgroundColor = 'transparent';
        emptyCell.style.borderRadius = '4px';
        calendarGrid.appendChild(emptyCell);
    }
    
    // Load habit history
    const habitHistory = loadHabitHistory();
    console.log('Loaded habit history:', habitHistory);
    
    // Create cells for all days in the month
    for (let day = 1; day <= lastDay.getDate(); day++) {
        const dayCell = document.createElement('div');
        dayCell.style.height = '40px';
        dayCell.style.backgroundColor = isDarkModeEnabled() ? '#333' : '#f0f0f0';
        dayCell.style.display = 'flex';
        dayCell.style.flexDirection = 'column';
        dayCell.style.alignItems = 'center';
        dayCell.style.justifyContent = 'space-between';
        dayCell.style.padding = '5px';
        dayCell.style.borderRadius = '4px';
        dayCell.style.cursor = 'pointer';
        dayCell.style.position = 'relative';
        
        // Get the date string for this day
        const dateString = getLocalDateString(currentViewYear, currentViewMonth, day);
        console.log('Processing date:', dateString);
        
        // Highlight current day
        if (dateString === getTodayFormatted()) {
            dayCell.style.border = '2px solid #673ab7';
            dayCell.style.fontWeight = 'bold';
        }
        
        const dayNumber = document.createElement('div');
        dayNumber.textContent = day;
        dayCell.appendChild(dayNumber);
        
        // Add habit completion indicators
        const completionIndicator = document.createElement('div');
        completionIndicator.style.display = 'flex';
        completionIndicator.style.gap = '2px';
        completionIndicator.style.marginTop = '2px';
        
        // If we're filtering by a specific habit
        if (window.calendarCurrentFilterHabit) {
            const habit = habits[window.calendarCurrentFilterHabit];
            if (habit) {
                const status = checkHabitCompletion(habit, dateString, habitHistory);
                if (status) {
                const indicator = document.createElement('div');
                    if (status === "completed") {
                    indicator.style.width = '12px';
                    indicator.style.height = '12px';
                    indicator.style.borderRadius = '50%';
                        indicator.style.backgroundColor = habit.color;
                } else {
                    indicator.style.width = '10px';
                    indicator.style.height = '10px';
                    indicator.style.borderRadius = '50%';
                    indicator.style.backgroundColor = '#ccc';
                    indicator.style.opacity = '0.5';
                }
                completionIndicator.appendChild(indicator);
                }
            }
        } else {
            // Show all habits for this day
            let completedCount = 0;
            let uncompletedCount = 0;
            
            Object.entries(habits).forEach(([habitId, habit]) => {
                const status = checkHabitCompletion(habit, dateString, habitHistory);
                if (status === "completed") {
                    completedCount++;
                } else if (status === "not_completed") {
                    uncompletedCount++;
                }
            });
            
            // Show completed habits
            if (completedCount > 0) {
                        const indicator = document.createElement('div');
                        indicator.style.width = '6px';
                        indicator.style.height = '6px';
                        indicator.style.borderRadius = '50%';
                indicator.style.backgroundColor = '#4CAF50';
                completionIndicator.appendChild(indicator);
            }
            
            // Show uncompleted habits
            if (uncompletedCount > 0) {
                const indicator = document.createElement('div');
                indicator.style.width = '6px';
                indicator.style.height = '6px';
                indicator.style.borderRadius = '50%';
                            indicator.style.backgroundColor = '#ccc';
                            indicator.style.opacity = '0.5';
                completionIndicator.appendChild(indicator);
                        }
                        
            // Show "more" indicator if needed
            if (completedCount + uncompletedCount > 2) {
                        const moreIndicator = document.createElement('div');
                        moreIndicator.textContent = '+';
                        moreIndicator.style.fontSize = '8px';
                moreIndicator.style.color = isDarkModeEnabled() ? '#aaa' : '#666';
                        completionIndicator.appendChild(moreIndicator);
            }
        }
        
        dayCell.appendChild(completionIndicator);
        
        // Add click handler to show daily habit details
        dayCell.onclick = () => {
            showDayDetails(dateString, isDarkModeEnabled(), habits);
        };
        
        calendarGrid.appendChild(dayCell);
    }
}

// Function to show details for a selected day
function showDayDetails(dateString, isDarkMode, habits) {
    const habitHistory = loadHabitHistory() || {};
    console.log('Showing details for date:', dateString);
    console.log('Full habit history:', habitHistory);
    console.log('Habits object:', habits);
    
    // Create overlay for popup
    const overlay = document.createElement('div');
    overlay.className = 'dialog-overlay';
    
    // Create popup container
    const popup = document.createElement('div');
    popup.className = 'calendar-popup';
    popup.style.backgroundColor = 'var(--section-bg-color)'; // Ensure background color is explicitly set
    popup.style.color = 'var(--text-color)'; // Ensure text color is explicitly set
    
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
        // Safer parent element removal
        if (overlay.parentElement) {
            overlay.parentElement.removeChild(overlay);
        }
    };
    
    // Function to create and update the habits list
    function createHabitsList(selectedHabitId = null) {
        // Create new habits list
    const habitsList = document.createElement('div');
        habitsList.className = 'habit-list';
    
        // Show habits based on filter
        let hasAnyData = false;
        
        // Guard against undefined or null habits
        if (!habits) {
            habits = {};
            console.log('No habits object provided, using empty object');
        }
        
        if (selectedHabitId) {
            const habit = habits[selectedHabitId];
            if (habit) {
                const status = checkHabitCompletion(habit, dateString, habitHistory);
                console.log(`Filtered habit ${habit.name} status:`, status);
                
                // More robust check: accept any string value including falsy strings
                if (status !== null && status !== undefined) {
                    hasAnyData = true;
                    displayHabitHistoryItem(habitsList, selectedHabitId, status, habit, isDarkMode);
                }
            }
        } else {
            // Only proceed if habits is defined and not empty
            if (habits && Object.keys(habits).length > 0) {
                // Sort habits by name and show all - with guard against undefined habits
                try {
                    console.log('Processing all habits for date:', dateString);
                    
                    const sortedHabits = Object.entries(habits).sort(([,a], [,b]) => {
                        // Guard against undefined habit properties
                        const nameA = a && a.name ? a.name : '';
                        const nameB = b && b.name ? b.name : '';
                        return nameA.localeCompare(nameB);
                    });
                    
                    // Debug log of sorted habits
                    console.log('Sorted habits:', sortedHabits.map(([id, h]) => h.name));
                    
                    sortedHabits.forEach(([habitId, habit]) => {
                        if (habit) { // Additional guard to ensure habit exists
                            const status = checkHabitCompletion(habit, dateString, habitHistory);
                            console.log(`Habit ${habit.name} (${habitId}) status:`, status);
                            
                            // More robust check: accept any string value including falsy strings
                            if (status !== null && status !== undefined) {
                                hasAnyData = true;
                                displayHabitHistoryItem(habitsList, habitId, status, habit, isDarkMode);
        }
                        }
                    });
                    
                    console.log('Has any data after processing:', hasAnyData);
                } catch (error) {
                    console.error('Error processing habits:', error);
                    // Show error message in UI
                    const errorMsg = document.createElement('div');
                    errorMsg.className = 'no-data-message';
                    errorMsg.textContent = 'Error loading habit data.';
                    habitsList.appendChild(errorMsg);
                }
            }
        }
        
        if (!hasAnyData) {
            const noDataMsg = document.createElement('div');
            noDataMsg.className = 'no-data-message';
            noDataMsg.textContent = selectedHabitId ? 
                'No data recorded for this habit on this date.' :
                'No habits recorded for this date.';
            habitsList.appendChild(noDataMsg);
        }
        
        return habitsList;
    }
    
    // Create and add initial habits list
    const habitsList = createHabitsList(window.calendarCurrentFilterHabit);
    
    // Add filter section
    const filterSection = document.createElement('div');
    filterSection.className = 'filter-section';
    
    const filterLabel = document.createElement('div');
    filterLabel.textContent = 'Filter Calendar By:';
    filterLabel.style.marginBottom = '10px';
    filterLabel.style.fontWeight = 'bold';
    
    const filterButtons = document.createElement('div');
    filterButtons.className = 'filter-buttons';
    
    // Function to update the filter and refresh the popup content
    function updateFilter(selectedHabitId) {
        // Update filter state
        window.calendarCurrentFilterHabit = selectedHabitId;
        
        // Update active state on filter buttons
        const allFilterButtons = filterButtons.querySelectorAll('.filter-button');
        allFilterButtons.forEach(btn => {
            if ((selectedHabitId === null && btn.classList.contains('all-habits-btn')) ||
                btn.dataset.habitId === selectedHabitId) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        });
        
        // Replace the habits list with updated filtered content
        const oldHabitsList = popup.querySelector('.habit-list');
        const newHabitsList = createHabitsList(selectedHabitId);
        if (oldHabitsList) {
            popup.replaceChild(newHabitsList, oldHabitsList);
        }
        
        // Also update the main calendar view (without closing the popup)
        if (typeof renderCalendarDays === 'function') {
            // Use setTimeout to ensure this happens after the current event loop
            setTimeout(() => {
                try {
                    // Only update the main calendar after the popup interaction is complete
                    const calendarGrid = document.querySelector('.calendar-grid');
                    if (calendarGrid) {
                        console.log('Updating calendar grid dots for filter:', selectedHabitId);
                        // Note: The calendar grid will be updated but the popup remains open
                    }
                } catch (e) {
                    console.error('Error updating calendar grid:', e);
                }
            }, 50);
        }
    }
    
    // Add "Show All" button
    const allButton = document.createElement('button');
    allButton.textContent = 'All Habits';
    allButton.className = 'filter-button all-habits-btn';
    
    if (window.calendarCurrentFilterHabit === null) {
        allButton.classList.add('active');
    }
    
    allButton.onclick = () => {
        updateFilter(null);
    };
    
    filterButtons.appendChild(allButton);
    
    // Add a button for each habit
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        if (!habit) return; // Skip if habit is undefined
        
        const filterButton = document.createElement('button');
        filterButton.textContent = habit.name;
        filterButton.className = 'filter-button';
        filterButton.dataset.habitId = habitId;
        
        if (window.calendarCurrentFilterHabit === habitId) {
            filterButton.classList.add('active');
            filterButton.style.backgroundColor = habit.color;
        }
        
        filterButton.onclick = () => {
            updateFilter(habitId);
        };
        
        filterButtons.appendChild(filterButton);
    });
    
    filterSection.appendChild(filterLabel);
    filterSection.appendChild(filterButtons);
    
    // Assemble popup
    popup.appendChild(closeButton);
    popup.appendChild(title);
    popup.appendChild(habitsList);
    popup.appendChild(filterSection);
    overlay.appendChild(popup);
    
    // Close popup when clicking overlay
    overlay.onclick = (e) => {
        if (e.target === overlay && overlay.parentElement) {
            overlay.parentElement.removeChild(overlay);
        }
    };
    
    // Add to app-root instead of body to maintain theme context
    const appRoot = document.getElementById('app-root');
    if (appRoot) {
        appRoot.appendChild(overlay);
    } else {
        // Fallback to body if app-root is not found
    document.body.appendChild(overlay);
    }
}

// Helper function to display a habit history item
function displayHabitHistoryItem(parentElement, habitId, status, habit, isDarkMode) {
    if (!habit) return;
    
    const habitItem = document.createElement('div');
    habitItem.className = 'habit-item';
    
    const habitName = document.createElement('div');
    habitName.className = 'habit-name';
    habitName.textContent = habit.name;
    habitName.style.color = habit.color;
    
    const habitStatus = document.createElement('div');
    habitStatus.className = `habit-status ${status}`;
    
    if (status === "completed") {
        habitStatus.innerHTML = '✅ Completed';
    } else {
        habitStatus.innerHTML = '❌ Not Completed';
    }
    
    habitItem.appendChild(habitName);
    habitItem.appendChild(habitStatus);
    parentElement.appendChild(habitItem);
}

// Export necessary functions
window.showDayDetails = showDayDetails;
export { showDayDetails }; 