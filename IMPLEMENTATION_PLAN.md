# Portify — Implementation Plan

> **Note:** This plan is designed for AI-assisted development (Codex/Claude Code). Estimates assume ~4-6x productivity gains on boilerplate and test scaffolding while accounting for macOS-specific edge cases requiring manual investigation.

## 1. Project Structure

```
portify/
├── Portify.xcodeproj/
├── Portify/
│   ├── App/
│   │   ├── PortifyApp.swift              # @main entry, NSStatusItem setup
│   │   ├── AppDelegate.swift             # NSApplicationDelegate for menu bar lifecycle
│   │   └── Constants.swift               # App-wide constants, OSLog categories
│   ├── Core/
│   │   ├── Protocols/                    # OS abstraction layer (testability)
│   │   │   ├── PortScanning.swift        # lsof abstraction
│   │   │   ├── ProcInfoProviding.swift   # proc_pidpath, proc_pidinfo
│   │   │   ├── SignalSending.swift       # kill(2) wrapper
│   │   │   ├── ConfigWatching.swift      # File system events
│   │   │   └── ProcessLaunching.swift    # Process() wrapper
│   │   ├── Scanner/
│   │   │   ├── LsofPortScanner.swift     # Production PortScanning impl
│   │   │   ├── LsofFParser.swift         # lsof -F state machine parser
│   │   │   └── DarwinProcInfo.swift      # Production ProcInfoProviding impl
│   │   ├── Classifier/
│   │   │   ├── ProcessClassifier.swift   # Binary name → ProcessType mapping
│   │   │   └── ProcessType.swift         # ProcessType enum
│   │   ├── Identifier/
│   │   │   ├── ProjectIdentifier.swift   # Manifest walking + name extraction
│   │   │   └── ManifestParser.swift      # Individual manifest file parsers
│   │   └── Models/
│   │       ├── DevServer.swift           # Core model with (pid,port) identity
│   │       ├── AppConfig.swift           # Configuration model (schemaVersion 1)
│   │       ├── PortOverride.swift        # Per-port override model
│   │       └── RawListeningPort.swift    # Scanner output model
│   ├── Services/
│   │   ├── ScanService.swift             # Swift actor, timer-driven, overlap-skip
│   │   ├── ConfigStore.swift             # Swift actor, directory-watch, migration
│   │   ├── ProcessKiller.swift           # PID revalidation + SIGTERM/SIGKILL
│   │   ├── PosixSignalSender.swift       # Production SignalSending impl
│   │   └── LaunchAtLogin.swift           # SMAppService wrapper
│   ├── ViewModels/
│   │   └── ServerListViewModel.swift     # @MainActor, drives the UI
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   ├── StatusItemController.swift # NSStatusItem + badge rendering
│   │   │   ├── PopoverView.swift          # Main dropdown content
│   │   │   ├── ServerRowView.swift        # Individual server row + context menu
│   │   │   └── EmptyStateView.swift       # No servers detected view
│   │   └── Settings/
│   │       ├── SettingsView.swift         # Settings window container
│   │       ├── GeneralSettingsView.swift  # General tab
│   │       ├── AppearanceSettingsView.swift # Appearance tab
│   │       └── AdvancedSettingsView.swift  # Advanced tab + hotkey permission flow
│   ├── Utilities/
│   │   ├── FoundationProcessLauncher.swift # Production ProcessLaunching impl
│   │   └── DirectoryConfigWatcher.swift    # Production ConfigWatching impl
│   └── Resources/
│       ├── Assets.xcassets/              # App icon, menu bar icon
│       ├── Portify.entitlements
│       └── Info.plist
├── PortifyTests/
│   ├── Mocks/                            # Test doubles for all protocols
│   │   ├── MockPortScanner.swift
│   │   ├── MockProcInfoProvider.swift
│   │   ├── MockSignalSender.swift
│   │   ├── MockConfigWatcher.swift
│   │   └── MockProcessLauncher.swift
│   ├── Core/
│   │   ├── LsofFParserTests.swift        # Fixtures for -F output
│   │   ├── ProcessClassifierTests.swift
│   │   ├── ProjectIdentifierTests.swift
│   │   └── ManifestParserTests.swift
│   ├── Services/
│   │   ├── ScanServiceTests.swift        # Overlap/backoff/degraded tests
│   │   ├── ConfigStoreTests.swift        # Migration/atomic-replace tests
│   │   └── ProcessKillerTests.swift      # PID reuse safety tests
│   └── ViewModels/
│       └── ServerListViewModelTests.swift
├── PortifyUITests/
│   ├── PortifyUITests.swift
│   └── TestHooks.swift                   # Debug commands for UI test reliability
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                        # Build + test on PR (macOS 14 + 15)
│   │   ├── release.yml                   # Build, sign, notarize, staple, release
│   │   └── lint.yml                      # SwiftLint
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── PULL_REQUEST_TEMPLATE.md
├── scripts/
│   ├── build.sh                          # Build universal binary
│   ├── notarize.sh                       # Notarization + staple script
│   ├── create-dmg.sh                     # DMG packaging
│   └── perf-check.sh                     # Performance gate script
├── Fixtures/                             # Test fixtures
│   ├── lsof-outputs/                     # Sample lsof -F outputs
│   └── manifest-dirs/                    # Sample project directories
├── Homebrew/
│   └── portify.rb                        # Homebrew Cask formula
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── LICENSE                               # MIT
├── CHANGELOG.md
├── .swiftlint.yml
└── .gitignore
```

