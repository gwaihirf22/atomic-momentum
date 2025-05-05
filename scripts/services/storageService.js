/**
 * Storage service for handling habit data persistence
 * Abstracts localStorage operations with proper error handling
 */

/**
 * Retrieves habits from localStorage
 * @returns {Array} Array of habit objects or empty array if none exist or error occurs
 */
function getHabits() {
  try {
    const habitsData = localStorage.getItem('habits');
    return habitsData ? JSON.parse(habitsData) : [];
  } catch (error) {
    console.error('Error retrieving habits from storage:', error);
    return [];
  }
}

/**
 * Saves habits to localStorage
 * @param {Array} habits Array of habit objects to save
 * @returns {boolean} True if save was successful, false otherwise
 */
function saveHabits(habits) {
  try {
    localStorage.setItem('habits', JSON.stringify(habits));
    return true;
  } catch (error) {
    console.error('Error saving habits to storage:', error);
    return false;
  }
}

// Export the functions
export { getHabits, saveHabits }; 