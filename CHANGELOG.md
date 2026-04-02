# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of kube-ctx-manager
- Fuzzy context switching with `kx` command
- Fuzzy namespace switching with `kns` command
- Production environment safeguards with confirmation prompts
- Automatic alias suggestion based on usage patterns
- Shell prompt integration showing current context and namespace
- Comprehensive audit logging for production commands
- Support for both Bash and Zsh shells
- Complete test suite with bats-core
- Installation and uninstallation scripts

### Features
- **Context Management**
  - `kx` - Fuzzy context picker with fzf integration
  - `kx <context>` - Direct context switching
  - `kx -` - Switch back to previous context
  - Context tracking and history

- **Namespace Management**
  - `kns` - Fuzzy namespace picker
  - `kns <namespace>` - Direct namespace switching
  - Automatic namespace detection

- **Safety Features**
  - Production context detection via configurable regex patterns
  - Confirmation prompts for destructive commands
  - Audit logging of all production commands
  - Command blocking on failed confirmation

- **Alias Management**
  - Automatic usage tracking for kubectl commands
  - Intelligent alias generation based on command patterns
  - Configurable suggestion thresholds
  - Persistent alias storage

- **Shell Integration**
  - Bash and Zsh support
  - PS1/RPROMPT customization
  - Color-coded context indicators
  - Oh My Zsh plugin compatibility

### Configuration
- `KCM_PROD_PATTERN` - Regex pattern for production context detection
- `KCM_SUGGEST_THRESHOLD` - Minimum command repetitions for alias suggestions
- `KCM_AUDIT_LOG` - Location of audit log file
- `KCM_PROMPT` - Enable/disable prompt integration
- `KCM_PROMPT_STYLE` - Prompt display style (minimal/full)

### Security
- Production safeguards prevent accidental destructive operations
- Audit trail for all production commands
- Context confirmation requirements
- Safe command wrapping without modifying kubectl binary

## [1.0.0] - 2026-04-02

### Added
- Initial public release
- Complete feature set as described above
- Comprehensive documentation
- Full test coverage
- Installation scripts for easy setup

---

## Development Notes

### Testing
- Tests use bats-core framework
- Mock kubectl commands for isolated testing
- Comprehensive coverage of all major functions
- Helper utilities for common test patterns

### Contributing
- Code should pass shellcheck linting
- All new features should include tests
- Follow existing code style and patterns
- Update documentation for user-facing changes

### Compatibility
- Tested on macOS and Linux
- Requires Bash 4+ or Zsh 5+
- kubectl 1.24+ required
- fzf 0.35+ required for fuzzy selection
