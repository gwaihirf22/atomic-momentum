// Calendar functionality for Atomic Momentum

// Global variable to track which habit is being filtered in calendar view
window.calendarCurrentFilterHabit = null;

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
    
    // Clear existing calendar days (keep header row with day names)
    const headerRowCount = 7; // Number of day headers (Sun-Sat)
    while (calendarGrid && calendarGrid.childElementCount > headerRowCount) {
        calendarGrid.removeChild(calendarGrid.lastChild);
    }
    
    // Update month display
    currentMonthDisplay.textContent = `${new Date(currentViewYear, currentViewMonth, 1).toLocaleString('default', { month: 'long' })} ${currentViewYear}`;
    
    // First day of the month
    const firstDay = new Date(currentViewYear, currentViewMonth, 1);
    // Last day of the month
    const lastDay = new Date(currentViewYear, currentViewMonth + 1, 0);
    
    // Get day of week for the first day (0-6, Sunday to Saturday)
    const firstDayOfWeek = firstDay.getDay();
    
    // Create empty cells for days from previous month
    for (let i = 0; i < firstDayOfWeek; i++) {
        const emptyCell = document.createElement('div');
        emptyCell.style.height = '40px';
        emptyCell.style.backgroundColor = 'transparent';
        emptyCell.style.borderRadius = '4px';
        calendarGrid.appendChild(emptyCell);
    }
    
    // Create cells for all days in the month
    const habitHistory = loadHabitHistory();
    const today = new Date();
    const isDarkMode = isDarkModeEnabled();
    
    for (let day = 1; day <= lastDay.getDate(); day++) {
        const dayCell = document.createElement('div');
        dayCell.style.height = '40px';
        dayCell.style.backgroundColor = isDarkMode ? '#333' : '#f0f0f0';
        dayCell.style.display = 'flex';
        dayCell.style.flexDirection = 'column';
        dayCell.style.alignItems = 'center';
        dayCell.style.justifyContent = 'space-between';
        dayCell.style.padding = '5px';
        dayCell.style.borderRadius = '4px';
        dayCell.style.cursor = 'pointer';
        dayCell.style.position = 'relative';
        
        // Highlight current day
        if (currentViewYear === today.getFullYear() && 
            currentViewMonth === today.getMonth() && 
            day === today.getDate()) {
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
        
        // Get habit status for this day
        const checkDate = formatDate(new Date(currentViewYear, currentViewMonth, day));
        
        // If we're filtering by a specific habit
        if (window.calendarCurrentFilterHabit) {
            if (habitHistory && habitHistory[checkDate] && habitHistory[checkDate][window.calendarCurrentFilterHabit]) {
                // Show a larger indicator if a specific habit is filtered
                const indicator = document.createElement('div');
                if (habitHistory[checkDate][window.calendarCurrentFilterHabit] === "completed") {
                    indicator.style.width = '12px';
                    indicator.style.height = '12px';
                    indicator.style.borderRadius = '50%';
                    const habit = habits[window.calendarCurrentFilterHabit];
                    indicator.style.backgroundColor = habit ? habit.color : '#4CAF50';
                } else {
                    indicator.style.width = '10px';
                    indicator.style.height = '10px';
                    indicator.style.borderRadius = '50%';
                    indicator.style.backgroundColor = '#ccc';
                    indicator.style.opacity = '0.5';
                }
                completionIndicator.appendChild(indicator);
            }
        } else {
            // Show all habits for this day (limited to dots)
            if (habitHistory && habitHistory[checkDate]) {
                Object.keys(habitHistory[checkDate]).forEach((habitId, index) => {
                    if (index < 3) { // Limit to 3 indicators per day to avoid overflow
                        const indicator = document.createElement('div');
                        indicator.style.width = '6px';
                        indicator.style.height = '6px';
                        indicator.style.borderRadius = '50%';
                        
                        if (habitHistory[checkDate][habitId] === "completed") {
                            const habit = habits[habitId];
                            indicator.style.backgroundColor = habit ? habit.color : '#4CAF50';
                        } else {
                            indicator.style.backgroundColor = '#ccc';
                            indicator.style.opacity = '0.5';
                        }
                        
                        completionIndicator.appendChild(indicator);
                    } else if (index === 3) {
                        // Add a "more" indicator
                        const moreIndicator = document.createElement('div');
                        moreIndicator.textContent = '+';
                        moreIndicator.style.fontSize = '8px';
                        moreIndicator.style.color = isDarkMode ? '#aaa' : '#666';
                        completionIndicator.appendChild(moreIndicator);
                    }
                });
            }
        }
        
        dayCell.appendChild(completionIndicator);
        
        // Add click handler to show daily habit details
        dayCell.onclick = () => {
            showDayDetails(checkDate, isDarkMode, habits);
        };
        
        calendarGrid.appendChild(dayCell);
    }
}

