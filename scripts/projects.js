// Projects management script

// Store projects in localStorage
const PROJECTS_STORAGE_KEY = 'atomic_momentum_projects';

// Load projects from localStorage
function loadProjects() {
    const savedProjects = localStorage.getItem(PROJECTS_STORAGE_KEY);
    if (savedProjects) {
        try {
            return JSON.parse(savedProjects);
        } catch (e) {
            console.error('Error loading projects:', e);
            return [];
        }
    }
    return [];
}

// Save projects to localStorage
function saveProjects(projects) {
    try {
        localStorage.setItem(PROJECTS_STORAGE_KEY, JSON.stringify(projects));
    } catch (e) {
        console.error('Error saving projects:', e);
    }
}

// Create project element
function createProjectElement(project, onEdit, onDelete) {
    const projectEl = document.createElement('div');
    projectEl.className = 'project-card';
    projectEl.style.backgroundColor = 'white';
    projectEl.style.borderRadius = '8px';
    projectEl.style.boxShadow = '0 2px 4px rgba(0, 0, 0, 0.1)';
    projectEl.style.padding = '16px';
    projectEl.style.marginBottom = '16px';
    projectEl.style.display = 'flex';
    projectEl.style.justifyContent = 'space-between';
    projectEl.style.alignItems = 'center';
    projectEl.style.borderLeft = `4px solid ${project.color}`;
    
    // Project info
    const projectInfo = document.createElement('div');
    projectInfo.className = 'project-info';
    projectInfo.style.display = 'flex';
    projectInfo.style.alignItems = 'center';
    
    // Icon
    if (project.icon) {
        const icon = document.createElement('div');
        icon.className = 'project-icon';
        icon.style.marginRight = '12px';
        icon.style.width = '32px';
        icon.style.height = '32px';
        icon.style.borderRadius = '50%';
        icon.style.backgroundColor = project.color;
        icon.style.display = 'flex';
        icon.style.justifyContent = 'center';
        icon.style.alignItems = 'center';
        icon.style.color = 'white';
        
        const iconEl = document.createElement('i');
        iconEl.className = `fas fa-${project.icon}`;
        
        icon.appendChild(iconEl);
        projectInfo.appendChild(icon);
    }
    
    // Project name
    const name = document.createElement('h3');
    name.textContent = project.name;
    name.style.margin = '0';
    projectInfo.appendChild(name);
    
    // Actions
    const actions = document.createElement('div');
    actions.className = 'project-actions';
    actions.style.display = 'flex';
    actions.style.gap = '8px';
    
    // Edit button
    const editBtn = document.createElement('button');
    editBtn.innerHTML = '<i class="fas fa-edit"></i>';
    editBtn.title = 'Edit Project';
    editBtn.style.background = 'none';
    editBtn.style.border = 'none';
    editBtn.style.cursor = 'pointer';
    editBtn.style.fontSize = '16px';
    editBtn.style.color = '#666';
    editBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        onEdit(project);
    });
    
    // Delete button
    const deleteBtn = document.createElement('button');
    deleteBtn.innerHTML = '<i class="fas fa-trash"></i>';
    deleteBtn.title = 'Delete Project';
    deleteBtn.style.background = 'none';
    deleteBtn.style.border = 'none';
    deleteBtn.style.cursor = 'pointer';
    deleteBtn.style.fontSize = '16px';
    deleteBtn.style.color = '#d9534f';
    deleteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (confirm(`Are you sure you want to delete the project "${project.name}"?`)) {
            onDelete(project.id);
        }
    });
    
    actions.appendChild(editBtn);
    actions.appendChild(deleteBtn);
    
    projectEl.appendChild(projectInfo);
    projectEl.appendChild(actions);
    
    // Make entire card clickable to view project details
    projectEl.addEventListener('click', () => {
        // Navigate to project detail page or show project details
        console.log('View project:', project);
        // Replace with actual navigation or detail view code
    });
    
    return projectEl;
}

// Render all projects
function renderProjects() {
    const projects = loadProjects();
    const container = document.getElementById('projects-container');
    
    if (!container) {
        console.error('Projects container not found');
        return;
    }
    
    container.innerHTML = '';
    
    if (projects.length === 0) {
        const emptyMessage = document.createElement('div');
        emptyMessage.className = 'empty-projects';
        emptyMessage.textContent = 'No projects yet. Create your first project!';
        emptyMessage.style.textAlign = 'center';
        emptyMessage.style.padding = '32px';
        emptyMessage.style.color = '#666';
        container.appendChild(emptyMessage);
        return;
    }
    
    projects.forEach(project => {
        const projectEl = createProjectElement(
            project,
            // Edit callback
            (project) => {
                showEditProjectDialog(project);
            },
            // Delete callback
            (projectId) => {
                deleteProject(projectId);
            }
        );
        container.appendChild(projectEl);
    });
}

// Add new project
function addProject(project) {
    const projects = loadProjects();
    projects.push(project);
    saveProjects(projects);
    renderProjects();
}

// Update existing project
function updateProject(updatedProject) {
    const projects = loadProjects();
    const index = projects.findIndex(p => p.id === updatedProject.id);
    
    if (index !== -1) {
        projects[index] = {...projects[index], ...updatedProject};
        saveProjects(projects);
        renderProjects();
    }
}

// Delete project
function deleteProject(projectId) {
    const projects = loadProjects();
    const updatedProjects = projects.filter(p => p.id !== projectId);
    saveProjects(updatedProjects);
    renderProjects();
}

// Show dialog to create a new project
function showNewProjectDialog() {
    // Load the dialog component
    const dialog = new ProjectDialog(
        // Save callback
        (project) => {
            addProject(project);
        },
        // Cancel callback
        () => {
            console.log('Project creation canceled');
        }
    );
    
    dialog.open();
}

// Show dialog to edit an existing project
function showEditProjectDialog(project) {
    // Load the dialog component
    const dialog = new ProjectDialog(
        // Save callback
        (updatedProject) => {
            updateProject(updatedProject);
        },
        // Cancel callback
        () => {
            console.log('Project edit canceled');
        }
    );
    
    dialog.open(project);
}

// Initialize projects when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    renderProjects();
    
    // Set up "Add Project" button if it exists
    const addProjectBtn = document.getElementById('add-project-btn');
    if (addProjectBtn) {
        addProjectBtn.addEventListener('click', showNewProjectDialog);
    }
}); 