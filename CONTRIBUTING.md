# Contributing to VTS

Thanks for taking the time to contribute to VTS (Voice to Text Service)!

VTS is a modern macOS speech-to-text application, and we welcome contributions that help improve the transcription experience for users.

## How to Contribute

### Reporting Issues

If you encounter a bug or have a feature request:

1. **Search existing issues** first to avoid duplicates
2. **Use the issue templates** when available
3. **Provide clear details** including:
   - macOS version
   - VTS version
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Console logs if relevant

### Code Contributions

#### Before You Start

1. **Fork the repository** and create a feature branch
2. **Check existing issues** - your idea might already be planned
3. **Consider opening an issue** to discuss major changes before implementation

#### Development Setup

1. **Clone your fork**:
   ```bash
   git clone https://github.com/your-username/VTS.git
   cd VTS
   ```

2. **Open in Xcode**:
   ```bash
   open VTSApp.xcodeproj
   ```

3. **Install dependencies**: Dependencies are managed via Swift Package Manager and should resolve automatically

#### Coding Guidelines

We follow Swift and SwiftUI best practices:

- **Architecture**: Maintain the existing clean architecture (Services, Providers, Protocols)
- **SwiftUI Patterns**: Use proper state management with `@StateObject`, `@ObservableObject`, etc.
- **Error Handling**: Use proper Swift error handling patterns

#### Adding New STT Providers

VTS supports multiple speech-to-text providers. To add a new one:

1. **Implement `STTProvider` protocol** in `VTSApp/VTS/Providers/`
2. **Add to `STTProviderType` enum** in `TranscriptionModels.swift`
3. **Update provider selection UI** in `ContentView.swift`
5. **Update documentation** including README and provider-specific setup

#### Testing

- **Test on a real macOS device** and add screenshots or videos to the Pull Request description
- **Include edge cases** - network failures, permission denied, etc.

#### Pull Request Guidelines

1. **Create a clear title** describing the change
5. **Keep changes focused** - one feature/fix per PR

### Code Review Process

1. **All PRs require review** by a maintainer
2. **Address feedback** and be open to suggestions
3. **Keep discussions respectful** and focused on the code
4. **Squash commits** if requested before merge

## Project Structure

Understanding the codebase structure helps with contributions:

```
VTS/
├── VTSApp/                   # SwiftUI application
│   ├── VTSApp.swift          # App entry point
│   ├── ContentView.swift     # Main UI
│   └── VTS/                  # Core library
│       ├── Services/         # Core services (CaptureEngine, etc.)
│       ├── Providers/        # STT provider implementations
│       ├── Protocols/        # Provider abstraction
│       ├── Models/           # Data models
│       └── Extensions/       # Utility extensions
```

## Areas We'd Love Help With

- **New STT Providers**: Support for additional APIs
- **Localization**: Support for other languages in the UI
- **Performance**: Optimization for better real-time performance
- **Documentation**: Improve setup guides and API documentation
- **Testing**: Expand test coverage and edge case handling

## Questions?

- **Open an issue** for general questions
- **Check existing discussions** in the Issues section
- **Review the README** for basic setup and usage

## Recognition

Contributors who make significant improvements will be recognized in:
- Release notes for major contributions
- README contributors section (coming soon)

Thank you for contributing to VTS and helping make voice transcription better for the macOS community!

## License

By contributing to VTS you agree that your contributions will be licensed under its MIT license.

---

**Note**: This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to abide by its terms. 