// Function to show details for a selected day
function showDayDetails(dateString, isDarkMode, habits) {
    const formatOptions = { 
        weekday: 'long', 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
    };
    
    // Get habit history
    const habitHistory = loadHabitHistory();
    const dateHistory = habitHistory[dateString] || {};
    
    // Create overlay for popup
    const overlay = document.createElement('div');
    overlay.style.position = 'fixed';
    overlay.style.top = '0';
    overlay.style.left = '0';
    overlay.style.width = '100%';
    overlay.style.height = '100%';
    overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.5)';
    overlay.style.display = 'flex';
    overlay.style.justifyContent = 'center';
    overlay.style.alignItems = 'center';
    overlay.style.zIndex = '1000';
    
    // Create popup container
    const popup = document.createElement('div');
    popup.style.width = '80%';
    popup.style.maxWidth = '400px';
    popup.style.backgroundColor = isDarkMode ? '#1e1e1e' : 'white';
    popup.style.borderRadius = '8px';
    popup.style.padding = '20px';
    popup.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.2)';
    popup.style.position = 'relative';
    
    // Format date for display
    const displayDate = new Date(dateString);
    
    // Popup title
    const title = document.createElement('h3');
    title.textContent = displayDate.toLocaleDateString(undefined, formatOptions);
    title.style.textAlign = 'center';
    title.style.marginTop = '0';
    title.style.marginBottom = '20px';
    
    // Close button
    const closeButton = document.createElement('div');
    closeButton.innerHTML = '&times;';
    closeButton.style.position = 'absolute';
    closeButton.style.top = '10px';
    closeButton.style.right = '15px';
    closeButton.style.fontSize = '24px';
    closeButton.style.cursor = 'pointer';
    closeButton.style.color = isDarkMode ? '#aaa' : '#666';
    
    closeButton.onclick = () => {
        document.body.removeChild(overlay);
    };
    
    // Habits list
    const habitsList = document.createElement('div');
    habitsList.style.marginTop = '10px';
    
    // If we have a filter active, only show that habit
    if (window.calendarCurrentFilterHabit) {
        if (dateHistory[window.calendarCurrentFilterHabit]) {
            const status = dateHistory[window.calendarCurrentFilterHabit]; // "completed" or "not_completed"
            const habit = habits[window.calendarCurrentFilterHabit]; // Get the current habit info
            displayHabitHistoryItem(habitsList, window.calendarCurrentFilterHabit, status, habit, isDarkMode);
        } else {
            const noDataMsg = document.createElement('div');
            noDataMsg.textContent = 'No data recorded for this habit on this date.';
            noDataMsg.style.textAlign = 'center';
            noDataMsg.style.color = isDarkMode ? '#aaa' : '#666';
            noDataMsg.style.padding = '20px 0';
            habitsList.appendChild(noDataMsg);
        }
    } else {
        // Show all habits for the selected date
        if (Object.keys(dateHistory).length === 0) {
            const noDataMsg = document.createElement('div');
            noDataMsg.textContent = 'No habits recorded for this date.';
            noDataMsg.style.textAlign = 'center';
            noDataMsg.style.color = isDarkMode ? '#aaa' : '#666';
            noDataMsg.style.padding = '20px 0';
            habitsList.appendChild(noDataMsg);
        } else {
            // Sort habit entries alphabetically by habit name
            const sortedHabitEntries = Object.entries(dateHistory).sort((a, b) => {
                const habitA = habits[a[0]] || { name: 'Unknown' };
                const habitB = habits[b[0]] || { name: 'Unknown' };
                return habitA.name.localeCompare(habitB.name);
            });
            
            sortedHabitEntries.forEach(([habitId, status]) => {
                const habit = habits[habitId];
                displayHabitHistoryItem(habitsList, habitId, status, habit, isDarkMode);
            });
        }
    }
    
    // Habit filter section
    const filterSection = document.createElement('div');
    filterSection.style.marginTop = '20px';
    filterSection.style.borderTop = isDarkMode ? '1px solid #444' : '1px solid #ddd';
    filterSection.style.paddingTop = '15px';
    
    const filterLabel = document.createElement('div');
    filterLabel.textContent = 'Filter Calendar By:';
    filterLabel.style.marginBottom = '10px';
    filterLabel.style.fontWeight = 'bold';
    
    const filterButtons = document.createElement('div');
    filterButtons.style.display = 'flex';
    filterButtons.style.flexWrap = 'wrap';
    filterButtons.style.gap = '5px';
    
    // Add "Show All" button
    const allButton = document.createElement('button');
    allButton.textContent = 'All Habits';
    allButton.style.backgroundColor = window.calendarCurrentFilterHabit === null ? '#673ab7' : (isDarkMode ? '#333' : '#f0f0f0');
    allButton.style.color = window.calendarCurrentFilterHabit === null ? 'white' : (isDarkMode ? '#ddd' : '#333');
    allButton.style.border = 'none';
    allButton.style.borderRadius = '4px';
    allButton.style.padding = '5px 10px';
    allButton.style.cursor = 'pointer';
    
    allButton.onclick = () => {
        window.calendarCurrentFilterHabit = null;
        document.body.removeChild(overlay);
        // Force calendar redraw
        if (typeof renderCalendarDays === 'function') {
            renderCalendarDays();
        }
    };
    
    filterButtons.appendChild(allButton);
    
    // Add a button for each habit
    Object.keys(habits).forEach(habitId => {
        const habit = habits[habitId];
        const filterButton = document.createElement('button');
        filterButton.textContent = habit.name;
        filterButton.style.backgroundColor = window.calendarCurrentFilterHabit === habitId ? habit.color : (isDarkMode ? '#333' : '#f0f0f0');
        filterButton.style.color = window.calendarCurrentFilterHabit === habitId ? 'white' : (isDarkMode ? '#ddd' : '#333');
        filterButton.style.border = 'none';
        filterButton.style.borderRadius = '4px';
        filterButton.style.padding = '5px 10px';
        filterButton.style.cursor = 'pointer';
        
        filterButton.onclick = () => {
            window.calendarCurrentFilterHabit = habitId;
            document.body.removeChild(overlay);
            // Force calendar redraw
            if (typeof renderCalendarDays === 'function') {
                renderCalendarDays();
            }
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
        if (e.target === overlay) {
            document.body.removeChild(overlay);
        }
    };
    
    document.body.appendChild(overlay);
}

// Helper function to display a habit history item
function displayHabitHistoryItem(parentElement, habitId, status, habit, isDarkMode) {
    if (!habit) return; // Skip if habit doesn't exist anymore
    
    const habitItem = document.createElement('div');
    habitItem.style.padding = '10px';
    habitItem.style.marginBottom = '10px';
    habitItem.style.borderRadius = '4px';
    habitItem.style.backgroundColor = isDarkMode ? '#333' : '#f0f0f0';
    habitItem.style.display = 'flex';
    habitItem.style.justifyContent = 'space-between';
    habitItem.style.alignItems = 'center';
    
    const habitName = document.createElement('div');
    habitName.textContent = habit.name;
    habitName.style.fontWeight = 'bold';
    habitName.style.color = habit.color;
    
    const habitStatus = document.createElement('div');
    if (status === "completed") {
        habitStatus.innerHTML = '✅ Completed';
        habitStatus.style.color = '#4CAF50';
    } else {
        habitStatus.innerHTML = '❌ Not Completed';
        habitStatus.style.color = '#F44336';
    }
    
    habitItem.appendChild(habitName);
    habitItem.appendChild(habitStatus);
    parentElement.appendChild(habitItem);
} 