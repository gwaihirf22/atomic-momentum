class IconSelector {
    constructor(containerId, onSelectCallback) {
        this.container = document.getElementById(containerId);
        this.onSelectCallback = onSelectCallback;
        this.selectedIcon = 'list-check'; // Default icon
        this.icons = [
            { id: 'list-check', name: 'Tasks' },
            { id: 'house', name: 'Home' },
            { id: 'briefcase', name: 'Work' },
            { id: 'book', name: 'Study' },
            { id: 'heart', name: 'Health' },
            { id: 'cart-shopping', name: 'Shopping' },
            { id: 'money-bill', name: 'Finance' },
            { id: 'utensils', name: 'Food' },
            { id: 'dumbbell', name: 'Fitness' },
            { id: 'gamepad', name: 'Games' },
            { id: 'music', name: 'Music' },
            { id: 'palette', name: 'Art' },
            { id: 'car', name: 'Travel' },
            { id: 'user', name: 'Personal' },
            { id: 'users', name: 'Family' },
            { id: 'calendar', name: 'Events' },
            { id: 'gift', name: 'Gifts' },
            { id: 'code', name: 'Coding' },
            { id: 'star', name: 'Important' },
            { id: 'phone', name: 'Calls' }
        ];
        
        this.init();
    }
    
    init() {
        if (!this.container) return;
        
        this.container.innerHTML = '';
        this.container.classList.add('icon-selector');
        
        this.renderPreview();
        this.renderIconGrid();
    }
    
    renderPreview() {
        const previewEl = document.createElement('div');
        previewEl.className = 'icon-preview';
        
        const selectedIcon = this.icons.find(icon => icon.id === this.selectedIcon);
        
        previewEl.innerHTML = `
            <i class="fas fa-${this.selectedIcon}"></i>
            <span>Selected: ${selectedIcon ? selectedIcon.name : 'None'}</span>
        `;
        
        this.container.appendChild(previewEl);
    }
    
    renderIconGrid() {
        const gridEl = document.createElement('div');
        gridEl.className = 'icon-grid';
        
        this.icons.forEach(icon => {
            const iconItem = document.createElement('div');
            iconItem.className = `icon-item${this.selectedIcon === icon.id ? ' selected' : ''}`;
            iconItem.dataset.iconId = icon.id;
            
            iconItem.innerHTML = `
                <i class="fas fa-${icon.id}"></i>
                <span>${icon.name}</span>
            `;
            
            iconItem.addEventListener('click', () => this.selectIcon(icon.id));
            gridEl.appendChild(iconItem);
        });
        
        this.container.appendChild(gridEl);
    }
    
    selectIcon(iconId) {
        this.selectedIcon = iconId;
        
        // Update UI to reflect selection
        const items = this.container.querySelectorAll('.icon-item');
        items.forEach(item => {
            if (item.dataset.iconId === iconId) {
                item.classList.add('selected');
            } else {
                item.classList.remove('selected');
            }
        });
        
        // Update preview
        const previewEl = this.container.querySelector('.icon-preview');
        const selectedIcon = this.icons.find(icon => icon.id === iconId);
        
        previewEl.innerHTML = `
            <i class="fas fa-${iconId}"></i>
            <span>Selected: ${selectedIcon ? selectedIcon.name : 'None'}</span>
        `;
        
        // Call the callback function with the selected icon
        if (typeof this.onSelectCallback === 'function') {
            this.onSelectCallback(iconId);
        }
    }
    
    getSelectedIcon() {
        return this.selectedIcon;
    }
    
    setSelectedIcon(iconId) {
        if (this.icons.some(icon => icon.id === iconId)) {
            this.selectIcon(iconId);
        }
    }
} 