---

## 2. Dependencies

**Runtime dependencies: ZERO.** Pure Swift + system frameworks only.

| Dependency | Type | Purpose |
|-----------|------|---------|
| SwiftUI | System | UI framework |
| AppKit | System | NSStatusItem, NSPopover |
| Foundation | System | Process, FileManager, JSONDecoder |
| ServiceManagement | System | SMAppService (launch at login) |
| Darwin | System | proc_pidpath, proc_pidinfo, signal, kill |
| OSLog | System | Structured logging |

**Dev dependencies:**

| Tool | Purpose |
|------|---------|
| SwiftLint | Code style enforcement (mandatory from day 1) |
| create-dmg | DMG creation for releases |
| Xcode 15+ | Build toolchain |

**No third-party packages.** This is intentional:
- Keeps binary tiny
- No supply chain risk
- No version conflicts
- macOS system frameworks provide everything needed

---

## 3. Phased Build Plan

### Phase 1: MVP (Core Detection + Menu Bar UI)

**Goal:** A working menu bar app that detects dev servers and displays them.

#### 1.0 — Protocol Boundaries & Safety Foundations (PREREQUISITE)
- [ ] Define `PortScanning` protocol — async scan returning `[RawListeningPort]`
- [ ] Define `ProcInfoProviding` protocol — pid → path, CWD, start time
- [ ] Define `SignalSending` protocol — send signal to pid, returns success/error
- [ ] Define `ConfigWatching` protocol — directory-level file change events
- [ ] Define `ProcessLaunching` protocol — run process with explicit URL + args + timeout
- [ ] Create mock implementations for all protocols
- [ ] Define `DevServer` identity model: `(pid, port)` tuple, deterministic SwiftUI id
- [ ] Define `AppConfig` model matching spec §7.1 schema exactly (schemaVersion 1)
- [ ] Set up OSLog categories: scanner, resolver, config, lifecycle, kill

**Effort:** 1.5 days

#### 1.1 — Project Setup
- [ ] Create Xcode project (macOS App, SwiftUI lifecycle)
- [ ] Configure as menu bar–only app (LSUIElement = true)
- [ ] Set up NSStatusItem with template icon
- [ ] Add SwiftLint config, enforce on all commits
- [ ] Set up GitHub repo with MIT license, .gitignore, README stub
- [ ] Set up CI workflow (build + lint) — gate from day 1

