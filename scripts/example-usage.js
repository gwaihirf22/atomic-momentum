import HabitForm from './components/habitForm.js';

// Make sure to include these CSS files in your HTML:
// <link rel="stylesheet" href="styles/icon-selector.css">
// <link rel="stylesheet" href="styles/habit-form.css">

document.addEventListener('DOMContentLoaded', () => {
  // Elements
  const newHabitBtn = document.getElementById('new-habit-btn');
  const formContainer = document.getElementById('habit-form-container');
  const habitsContainer = document.getElementById('habits-container');
  
  // Sample habits data (in a real app, this would come from localStorage or a database)
  let habits = [
    {
      id: '1',
      name: 'Morning Meditation',
      description: 'Start the day with 10 minutes of mindfulness',
      icon: {
        key: 'meditation',
        category: 'mindfulness'
      },
      frequency: 'daily',
      goal: 10,
      unit: 'minutes',
      createdDate: '2023-06-15T08:00:00.000Z',
      updatedDate: '2023-06-15T08:00:00.000Z'
    },
    {
      id: '2',
      name: 'Read a Book',
      description: 'Read at least 20 pages per day',
      icon: {
        key: 'reading',
        category: 'productivity'
      },
      frequency: 'daily',
      goal: 20,
      unit: 'pages',
      createdDate: '2023-06-16T10:30:00.000Z',
      updatedDate: '2023-06-16T10:30:00.000Z'
    }
  ];
  
  // Functions
  function renderHabits() {
    habitsContainer.innerHTML = '';
    
    if (habits.length === 0) {
      habitsContainer.innerHTML = `
        <div class="empty-state">
          <p>You don't have any habits yet. Create your first habit to get started!</p>
        </div>
      `;
      return;
    }
    
    habits.forEach(habit => {
      const habitElement = document.createElement('div');
      habitElement.classList.add('habit-card');
      habitElement.dataset.id = habit.id;
      
      // Get the actual SVG for the icon
      let iconSvg = '';
      try {
        const iconLibrary = window.IconLibrary || {}; // Ensure this is available globally
        iconSvg = iconLibrary[habit.icon.category].icons[habit.icon.key].svg;
      } catch (e) {
        console.warn(`Icon not found: ${habit.icon.key} in ${habit.icon.category}`);
        iconSvg = '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none"><circle cx="12" cy="12" r="10"></circle></svg>';
      }
      
      habitElement.innerHTML = `
        <div class="habit-icon">${iconSvg}</div>
        <div class="habit-details">
          <h3>${habit.name}</h3>
          <p>${habit.description || ''}</p>
          <div class="habit-meta">
            <span>${habit.frequency}</span>
            <span>${habit.goal} ${habit.unit}</span>
          </div>
        </div>
        <div class="habit-actions">
          <button class="edit-habit" data-id="${habit.id}">Edit</button>
          <button class="delete-habit" data-id="${habit.id}">Delete</button>
        </div>
      `;
      
      habitsContainer.appendChild(habitElement);
    });
    
    // Add event listeners for edit and delete buttons
    document.querySelectorAll('.edit-habit').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const habitId = e.target.dataset.id;
        const habit = habits.find(h => h.id === habitId);
        if (habit) {
          showHabitForm(habit);
        }
      });
    });
    
    document.querySelectorAll('.delete-habit').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const habitId = e.target.dataset.id;
        if (confirm('Are you sure you want to delete this habit?')) {
          habits = habits.filter(h => h.id !== habitId);
          saveHabits();
          renderHabits();
        }
      });
    });
  }
  
  function showHabitForm(habitData = null) {
    // Clear the form container first
    formContainer.innerHTML = '';
    
    // Initialize the habit form
    new HabitForm(formContainer, (newHabitData) => {
      // This is the callback that will be called when the form is submitted
      
      if (habitData) {
        // Edit existing habit
        const index = habits.findIndex(h => h.id === habitData.id);
        if (index !== -1) {
          habits[index] = newHabitData;
        }
      } else {
        // Add new habit
        habits.push(newHabitData);
      }
      
      // Save and render
      saveHabits();
      renderHabits();
      
      // Clear the form
      formContainer.innerHTML = '';
    }, habitData);
    
    // Show the form
    formContainer.style.display = 'block';
    
    // Add event listener for form cancellation
    formContainer.addEventListener('habit-form-cancelled', () => {
      formContainer.style.display = 'none';
    });
  }
  
  function saveHabits() {
    // In a real app, save to localStorage or send to a backend
    localStorage.setItem('habits', JSON.stringify(habits));
  }
  
  function loadHabits() {
    // In a real app, load from localStorage or fetch from a backend
    const savedHabits = localStorage.getItem('habits');
    if (savedHabits) {
      try {
        habits = JSON.parse(savedHabits);
      } catch (e) {
        console.error('Failed to parse saved habits:', e);
      }
    }
  }
  
  // Event Listeners
  newHabitBtn.addEventListener('click', () => {
    showHabitForm();
  });
  
  // Initialize
  loadHabits();
  renderHabits();
  
  // Make sure IconLibrary is available globally for the example
  // In a real app, you might handle this differently
  import('./icons.js').then(module => {
    window.IconLibrary = module.default;
  });
}); 