class ProjectDialog {
    constructor(onSave, onCancel) {
        this.onSave = onSave || function() {};
        this.onCancel = onCancel || function() {};
        this.project = null;
        this.isEdit = false;
        this.selectedIcon = 'list-check';
        this.iconSelector = null;
    }
    
    open(project = null) {
        this.project = project;
        this.isEdit = !!project;
        
        this.createDialog();
        this.setupIconSelector();
        
        if (this.isEdit) {
            this.populateForm();
        }
        
        document.body.appendChild(this.dialogElement);
    }
    
    createDialog() {
        // Create overlay
        this.dialogElement = document.createElement('div');
        this.dialogElement.className = 'dialog-overlay';
        this.dialogElement.style.position = 'fixed';
        this.dialogElement.style.top = '0';
        this.dialogElement.style.left = '0';
        this.dialogElement.style.width = '100%';
        this.dialogElement.style.height = '100%';
        this.dialogElement.style.backgroundColor = 'rgba(0, 0, 0, 0.5)';
        this.dialogElement.style.display = 'flex';
        this.dialogElement.style.justifyContent = 'center';
        this.dialogElement.style.alignItems = 'center';
        this.dialogElement.style.zIndex = '1000';
        
        // Create dialog content
        const dialog = document.createElement('div');
        dialog.className = 'dialog';
        dialog.style.backgroundColor = 'white';
        dialog.style.borderRadius = '8px';
        dialog.style.boxShadow = '0 2px 10px rgba(0, 0, 0, 0.2)';
        dialog.style.width = '90%';
        dialog.style.maxWidth = '500px';
        dialog.style.maxHeight = '90vh';
        dialog.style.overflow = 'auto';
        dialog.style.display = 'flex';
        dialog.style.flexDirection = 'column';
        dialog.style.padding = '0';
        
        // Dialog header
        const header = document.createElement('div');
        header.className = 'dialog-header';
        header.style.padding = '16px';
        header.style.borderBottom = '1px solid #eee';
        header.style.display = 'flex';
        header.style.justifyContent = 'space-between';
        header.style.alignItems = 'center';
        
        const title = document.createElement('h2');
        title.textContent = this.isEdit ? 'Edit Project' : 'Create Project';
        title.style.margin = '0';
        title.style.fontSize = '18px';
        
        const closeButton = document.createElement('button');
        closeButton.innerHTML = '&times;';
        closeButton.style.background = 'none';
        closeButton.style.border = 'none';
        closeButton.style.fontSize = '24px';
        closeButton.style.cursor = 'pointer';
        closeButton.style.padding = '0';
        closeButton.style.lineHeight = '1';
        closeButton.addEventListener('click', () => this.close());
        
        header.appendChild(title);
        header.appendChild(closeButton);
        
        // Dialog content
        const content = document.createElement('div');
        content.className = 'dialog-content';
        content.style.padding = '16px';
        
        // Form elements
        const form = document.createElement('form');
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleSave();
        });
        
        // Project name
        const nameGroup = document.createElement('div');
        nameGroup.className = 'form-group';
        nameGroup.style.marginBottom = '16px';
        
        const nameLabel = document.createElement('label');
        nameLabel.htmlFor = 'project-name';
        nameLabel.textContent = 'Project Name';
        nameLabel.style.display = 'block';
        nameLabel.style.marginBottom = '8px';
        nameLabel.style.fontWeight = 'bold';
        
        const nameInput = document.createElement('input');
        nameInput.type = 'text';
        nameInput.id = 'project-name';
        nameInput.placeholder = 'Enter project name';
        nameInput.required = true;
        nameInput.style.width = '100%';
        nameInput.style.padding = '8px';
        nameInput.style.borderRadius = '4px';
        nameInput.style.border = '1px solid #ddd';
        nameInput.style.boxSizing = 'border-box';
        
        nameGroup.appendChild(nameLabel);
        nameGroup.appendChild(nameInput);
        
        // Icon selector container
        const iconGroup = document.createElement('div');
        iconGroup.className = 'form-group';
        iconGroup.style.marginBottom = '16px';
        
        const iconLabel = document.createElement('label');
        iconLabel.textContent = 'Project Icon';
        iconLabel.style.display = 'block';
        iconLabel.style.marginBottom = '8px';
        iconLabel.style.fontWeight = 'bold';
        
        const iconContainer = document.createElement('div');
        iconContainer.id = 'icon-selector-container';
        
        iconGroup.appendChild(iconLabel);
        iconGroup.appendChild(iconContainer);
        
        // Add color picker
        const colorGroup = document.createElement('div');
        colorGroup.className = 'form-group';
        colorGroup.style.marginBottom = '16px';
        
        const colorLabel = document.createElement('label');
        colorLabel.htmlFor = 'project-color';
        colorLabel.textContent = 'Project Color';
        colorLabel.style.display = 'block';
        colorLabel.style.marginBottom = '8px';
        colorLabel.style.fontWeight = 'bold';
        
        const colorInput = document.createElement('input');
        colorInput.type = 'color';
        colorInput.id = 'project-color';
        colorInput.style.width = '100%';
        colorInput.style.height = '40px';
        colorInput.style.border = 'none';
        colorInput.style.borderRadius = '4px';
        colorInput.style.cursor = 'pointer';
        colorInput.style.padding = '0';
        colorInput.value = '#4A6FDC';
        
        colorGroup.appendChild(colorLabel);
        colorGroup.appendChild(colorInput);
        
        // Form actions
        const actions = document.createElement('div');
        actions.className = 'form-actions';
        actions.style.display = 'flex';
        actions.style.justifyContent = 'flex-end';
        actions.style.gap = '8px';
        actions.style.marginTop = '24px';
        
        const cancelButton = document.createElement('button');
        cancelButton.type = 'button';
        cancelButton.textContent = 'Cancel';
        cancelButton.style.padding = '8px 16px';
        cancelButton.style.border = '1px solid #ddd';
        cancelButton.style.borderRadius = '4px';
        cancelButton.style.backgroundColor = '#f5f5f5';
        cancelButton.style.cursor = 'pointer';
        cancelButton.addEventListener('click', () => this.close());
        
        const saveButton = document.createElement('button');
        saveButton.type = 'submit';
        saveButton.textContent = this.isEdit ? 'Save Changes' : 'Create Project';
        saveButton.style.padding = '8px 16px';
        saveButton.style.border = 'none';
        saveButton.style.borderRadius = '4px';
        saveButton.style.backgroundColor = '#4A6FDC';
        saveButton.style.color = 'white';
        saveButton.style.cursor = 'pointer';
        
        actions.appendChild(cancelButton);
        actions.appendChild(saveButton);
        
        // Assemble form
        form.appendChild(nameGroup);
        form.appendChild(iconGroup);
        form.appendChild(colorGroup);
        form.appendChild(actions);
        
        content.appendChild(form);
        
        // Add content to dialog
        dialog.appendChild(header);
        dialog.appendChild(content);
        
        this.dialogElement.appendChild(dialog);
        this.form = form;
        this.nameInput = nameInput;
        this.colorInput = colorInput;
    }
    
    setupIconSelector() {
        // Wait for the DOM to be fully loaded
        setTimeout(() => {
            // Initialize the icon selector
            this.iconSelector = new IconSelector('icon-selector-container', (iconId) => {
                this.selectedIcon = iconId;
            });
            
            // If editing, set the selected icon
            if (this.isEdit && this.project.icon) {
                this.iconSelector.setSelectedIcon(this.project.icon);
            }
        }, 0);
    }
    
    populateForm() {
        if (!this.project) return;
        
        this.nameInput.value = this.project.name || '';
        this.colorInput.value = this.project.color || '#4A6FDC';
        this.selectedIcon = this.project.icon || 'list-check';
    }
    
    handleSave() {
        // Validate form
        if (!this.nameInput.value.trim()) {
            alert('Please enter a project name');
            return;
        }
        
        const projectData = {
            name: this.nameInput.value.trim(),
            color: this.colorInput.value,
            icon: this.selectedIcon
        };
        
        if (this.isEdit && this.project.id) {
            projectData.id = this.project.id;
        } else {
            projectData.id = 'project_' + Date.now(); // Generate a unique ID
            projectData.tasks = [];
            projectData.createdAt = new Date().toISOString();
        }
        
        this.onSave(projectData);
        this.close();
    }
    
    close() {
        if (this.dialogElement && this.dialogElement.parentNode) {
            this.dialogElement.parentNode.removeChild(this.dialogElement);
        }
        this.onCancel();
    }
} 