**Effort:** 1 day

#### 1.2 — Port Scanner (lsof -F)
- [ ] Implement `FoundationProcessLauncher` — `Process(executableURL:)` with timeout
- [ ] Implement `LsofFParser` — strict state machine for `-F pcn` field output:
  - `p` line starts new process context
  - `c` line sets command name
  - `n` line emits listening entry (parse address:port)
  - Unknown field prefixes logged and skipped (forward compat)
- [ ] Implement `LsofPortScanner` (production `PortScanning` impl):
  - Execute `/usr/sbin/lsof -F pcn -iTCP -sTCP:LISTEN -P -n`
  - Never use shell strings or `sh -c`
  - 2-second timeout
- [ ] IPv4+IPv6 deduplication: collapse same (pid, port) entries
- [ ] Write unit tests with fixtures:
  - Normal output (5 servers)
  - Empty output (no listeners)
  - Malformed lines (parser recovery)
  - IPv6-only, mixed IPv4/IPv6
  - Large output (100+ entries)

**Effort:** 2.5 days

#### 1.3 — Process Resolution & Classification
- [ ] Implement `DarwinProcInfo` (production `ProcInfoProviding` impl):
  - `proc_pidpath()` for binary path
  - `proc_pidinfo` with `PROC_PIDTBSDINFO` for start time
  - `proc_pidinfo` with `PROC_PIDVNODEPATHINFO` for CWD
- [ ] Implement `ProcessClassifier` — binary name → ProcessType mapping
- [ ] Write unit tests with mocked `ProcInfoProviding`:
  - Known binary names → correct ProcessType
  - Unknown binary → `.other`
  - Permission denied handling
  - Short-lived process (gone before resolution)

**Effort:** 1.5 days

#### 1.4 — Project Identification
- [ ] Implement `ProjectIdentifier` — walk directory tree for manifests
- [ ] Implement `ManifestParser` — parse package.json, Cargo.toml, go.mod, pyproject.toml, etc.
- [ ] Add caching layer (PID + CWD → project name)
- [ ] Fallback chain: manifest name → directory name → process name
- [ ] Write unit tests with fixture directories

**Effort:** 2 days

#### 1.5 — Scan Service (Actor-Based)
- [ ] Implement `ScanService` as Swift actor:
  - Timer-driven scan loop using `Task.sleep`
  - Non-overlapping scan policy (skip if in-progress)
  - Degraded mode: on failure, keep previous results
  - Backoff: double interval after 3 consecutive failures (max 30s)
  - Reset to normal on success
- [ ] Implement `ServerListViewModel` (`@MainActor`):
  - Diff old/new scan results
  - Stable identity via (pid, port)
  - Publish changes to UI
- [ ] Write tests for:
  - Overlap skip behavior
  - Backoff/reset logic
  - Diffing (added/removed/unchanged)

**Effort:** 2 days

#### 1.6 — Config Store (Actor-Based + Security)
- [ ] Implement `ConfigStore` as Swift actor:
  - Read/write `~/.config/portify/config.json`
  - Schema version validation (current: 1)
  - Migration registry (v0 → v1)
  - Unknown schema version → log warning, use defaults, don't overwrite
  - File permissions: `0600` on write
  - Canonical path validation before write (prevent symlink attacks)
- [ ] Implement `DirectoryConfigWatcher` (production `ConfigWatching` impl):
  - Watch parent directory, not file descriptor
  - Check mtime on event
  - Handle corrupt/partial JSON gracefully
- [ ] Serialize all updates through actor
- [ ] Write tests for:
  - Migration from v0 to v1
  - Future version handling
  - Atomic replace (temp file + rename)
  - Corrupt file recovery

**Effort:** 2 days

