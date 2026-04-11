# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Unreleased

### Added
- **Context History & Favorites**
  - Track recent context switches with `khist`
  - Save favorite contexts with `kfav-add` and quick-switch with `kfav`
  - Context statistics with `kstats`
  - Configurable history and favorites limits

- **Enhanced Safeguard**
  - Dry-run mode with `k-dry-run` for safe testing
  - Configurable destructive verbs via `KCM_DESTRUCTIVE_VERBS`
  - Multiple confirmation modes: strict, simple, none
  - Extended destructive verb list (includes exec, attach, patch)

- **Quick Resource Actions**
  - `kshell` - Quick pod shell access with fuzzy selection
  - `klogs` - Pod log viewing with follow mode
  - `kpf` - Port-forwarding helper
  - `kdesc` - Quick resource describe
  - `kget` - Quick resource listing
  - `kdel` - Safe resource deletion with confirmation
  - `kscale` - Deployment scaling
  - `krestart` - Deployment restart
  - `kevents` - Event viewer
  - `ktop` - Resource usage monitoring
  - `kconfig` - Kubeconfig viewer

- **Context Groups**
  - Organize contexts by environment, team, or region
  - `kgroup-add` / `kgroup-remove` for group management
  - `kgroup-list` to view groups and contexts
  - `kgroup` for fuzzy selection within groups
  - `kgroup-auto` for automatic grouping by pattern

- **Command Templates**
  - Reusable command templates with variable substitution
  - 18+ built-in templates for common operations
  - `ktemplate` for interactive template execution
  - Custom template creation with `ktemplate-add`

- **Enhanced FZF Previews**
  - Context preview shows cluster, user, namespace, prod status, favorite status
  - Cluster connectivity check in context preview
  - Namespace preview shows resource counts and labels
  - Improved preview window layout

### Changed
- Enhanced context switcher with better preview information
- Enhanced namespace switcher with resource counts
- Improved fzf integration with better headers and prompts
- Updated configuration with new environment variables

### Fixed
- Better error handling in context switching
- Improved history tracking integration

## [1.0.0] - 2026-04-02

### Added
- Initial public release
- Fuzzy context switching with `kx` command
- Fuzzy namespace switching with `kns` command
- Production environment safeguards with confirmation prompts
- Automatic alias suggestion based on usage patterns
- Shell prompt integration showing current context and namespace
- Comprehensive audit logging for production commands
- Support for both Bash and Zsh shells
- Complete test suite with bats-core
- Installation and uninstallation scripts
- Health monitoring features
- Kubeconfig merging and backup
- Advanced search capabilities
- Context bookmarks
- Resource monitoring
- Command analytics
- Security features with data redaction

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
