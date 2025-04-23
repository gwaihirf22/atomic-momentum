import IconSelector from './iconSelector.js';

class HabitForm {
  constructor(container, onSubmit, habitData = null) {
    this.container = container;
    this.onSubmit = onSubmit;
    this.habitData = habitData; // For editing existing habits
    this.iconSelector = null;
    this.selectedIcon = null;
    
    this.init();
  }
  
  init() {
    this.render();
    this.setupEventListeners();
    
    // If editing a habit, populate form with existing data
    if (this.habitData) {
      this.populateForm();
    }
  }
  
  render() {
    this.container.innerHTML = `
      <form class="habit-form">
        <div class="form-header">
          <h2>${this.habitData ? 'Edit Habit' : 'Create New Habit'}</h2>
        </div>
        
        <div class="form-group">
          <label for="habit-name">Habit Name</label>
          <input type="text" id="habit-name" placeholder="e.g., Morning Meditation" required>
        </div>
        
        <div class="form-group">
          <label for="habit-description">Description (optional)</label>
          <textarea id="habit-description" placeholder="What does this habit involve?"></textarea>
        </div>
        
        <div class="form-group">
          <label>Icon</label>
          <div class="icon-selector-container"></div>
        </div>
        
        <div class="form-row">
          <div class="form-group">
            <label for="habit-frequency">Frequency</label>
            <select id="habit-frequency">
              <option value="daily">Daily</option>
              <option value="weekly">Weekly</option>
              <option value="monthly">Monthly</option>
              <option value="custom">Custom</option>
            </select>
          </div>
          
          <div class="form-group" id="frequency-days-container" style="display: none;">
            <label>Days</label>
            <div class="days-selector">
              <label class="day-checkbox"><input type="checkbox" value="1"><span>M</span></label>
              <label class="day-checkbox"><input type="checkbox" value="2"><span>T</span></label>
              <label class="day-checkbox"><input type="checkbox" value="3"><span>W</span></label>
              <label class="day-checkbox"><input type="checkbox" value="4"><span>T</span></label>
              <label class="day-checkbox"><input type="checkbox" value="5"><span>F</span></label>
              <label class="day-checkbox"><input type="checkbox" value="6"><span>S</span></label>
              <label class="day-checkbox"><input type="checkbox" value="0"><span>S</span></label>
            </div>
          </div>
        </div>
        
        <div class="form-row">
          <div class="form-group">
            <label for="habit-goal">Daily Goal</label>
            <input type="number" id="habit-goal" min="1" value="1">
          </div>
          
          <div class="form-group">
            <label for="habit-unit">Unit</label>
            <select id="habit-unit">
              <option value="times">times</option>
              <option value="minutes">minutes</option>
              <option value="hours">hours</option>
              <option value="pages">pages</option>
              <option value="glasses">glasses</option>
              <option value="steps">steps</option>
              <option value="custom">custom...</option>
            </select>
          </div>
        </div>
        
        <div class="form-group" id="custom-unit-container" style="display: none;">
          <label for="custom-unit">Custom Unit</label>
          <input type="text" id="custom-unit" placeholder="e.g., kilometers">
        </div>
        
        <div class="form-actions">
          <button type="button" class="btn-secondary" id="cancel-btn">Cancel</button>
          <button type="submit" class="btn-primary">Save Habit</button>
        </div>
      </form>
    `;
    
    // Initialize the icon selector
    const iconSelectorContainer = this.container.querySelector('.icon-selector-container');
    this.iconSelector = new IconSelector(iconSelectorContainer, (icon) => {
      this.selectedIcon = icon;
    });
  }
  
