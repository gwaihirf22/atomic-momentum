# Contributing to Atomic Momentum

Thank you for your interest in contributing to Atomic Momentum! This document provides guidelines and instructions for contributing to this project.

## Development Environment Setup

1. Clone the repository:
```
git clone https://github.com/yourusername/atomic-momentum.git
```

2. Navigate to the project directory:
```
cd atomic-momentum
```

3. Run the application:
```
python server.py
```

## Project Structure

- `server.py`: Contains both the Python server and JavaScript application code
- `demo.html`: Generated HTML file (main application)
- `notifications-test.html`: Testing environment for notifications
- `README.md`: Project overview and documentation
- `PROJECT_STATUS.md`: Current status and recent updates
- `ROADMAP.md`: Planned features and improvements
- `.env.example`: Example environment variables for configuration

## Coding Standards

### JavaScript
- Use camelCase for variable and function names
- Add comments for complex logic sections
- Organize code into logical functions and sections
- Use descriptive variable names

### HTML/CSS
- Use meaningful class names
- Maintain responsive design principles
- Follow accessibility best practices

## Development Workflow

1. **Select a Task**: Choose an issue from the project board or create a new one for the feature/bug you want to work on.

2. **Create a Branch**: Create a new branch with a descriptive name:
   ```
   git checkout -b feature/your-feature-name
   ```
   or
   ```
   git checkout -b fix/issue-you-are-fixing
   ```

3. **Make Changes**: Implement your feature or fix the bug.

4. **Test Locally**: Test your changes thoroughly:
   - Verify that existing features still work
   - Test on different browsers if applicable
   - Check both light and dark themes
   - Test responsive behavior

5. **Document Changes**: Update relevant documentation:
   - Add comments to your code
   - Update README.md if needed
   - Add to PROJECT_STATUS.md for significant changes

6. **Commit Changes**: Make meaningful commits with clear messages:
   ```
   git commit -m "Add feature: description of your feature"
   ```
   or
   ```
   git commit -m "Fix: description of the issue fixed"
   ```

7. **Submit Pull Request**: Push your branch and create a pull request:
   ```
   git push origin feature/your-feature-name
   ```
   
## Current Development Focus

Please refer to the ROADMAP.md file for the current development priorities. Contributions that align with the short-term goals are especially welcome.

## Testing

When adding new features or fixing bugs, please ensure that:

1. The feature works as expected in both light and dark themes
2. The application remains responsive on different screen sizes
3. Browser compatibility is maintained (Chrome, Firefox, Safari)
4. Notifications functionality is tested in the dedicated environment

## Questions or Problems?

If you have any questions about contributing or encounter any issues, please open an issue on the repository and we'll be happy to help!