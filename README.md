# kube-ctx-manager

> A smart shell plugin for kubectl power users — fuzzy context switching, auto-suggested aliases, and prod safeguards built right into your terminal.

![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-blue)
![Requires](https://img.shields.io/badge/requires-kubectl%20%7C%20fzf-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Why this exists

If you manage multiple Kubernetes clusters daily, you've probably:

- Accidentally run `kubectl delete` on prod instead of staging
- Spent 30 seconds typing `kubectl config use-context arn:aws:eks:ap-south-1:...` 
- Forgotten your own aliases halfway through a sprint

`kube-ctx-manager` fixes all three. It's a single shell plugin — no daemon, no agent, no background process.

---

## Features

| Feature | What it does |
|---|---|
| **Fuzzy context switcher** | `kx` opens an fzf picker across all your kubeconfig contexts |
| **Alias suggester** | Watches your kubectl usage and suggests aliases for long commands you repeat |
| **Prod safeguard** | Any destructive command against a `prod`/`production`/`live` context requires explicit confirmation |
| **Namespace switcher** | `kns` fuzzy-picks namespaces within the current context |
| **Context label** | Injects current context + namespace into your shell prompt (PS1/RPROMPT) |
| **Audit log** | Every kubectl command against a prod context is appended to `~/.kube/audit.log` |
| **Health monitoring** | `khealth` checks cluster connectivity and response times |
| **Kubeconfig merging** | `kube-merge` combines multiple kubeconfig files safely |
| **Backup & restore** | `kube-backup` creates and restores kubeconfig backups |
| **Advanced search** | `ksearch` finds contexts by name, cluster, user, or pattern |
| **Context bookmarks** | `kbookmark` saves favorite contexts with descriptions |
| **Resource monitoring** | `kmonitor` shows cluster resource usage and health |
| **Command analytics** | `kanalytics` tracks usage patterns and generates reports |

---

## Requirements

- `kubectl` ≥ 1.24
- [`fzf`](https://github.com/junegunn/fzf) ≥ 0.35
- Bash 4+ or Zsh 5+

### Optional Dependencies

- `yq` - For enhanced kubeconfig merging and validation
- `jq` - For JSON processing in analytics and monitoring
- `bats-core` - For running tests
- `shellcheck` - For code linting

---

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/NotHarshhaa/kube-ctx-manager/master/install.sh | bash
```

### Manual

```bash
git clone https://github.com/NotHarshhaa/kube-ctx-manager.git
cd kube-ctx-manager
./install.sh
```

The installer adds a source line to your `.bashrc` or `.zshrc` automatically.

### Oh My Zsh plugin

```bash
git clone https://github.com/NotHarshhaa/kube-ctx-manager.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/kube-ctx-manager

# Add to your .zshrc plugins list:
plugins=(... kube-ctx-manager)
```

---

## Usage

### Context switching

```bash
kx                  # fuzzy pick from all contexts
kx staging          # switch directly if name matches
kx -                # switch back to previous context
```

### Namespace switching

```bash
kns                 # fuzzy pick namespace in current context
kns kube-system     # switch directly
```

### Suggested aliases

After you source the plugin, it silently tracks commands you type more than 3 times. Run:

```bash
kube-suggest        # prints alias recommendations to stdout
kube-suggest --apply  # writes them to ~/.kube-aliases and sources automatically
```

Example output:

```
You've run this 7 times:
  kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp

Suggested alias:
  alias kgpm='kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp'

Run `kube-suggest --apply` to add it.
```

### Prod safeguard

Destructive verbs (`delete`, `drain`, `cordon`, `scale`, `rollout restart`) against a context matching your configured prod pattern require a confirmation prompt:

```
⚠️  You are about to run a destructive command against context: prod-eks-ap-south-1

  kubectl delete pod api-server-7d9f4b -n default

Type the context name to confirm: _
```

If you mistype or press Ctrl+C, the command is blocked and nothing is sent to the cluster.

### Audit commands

```bash
kube-audit           # show recent audit entries
kube-audit-search delete  # search audit log for specific patterns
kube-audit-stats     # show audit statistics
```

---

## Advanced Features

### Health Monitoring

```bash
khealth                    # Check all contexts health
khealth-quick             # Quick health check for current context
khealth-watch             # Monitor context health continuously
khealth-clean             # Clean health cache
```

### Kubeconfig Management

```bash
# Merge multiple configs
kube-merge merged-config.yaml config1.yaml config2.yaml
kube-merge-env            # Merge from KUBECONFIG env var

# Backup and restore
kube-backup               # Create backup
kube-backup-list          # List backups
kube-backup-restore name  # Restore from backup
kube-backup-clean         # Clean old backups

# Split configs by environment
kube-split                # Split kubeconfig by patterns
```

### Advanced Search

```bash
ksearch pattern            # Search contexts by pattern
ksearch-advanced          # Multi-criteria search
ksearch-env prod          # Search by environment
ksearch-provider eks      # Search by cloud provider
ksearch-region us-east-1  # Search by region
ksearch-interactive       # Interactive fzf search
```

### Context Bookmarks

```bash
kbookmark-add prod-main prod-eks-main "Production cluster" "prod,eks"
kbookmark-list            # List all bookmarks
kbookmark-go prod-main    # Switch to bookmarked context
kbookmark-search pattern  # Search bookmarks
kbookmark-interactive     # Interactive bookmark selection
```

### Resource Monitoring

```bash
kmonitor                  # Cluster overview
kmonitor-resource pods    # Monitor specific resource
kmonitor-watch pods       # Watch resources in real-time
kmonitor-metrics          # Show resource usage
kmonitor-health           # Cluster health score
```

### Command Analytics

```bash
kanalytics-stats          # Show usage statistics
kanalytics-timeline       # Command timeline
kanalytics-report         # Generate reports
kanalytics-export         # Export analytics data
kanalytics-suggest        # Suggest aliases based on usage
```

---

## Configuration

Set these in your `.bashrc` / `.zshrc` **before** sourcing the plugin:

```bash
# Contexts matching this regex are treated as prod (default: prod|production|live)
export KCM_PROD_PATTERN="prod|production|live|prd"

# Number of times a command must repeat before alias is suggested (default: 3)
export KCM_SUGGEST_THRESHOLD=3

# Audit log location (default: ~/.kube/audit.log)
export KCM_AUDIT_LOG="$HOME/.kube/audit.log"

# Show context in prompt — set to 0 to disable (default: 1)
export KCM_PROMPT=1

# Prompt style: 'minimal' shows just context name, 'full' shows context:namespace
export KCM_PROMPT_STYLE="full"
```

---

## Repo structure

```
kube-ctx-manager/
├── kube-ctx-manager.plugin.zsh   # Main plugin (Zsh entry point)
├── kube-ctx-manager.bash         # Bash entry point
├── lib/
│   ├── context.sh                # kx and kns logic
│   ├── safeguard.sh              # Prod confirmation wrapper
│   ├── suggester.sh              # Alias usage tracking and suggestions
│   ├── prompt.sh                 # PS1/RPROMPT injection
│   ├── audit.sh                  # Audit logging
│   ├── health.sh                 # Health monitoring
│   ├── merge.sh                  # Kubeconfig merging
│   ├── backup.sh                 # Backup and restore
│   ├── search.sh                 # Advanced search
│   ├── bookmarks.sh              # Context bookmarks
│   ├── monitor.sh                # Resource monitoring
│   └── analytics.sh              # Command analytics
├── install.sh                    # Installer script
├── uninstall.sh                  # Clean removal
├── tests/
│   ├── test_context.sh
│   ├── test_safeguard.sh
│   ├── test_suggester.sh
│   └── test_helper.bash
└── README.md
```

---

## Development

```bash
# Run tests (requires bats-core)
brew install bats-core
bats tests/

# Lint
shellcheck lib/*.sh

# Test locally
source ./kube-ctx-manager.bash  # or .zsh for Zsh
kx
```

### Running tests

```bash
# Install test dependencies
brew install bats-core

# Run all tests
bats tests/

# Run specific test file
bats tests/test_context.sh

# Run with verbose output
bats -t tests/
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run `shellcheck lib/*.sh` and fix any issues
6. Run `bats tests/` and ensure all tests pass
7. Submit a pull request

---

## Roadmap

- [ ] Homebrew tap for one-command install
- [ ] Fish shell support
- [ ] Multi-kubeconfig merging helper (`kube-merge`)
- [ ] Team-shared alias sync via a dotfiles-compatible format
- [ ] VS Code terminal integration (context badge in title bar)
- [ ] Helm release context awareness
- [ ] K9s integration
- [ ] Context health checks and auto-failover

---

## Troubleshooting

### Common Issues

**Plugin not loading**
- Ensure you've sourced the plugin in your shell config
- Restart your terminal or run `source ~/.bashrc` / `source ~/.zshrc`

**fzf not found**
- Install fzf: `brew install fzf` or `git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install`

**kubectl not found**
- Install kubectl: `brew install kubectl` or follow the [official installation guide](https://kubernetes.io/docs/tasks/tools/)

**Aliases not being suggested**
- Check your usage threshold: `echo $KCM_SUGGEST_THRESHOLD`
- Verify tracking file exists: `ls -la ~/.kube-usage`

**Prod safeguard not working**
- Check your prod pattern: `echo $KCM_PROD_PATTERN`
- Verify current context matches pattern: `kubectl config current-context`

### Debug Mode

Enable debug output by setting:

```bash
export KCM_DEBUG=1
```

This will show additional information about plugin operations.

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Credits

Inspired by various kubectl context management tools, but focused on being a lightweight, non-intrusive shell plugin that works out of the box.

---

## Support

- 🐛 [Report bugs](https://github.com/NotHarshhaa/kube-ctx-manager/issues)
- 💡 [Feature requests](https://github.com/NotHarshhaa/kube-ctx-manager/issues/new?template=feature_request.md)
- 💬 [Discussions](https://github.com/NotHarshhaa/kube-ctx-manager/discussions)