  setupEventListeners() {
    const form = this.container.querySelector('.habit-form');
    const frequencySelect = this.container.querySelector('#habit-frequency');
    const unitSelect = this.container.querySelector('#habit-unit');
    const cancelBtn = this.container.querySelector('#cancel-btn');
    
    // Show/hide days selector based on frequency
    frequencySelect.addEventListener('change', () => {
      const daysContainer = this.container.querySelector('#frequency-days-container');
      daysContainer.style.display = frequencySelect.value === 'custom' ? 'block' : 'none';
    });
    
    // Show/hide custom unit input
    unitSelect.addEventListener('change', () => {
      const customUnitContainer = this.container.querySelector('#custom-unit-container');
      customUnitContainer.style.display = unitSelect.value === 'custom' ? 'block' : 'none';
    });
    
    // Form submission
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      
      if (!this.validateForm()) {
        return;
      }
      
      const habitData = this.collectFormData();
      
      if (this.onSubmit) {
        this.onSubmit(habitData);
      }
    });
    
    // Cancel button
    cancelBtn.addEventListener('click', () => {
      // Clear the form or close modal
      this.container.innerHTML = '';
      
      // Dispatch a custom event that can be caught by the parent
      this.container.dispatchEvent(new CustomEvent('habit-form-cancelled'));
    });
  }
  
  validateForm() {
    const nameInput = this.container.querySelector('#habit-name');
    
    if (!nameInput.value.trim()) {
      alert('Please enter a habit name');
      nameInput.focus();
      return false;
    }
    
    if (!this.selectedIcon) {
      alert('Please select an icon for your habit');
      return false;
    }
    
    return true;
  }
  
  collectFormData() {
    const form = this.container.querySelector('.habit-form');
    const frequencySelect = this.container.querySelector('#habit-frequency');
    const unitSelect = this.container.querySelector('#habit-unit');
    
    // Get selected days if frequency is custom
    let selectedDays = [];
    if (frequencySelect.value === 'custom') {
      const dayCheckboxes = this.container.querySelectorAll('.day-checkbox input:checked');
      selectedDays = Array.from(dayCheckboxes).map(checkbox => parseInt(checkbox.value));
    }
    
    // Get the unit (custom or predefined)
    let unit = unitSelect.value;
    if (unit === 'custom') {
      unit = this.container.querySelector('#custom-unit').value.trim() || 'times';
    }
    
    // Build the habit data object
    const habitData = {
      id: this.habitData ? this.habitData.id : Date.now().toString(),
      name: this.container.querySelector('#habit-name').value.trim(),
      description: this.container.querySelector('#habit-description').value.trim(),
      icon: this.selectedIcon ? {
        key: this.selectedIcon.key,
        category: this.selectedIcon.category,
      } : null,
      frequency: frequencySelect.value,
      frequencyDays: selectedDays,
      goal: parseInt(this.container.querySelector('#habit-goal').value) || 1,
      unit: unit,
      createdDate: this.habitData ? this.habitData.createdDate : new Date().toISOString(),
      updatedDate: new Date().toISOString()
    };
    
    return habitData;
  }
  
  populateForm() {
    if (!this.habitData) return;
    
    // Set basic text inputs
    this.container.querySelector('#habit-name').value = this.habitData.name || '';
    this.container.querySelector('#habit-description').value = this.habitData.description || '';
    
    // Set frequency
    const frequencySelect = this.container.querySelector('#habit-frequency');
    frequencySelect.value = this.habitData.frequency || 'daily';
    
    // Show days selector if custom frequency
    if (this.habitData.frequency === 'custom') {
      this.container.querySelector('#frequency-days-container').style.display = 'block';
      
      // Check the appropriate day checkboxes
      if (this.habitData.frequencyDays && this.habitData.frequencyDays.length) {
        this.habitData.frequencyDays.forEach(day => {
          const checkbox = this.container.querySelector(`.day-checkbox input[value="${day}"]`);
          if (checkbox) checkbox.checked = true;
        });
      }
    }
    
    // Set goal and unit
    this.container.querySelector('#habit-goal').value = this.habitData.goal || 1;
    
    const unitSelect = this.container.querySelector('#habit-unit');
    const standardUnits = ['times', 'minutes', 'hours', 'pages', 'glasses', 'steps'];
    
    if (standardUnits.includes(this.habitData.unit)) {
      unitSelect.value = this.habitData.unit;
    } else {
      unitSelect.value = 'custom';
      this.container.querySelector('#custom-unit-container').style.display = 'block';
      this.container.querySelector('#custom-unit').value = this.habitData.unit || '';
    }
    
    // Set the icon if available
    if (this.habitData.icon && this.habitData.icon.key && this.habitData.icon.category) {
      this.iconSelector.setIcon(this.habitData.icon.key, this.habitData.icon.category);
      // Since setIcon triggers the callback, this.selectedIcon should be set automatically
    }
  }
}

export default HabitForm; 