#### 1.7 — Menu Bar UI
- [ ] Implement `StatusItemController`:
  - NSStatusItem with template icon
  - Badge count rendered onto icon image
  - States: 0 (dim), 1-9 (count), 10+ ("9+")
- [ ] Implement `PopoverView`:
  - Server list with project name, port, type
  - Header with ⚙️ (settings) and ⟳ (refresh) buttons
  - Warning indicator when in degraded mode
- [ ] Implement `ServerRowView`:
  - Click → open `http://localhost:<port>`
  - Right-click context menu: Copy URL, Kill Process, Open in Terminal
  - Hover tooltip: full process path + PID
- [ ] Implement `EmptyStateView`
- [ ] Keyboard support:
  - Arrow keys navigate list (explicit focus management)
  - ⌘, opens Settings
  - ⌘Q quits
  - ⌘+click menu bar icon → force refresh

**Effort:** 2.5 days

#### 1.8 — Process Killer (PID Reuse Safety)
- [ ] Implement `ProcessKiller` with `SignalSending` protocol:
  1. Re-validate before SIGTERM:
     - Re-read `proc_pidpath(pid)` → must match stored `processPath`
     - Re-read process start time → must match stored `processStartTime`
     - If mismatch → abort with "Process has changed since listed. Refreshing..."
  2. Send SIGTERM
  3. Wait 2 seconds
  4. If still alive, prompt user for SIGKILL
  5. Re-validate again before SIGKILL (same checks)
  6. Only send SIGKILL with user confirmation + successful revalidation
- [ ] Implement `PosixSignalSender` (production `SignalSending` impl)
- [ ] Write tests with mocked SignalSending + ProcInfoProviding:
  - Normal kill flow
  - PID reuse detection (path changed)
  - PID reuse detection (start time changed)
  - Process already dead
  - SIGTERM insufficient, SIGKILL required

**Effort:** 1.5 days

#### 1.9 — Settings (Minimal MVP)
- [ ] Settings window with General tab:
  - Refresh interval (stepper: 1–30 seconds)
  - Launch at login (SMAppService)
  - Show in Dock toggle
  - Port range filter
- [ ] Config file location display with "Reveal in Finder"
- [ ] LSUIElement activation handling:
  - `NSApp.activate(ignoringOtherApps: true)`
  - Proper activation policy handling
- [ ] Hot-reload on config change

**Effort:** 1.5 days

#### 1.10 — Logging & Error Handling
- [ ] Instrument all OSLog categories per spec §8:
  - scanner: lsof execution, parsing, timing
  - resolver: proc_pidpath, CWD, failures
  - config: load, save, migration, watch
  - lifecycle: app start, activation, memory
  - kill: attempts, revalidation, results
- [ ] Privacy levels:
  - Process paths/PIDs: `.public`
  - Config values: `.private`
- [ ] `-PortifyDebug` launch arg enables `.debug` level
- [ ] Error handling per spec §10:
  - [ ] lsof not found → error message (should never happen)
  - [ ] lsof timeout → degraded mode + ⚠️ indicator
  - [ ] lsof permission denied → error message
  - [ ] PID disappears → remove on next scan
  - [ ] PID reuse at kill → abort + message
  - [ ] CWD unreadable → fallback to process name
  - [ ] Config corrupt → log + use defaults + toast
  - [ ] Config missing → create with defaults
  - [ ] Config schema too new → log + use defaults + don't overwrite
  - [ ] SIGTERM fails → prompt for SIGKILL
  - [ ] >100 ports → show first 50 + "and N more..."

**Effort:** 1.5 days

#### 1.11 — Polish, Accessibility & QA
- [ ] Accessibility:
  - All interactive elements have labels
  - VoiceOver: "Port 3000, project my-app, Node.js server. Actions available."
  - Explicit focus management in NSPopover-hosted SwiftUI
  - Semantic colors only (high contrast support)
  - macOS text scaling via system font metrics
  - Reduce Motion: standard SwiftUI transitions only
