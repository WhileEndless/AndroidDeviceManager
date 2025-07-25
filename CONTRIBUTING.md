# Contributing to Android Device Manager

First off, thank you for considering contributing to Android Device Manager! It's people like you that make Android Device Manager such a great tool.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct:
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples**
- **Describe the behavior you observed after following the steps**
- **Explain which behavior you expected to see instead and why**
- **Include screenshots if possible**
- **Include your system information:**
  - macOS version
  - Android Device Manager version
  - ADB version
  - Android device model and OS version

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a step-by-step description of the suggested enhancement**
- **Provide specific examples to demonstrate the steps**
- **Describe the current behavior and explain which behavior you expected**
- **Explain why this enhancement would be useful**

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. Ensure the test suite passes
4. Make sure your code follows the existing code style
5. Issue that pull request!

## Development Setup

### Prerequisites

- macOS 10.14 (Mojave) or later
- Xcode 12.0 or later
- Swift 5.3 or later
- ADB installed and in PATH

### Getting Started

1. Clone your fork:
```bash
git clone https://github.com/your-username/AndroidDeviceManager.git
cd AndroidDeviceManager
```

2. Build the project:
```bash
swift build
```

3. Run tests:
```bash
swift test
```

4. Build release version:
```bash
swift build -c release
```

## Code Style Guidelines

### Swift Style Guide

- Use 4 spaces for indentation
- Keep lines under 120 characters when possible
- Use descriptive variable and function names
- Follow Swift API Design Guidelines
- Add comments for complex logic
- Use `// MARK: -` to organize code sections

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

Example:
```
Add persistent shell session support

- Implement ShellSession class for managing persistent ADB shells
- Add ShellSessionManager singleton for session pooling
- Reduce overhead by reusing shell sessions
- Fix repeated root permission prompts

Fixes #123
```

### Code Organization

- **Models**: Data structures and types
- **Managers**: Business logic and orchestration
- **Services**: External service interfaces (ADB, shell)
- **Windows**: UI window controllers
- **Views**: Reusable UI components

## Testing

- Write unit tests for new functionality
- Ensure all tests pass before submitting PR
- Test on multiple Android devices if possible
- Test both USB and WiFi connections
- Verify root and non-root device behavior

## Documentation

- Update README.md if you change functionality
- Update CHANGELOG.md following Keep a Changelog format
- Add inline documentation for public APIs
- Include examples in documentation when helpful

## Release Process

1. Update version in:
   - `Info.plist` (CFBundleShortVersionString and CFBundleVersion)
   - `Sources/Models/AppInfo.swift`
2. Update CHANGELOG.md
3. Create a pull request
4. After merge, tag the release
5. Build and upload DMG to releases

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

Thank you for contributing!