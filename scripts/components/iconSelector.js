import IconLibrary from '../icons.js';

class IconSelector {
    constructor(container, onSelectCallback) {
        this.container = container;
        this.onSelectCallback = onSelectCallback;
        this.selectedIcon = null;
        this.init();
    }

    init() {
        // Create the main container
        this.container.innerHTML = '';
        this.container.classList.add('icon-selector');

        // Create preview section
        const previewSection = document.createElement('div');
        previewSection.classList.add('icon-preview');
        previewSection.innerHTML = `
            <div class="preview-icon"></div>
            <span>Select an icon below</span>
        `;
        this.container.appendChild(previewSection);
        this.previewIconContainer = previewSection.querySelector('.preview-icon');

        // Create the scrollable icon grid
        const iconGrid = document.createElement('div');
        iconGrid.classList.add('icon-grid');
        this.container.appendChild(iconGrid);

        // Populate with icon categories
        this.populateIconGrid(iconGrid);
    }

    populateIconGrid(grid) {
        // Loop through each icon category
        Object.entries(IconLibrary).forEach(([categoryKey, category]) => {
            const categorySection = document.createElement('div');
            categorySection.classList.add('icon-category');
            
            // Add category title
            const categoryTitle = document.createElement('div');
            categoryTitle.classList.add('category-title');
            categoryTitle.textContent = category.name;
            categorySection.appendChild(categoryTitle);
            
            // Create icons container for this category
            const categoryIcons = document.createElement('div');
            categoryIcons.classList.add('category-icons');
            
            // Add all icons from this category
            Object.entries(category.icons).forEach(([iconKey, icon]) => {
                const iconItem = document.createElement('div');
                iconItem.classList.add('icon-item');
                iconItem.dataset.iconKey = iconKey;
                iconItem.dataset.category = categoryKey;
                
                // Set the inner HTML directly with the SVG
                iconItem.innerHTML = `
                    ${icon.svg}
                    <span class="icon-name">${icon.name}</span>
                `;
                
                // Add click event
                iconItem.addEventListener('click', () => this.selectIcon(iconItem, iconKey, categoryKey));
                
                categoryIcons.appendChild(iconItem);
            });
            
            categorySection.appendChild(categoryIcons);
            grid.appendChild(categorySection);
        });
    }

    selectIcon(element, iconKey, category) {
        // Remove selected class from previously selected icon
        const previouslySelected = this.container.querySelector('.icon-item.selected');
        if (previouslySelected) {
            previouslySelected.classList.remove('selected');
        }
        
        // Add selected class to currently selected icon
        element.classList.add('selected');
        
        // Update the preview
        const iconData = IconLibrary[category].icons[iconKey];
        this.previewIconContainer.innerHTML = iconData.svg;
        
        // Set the selected icon
        this.selectedIcon = {
            key: iconKey,
            category: category,
            svg: iconData.svg,
            name: iconData.name
        };
        
        // Call the callback function with the selected icon data
        if (this.onSelectCallback) {
            this.onSelectCallback(this.selectedIcon);
        }
    }

    // Set an icon programmatically
    setIcon(iconKey, category) {
        if (!iconKey || !category) return;
        
        // Find the icon element
        const iconElement = this.container.querySelector(`.icon-item[data-icon-key="${iconKey}"][data-category="${category}"]`);
        if (iconElement) {
            this.selectIcon(iconElement, iconKey, category);
        } else {
            console.warn(`Icon not found: ${iconKey} in category ${category}`);
        }
    }
    
    // Get the currently selected icon
    getSelectedIcon() {
        return this.selectedIcon;
    }
    
    // Clear selection
    clearSelection() {
        const previouslySelected = this.container.querySelector('.icon-item.selected');
        if (previouslySelected) {
            previouslySelected.classList.remove('selected');
        }
        
        this.previewIconContainer.innerHTML = '';
        this.selectedIcon = null;
        
        if (this.onSelectCallback) {
            this.onSelectCallback(null);
        }
    }
}

export default IconSelector; 