- [ ] Performance verification:
  - Memory < 15 MB idle
  - Memory < 25 MB with 20 servers
  - Scan cycle < 300ms
  - App launch to first scan < 500ms
  - Popover open < 50ms
  - Binary size < 5 MB
- [ ] Manual testing:
  - [ ] 0, 1, 5, 20, 50+ servers
  - [ ] Node, Python, Go, Ruby, Java mix
  - [ ] Kill via app
  - [ ] Open in browser
  - [ ] Config hot-reload
  - [ ] VoiceOver enabled
  - [ ] 1 hour idle (memory stability)
  - [ ] macOS 14 (Sonoma)
  - [ ] macOS 15 (Sequoia)

**Effort:** 2 days

**Phase 1 Total: ~14.5 days** (AI-assisted development assumed; macOS edge cases may add buffer)

---

### Phase 2: Power User Features

**Goal:** Settings, customization, and quality-of-life improvements.

#### 2.1 — Full Settings UI
- [ ] Appearance tab (sort order, show/hide labels)
- [ ] Advanced tab:
  - Additional process names to detect
  - Ignored ports
  - Port range filter
  - Global hotkey configuration (opt-in)
- [ ] Override management UI (custom labels per port)
- [ ] Reset to defaults

**Effort:** 2 days

#### 2.2 — Global Hotkey (Opt-In with Permission Flow)
- [ ] Settings toggle to enable (default: off)
- [ ] On enable, check `AXIsProcessTrusted()`
- [ ] If not trusted:
  - Show dialog explaining Accessibility permission requirement
  - Button to open System Settings → Privacy & Security → Accessibility
- [ ] If denied or revoked:
  - Disable hotkey
  - Show message: "Global hotkey requires Accessibility permission"
- [ ] Implementation: `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`
- [ ] NO `CGEvent` taps

**Effort:** 1.5 days

#### 2.3 — Favorites & Pinning
- [ ] Pin servers to top of list
- [ ] Persist pins in config
- [ ] Visual indicator for pinned servers
- [ ] Keyboard shortcut to pin/unpin

**Effort:** 1.5 days

#### 2.4 — Notifications
- [ ] Detect server start (new port in scan)
- [ ] Detect server stop (port disappears)
- [ ] macOS native notifications via UNUserNotificationCenter
- [ ] Toggle in settings (per-server or global)
- [ ] Debounce: don't notify during rapid restarts (500ms window)

**Effort:** 2 days

#### 2.5 — Grouping by Project
- [ ] Group servers sharing same project root
- [ ] Collapsible groups in dropdown
- [ ] Group header shows project name

**Effort:** 2 days

#### 2.6 — Custom Port Labels
- [ ] In-place editing: click project name to rename
- [ ] Persist to config overrides
- [ ] Clear override (revert to auto-detected)

**Effort:** 1 day

**Phase 2 Total: ~10 days**

---

### Phase 3: Ecosystem

**Goal:** Extend Portify beyond the menu bar.

#### 3.1 — CLI Companion (`portify` command)
- [ ] Swift CLI using ArgumentParser (separate target)
- [ ] `portify list` — JSON output
- [ ] `portify list --format table` — human-readable
- [ ] `portify kill <port>` — kill with same safety checks
- [ ] `portify open <port>` — open in browser
- [ ] Communicate via Unix domain socket (spec §12)
- [ ] Install via `portify install-cli` or Homebrew

**Effort:** 3 days

#### 3.2 — Raycast Extension
- [ ] TypeScript Raycast extension
- [ ] List servers command
- [ ] Open/Kill actions
- [ ] Communicate via CLI

**Effort:** 3 days

#### 3.3 — Homebrew Distribution
- [ ] Create Homebrew Cask formula
- [ ] Automate formula updates in release CI
- [ ] `brew install --cask portify`

**Effort:** 1 day

**Phase 3 Total: ~7 days**

---

## 4. Milestones & Timeline

