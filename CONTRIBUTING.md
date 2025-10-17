# Contributing to eBPF Packet Duplication System

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what's best for the community

## How to Contribute

### Reporting Bugs

Open an issue with:
- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Environment details (kernel version, OS, etc.)

### Suggesting Enhancements

Open an issue with:
- Clear description of the enhancement
- Use cases and benefits
- Potential implementation approach

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes**:
   - Follow the coding style
   - Add tests if applicable
   - Update documentation
4. **Test your changes**:
   ```bash
   make clean
   make build
   ./scripts/setup.sh
   # Test your changes
   ./scripts/cleanup.sh
   ```
5. **Commit with clear messages**: 
   ```
   Add feature X for Y
   
   - Implement functionality Z
   - Update documentation
   - Add tests
   ```
6. **Push to your fork**: `git push origin feature/your-feature`
7. **Open a Pull Request**

## Coding Standards

### eBPF C Code

- Follow Linux kernel coding style
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and small

### Go Code

- Follow standard Go conventions
- Run `go fmt` before committing
- Add error handling
- Use meaningful variable names

### Scripts

- Include shebang (`#!/bin/bash`)
- Add error handling (`set -e`)
- Use meaningful variable names
- Add comments for complex logic

### Documentation

- Use Markdown format
- Include code examples
- Keep language clear and concise
- Update relevant docs when changing code

## Testing

- Test on a clean environment
- Verify eBPF program loads without errors
- Check packet duplication works as expected
- Ensure statistics are accurate
- Test cleanup completes successfully

## Project Structure

```
.
├── src/           # eBPF C programs
├── cmd/           # Go applications
├── scripts/       # Automation scripts
├── docs/          # Documentation
└── compose.yaml   # Docker setup
```

## Questions?

Open an issue for questions or discussions.

Thank you for contributing!