| Milestone | Content | Estimated Effort |
|-----------|---------|-----------------|
| **M1: Foundations** | Protocols, models, OSLog setup, CI | 2.5 days |
| **M2: Scanner** | lsof -F parser, process resolution | 4 days |
| **M3: Core Services** | ScanService actor, ConfigStore actor | 4 days |
| **M4: UI** | Menu bar, popover, server rows | 4 days |
| **M5: Safety** | ProcessKiller with PID revalidation | 1.5 days |
| **M6: Settings** | Minimal settings, hot-reload | 1.5 days |
| **M7: Polish** | Logging, errors, accessibility, perf | 3.5 days |
| **M8: MVP Release** | v0.1.0 — DMG on GitHub Releases | included |
| **M9: Power User** | Hotkey, favorites, notifications, grouping | 10 days |
| **M10: v0.2.0** | Full settings, custom labels | included |
| **M11: CLI** | Companion CLI tool | 3 days |
| **M12: Ecosystem** | Raycast extension, Homebrew Cask | 4 days |

---

## 5. Testing Strategy

### 5.1 Unit Tests

**Coverage targets:** Core modules at 90%+, Services at 80%+.

| Module | Test approach |
|--------|--------------|
| `LsofFParser` | Fixture-based: sample `-F` outputs across macOS versions |
| `ProcessClassifier` | Table-driven: input binary → expected ProcessType |
| `ManifestParser` | Fixture directories with real manifest files |
| `ProjectIdentifier` | Mocked `ProcInfoProviding`, test walking + caching |
| `ScanService` | Mocked `PortScanning`, test overlap/backoff/degraded |
| `ConfigStore` | Test migration, atomic replace, corruption recovery, schema versioning |
| `ProcessKiller` | Mocked `SignalSending` + `ProcInfoProviding`, test PID reuse safety |
| `ServerListViewModel` | Test diffing: added/removed/unchanged, sort orders |

### 5.2 Integration Tests

- End-to-end: start real `python -m http.server 9876`, verify detection
- Config write → watch → reload cycle (atomic replace)
- Kill flow with real process

### 5.3 Safety-Critical Tests

- [ ] PID reuse race: process dies and PID reused between scan and kill
- [ ] Scan overlap: verify skip when scan in progress
- [ ] Backoff/reset: verify timing after consecutive failures
- [ ] IPv4+IPv6 dedup: verify single entry per (pid, port)
- [ ] Config atomic replace: verify watch detects rename-based writes
- [ ] Schema migration: v0 → v1 data preserved
- [ ] Unknown schema version: no data loss, no overwrite

### 5.4 UI Tests

XCUITest with test hooks for reliability:
- [ ] `--portify-test-open-popover` launch arg
- [ ] `--portify-test-open-settings` launch arg
- [ ] Tests verify view model state, not pixel positions
- [ ] Popover opens and shows server list
- [ ] Settings window opens
- [ ] Empty state displayed when no servers

### 5.5 Performance Tests

Script-based gates (`scripts/perf-check.sh`):
- [ ] Memory idle < 15 MB
- [ ] Scan cycle < 300ms (with 20 mock servers)
- [ ] Launch to first scan < 500ms
- [ ] Binary size < 5 MB

### 5.6 Manual Testing Checklist

- [ ] Launch with 0 servers running
- [ ] Launch with 5+ servers (Node, Python, Go mix)
- [ ] Kill a server via the app
- [ ] Open a server in browser
- [ ] Open in Terminal from context menu
- [ ] Change refresh interval, verify behavior
- [ ] Edit config.json manually, verify hot-reload
- [ ] Replace config.json atomically (editor save)
- [ ] Test with VoiceOver enabled
- [ ] Test keyboard navigation in popover
- [ ] Run for 1 hour, check memory stability
- [ ] Test on macOS 14 (Sonoma)
- [ ] Test on macOS 15 (Sequoia)

---

## 6. CI/CD Setup

### 6.1 CI Pipeline (GitHub Actions)

**`ci.yml`** — Runs on every PR and push to `main`:

```yaml
name: CI
on: [push, pull_request]
jobs:
  build-and-test:
    strategy:
      matrix:
        os: [macos-14, macos-15]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: xcodebuild build -scheme Portify -destination 'platform=macOS'
      - name: Test
        run: xcodebuild test -scheme Portify -destination 'platform=macOS'
      - name: Lint
        run: swiftlint lint --strict
      - name: Performance Check
        run: ./scripts/perf-check.sh
```

**`release.yml`** — Triggered by git tag `v*`:

```yaml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build Universal Binary
        run: ./scripts/build.sh
      - name: Sign with Hardened Runtime
        run: |
          codesign --deep --force --options runtime \
            --sign "$SIGNING_IDENTITY" Portify.app
      - name: Notarize
        run: ./scripts/notarize.sh
      - name: Staple & Validate
        run: |
          xcrun stapler staple Portify.app
          xcrun stapler validate Portify.app
      - name: Gatekeeper Assessment
        run: spctl --assess --verbose Portify.app
      - name: Create DMG
        run: ./scripts/create-dmg.sh
      - name: Generate Checksums
        run: |
          shasum -a 256 Portify-*.dmg > checksums.txt
      - name: GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            Portify-*.dmg
            checksums.txt
          generate_release_notes: true
```

### 6.2 Code Signing & Notarization

- Sign with Developer ID certificate + Hardened Runtime (`--options runtime`)
- Notarize with `notarytool`
- Staple the ticket to app bundle and DMG
- Validate staple before release
- Gatekeeper assessment (`spctl --assess`)
- Store signing credentials as GitHub Secrets
- Publish SHA-256 checksums with release

---

## 7. Release & Distribution Plan

### 7.1 Distribution Channels

| Channel | Format | When |
|---------|--------|------|
| GitHub Releases | DMG (universal binary, arm64 + x86_64) + checksums | Every tagged release |
| Homebrew Cask | `brew install --cask portify` | After v0.1.0 stable |
| Direct download | Link from README → GitHub Releases | Always |

### 7.2 Version Scheme

Semantic versioning: `MAJOR.MINOR.PATCH`

- `0.1.0` — MVP release
- `0.2.0` — Power user features
- `0.3.0` — CLI + ecosystem
- `1.0.0` — Stable, battle-tested

### 7.3 Update Mechanism

No auto-update in v0.x. Users check GitHub Releases or `brew upgrade`.

Post-1.0, consider [Sparkle](https://sparkle-project.org/) with user-initiated checks only.

### 7.4 System Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel (universal binary)
- `lsof` is built into macOS at `/usr/sbin/lsof` — no additional tools required

---

## 8. Contribution Guidelines Structure

`CONTRIBUTING.md` will cover:

1. **Getting Started**
   - Clone repo
   - Open `Portify.xcodeproj` in Xcode 15+
   - Build and run (⌘R)
   - No external dependencies to install

2. **Development Workflow**
   - Fork → branch → PR
   - Branch naming: `feature/description`, `fix/description`
   - Keep PRs focused
   - Write tests for new functionality
   - SwiftLint must pass

3. **Code Style**
   - SwiftLint enforced (CI gates on violations)
   - Protocol-first for OS interactions
   - Actor-based concurrency for shared state
   - Use OSLog, not print statements

4. **Testing**
   - Run tests: `⌘U` in Xcode or `xcodebuild test`
   - New features require unit tests
   - Safety-critical paths require integration tests
   - Bug fixes require regression tests

5. **Adding a New Process Type**
   - Add binary names to `ProcessClassifier.swift`
   - Add manifest parser if needed
   - Add test fixtures
   - Update README

6. **Pull Request Process**
   - Fill out PR template
   - CI must pass (build + test + lint + perf)
   - One approval required
   - Squash merge to main
