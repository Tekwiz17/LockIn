# LockIn 1.6.2

- Switch ordinary Google searches to Web results during Block AI to avoid Overviews; retain explicit search categories and Never Block exceptions.
- Briefly hold regular search results until the first policy verdict, with a two-second failure release.
- Add bottom Quit LockIn: authorized session ending, recovery removal and true termination; exit checks and Nuclear quota remain enforced.
- Match extension and both blocking screens to #6c63ff purple.
- 55 portable tests pass; native and live browser validation remains required.

# LockIn 1.6.1

- Detect collapsed/generating AI Overviews and plain div headings without expansion.
- Use guarded immediate CSS, attribute/text observation and a 100 ms local AI Mode navigation check.
- Simplify domain DNR rules using requestDomains and one regional Google route expression.
- Request an immediate state on reconnection; permit paired controls to authenticate directly while polling reconnects.
- Confirm existing Combine import and explicit Binding setter fixes are present.
- 53 portable tests passed; native macOS compilation and live Google behavior remain unverified.

# LockIn 1.6

- Removed Pause/Unblock from blocked-app screens; added periodic visible-window enforcement for unfocused blocked apps.
- Restyled the app shield to match the website block page, with Open LockIn, Go Back and ordinary Quit App controls.
- Fixed missing Combine import and explicit Binding setters for reported Swift diagnostics.
- Moved Block AI exclusively into Edit; added Nuclear Mode to Edit while retaining the main toggle and hiding both for indefinite Focus.
- Added first-use macOS authentication and a choice of future verification policy.
- Simplified AI route network regexes; added runtime compatibility checks and a fallback that preserves sync and page hiding.
- Expanded Google Overview detection and made exit checks longer with timed, harder mental math.
- 47 portable tests pass; Swift grammar and project/resource checks pass. Native Xcode compilation and Mac behavior remain unverified here.

# LockIn 1.5

- Two monthly Nuclear emergency ends, each gated by an automatic attention check. No Nuclear pause. The quota is persisted and charged atomically with ending the session, only after passing and final confirmation.
- Optional Require Exit Checks for ordinary timed sessions, snapshotted at Focus start. Unlimited pauses/stops; a shorter/easier Pause check, longer Stop check, and immediate Resume. Unavailable for indefinite Focus.
- Six task types: Stroop, flanker, two-back, one-minute number flash, mental arithmetic and number ordering. Two failed attempts switch task automatically. Keep Focusing cancels without ending/pausing or spending quota; task and failure count survive cancellation/relaunch.
- App/extension controls route through one exit policy; native challenges are session-bound. Extension offers monthly Emergency Exit and sends gated actions to the app. Active Focus Disconnect is refused.
- Quit/Cmd-Q hides LockIn during any session instead of ending it. App + per-user deadline/lease watchdog recover from one process disappearing. App checks unloaded registration and launchd reschedules killed watchdogs. This cannot prevent OS-level Force Quit, killing both processes, disabling agents or editing local files.

Validation: 32 browser tests and 11 watchdog simulations passed (43 total), plus Swift grammar and Xcode project checks. Three new core tests cover quota persistence/month reset, task pool/two-back correctness and migration/answer normalization. Twenty Swift tests are included but unexecuted here. Actual Xcode compilation, challenge windows and launchd recovery require Mac checks.

# LockIn 1.4

- Optional Hide Blocked Apps from Dock in Edit, saved with Custom/presets and locked in Nuclear Mode. Both app rule modes and Never Block use the existing app policy.
- Durable write-ahead Dock snapshot preserves full tile metadata/GUIDs and original ordering. Restore on pause, break, end, toggle-off and normal Quit. Original positions recover exactly when the Dock has no unrelated edits; otherwise restore beside surviving original neighbors while preserving those edits.
- Separate bundled command-line recovery target plus per-user LaunchAgent recovers after crashes at the finite deadline or expired indefinite lease. Recovery failures retain the snapshot. Files are locked across app/helper transactions and the agent is installed before any removal.
- This removes pinned shortcuts only. macOS can still show running-app icons; no apps are force-closed or modified. Unsupported/managed Dock layouts are refused.
- Menu-bar window panel now resembles the extension: timer card, session status, rule summary, progress, available controls, confirmation for Stop, prominent Open LockIn, Settings and today's minutes.

Verification: 31 existing browser tests and six watchdog simulations passed; all Swift grammar and three-target Xcode/project checks passed. Four Dock/legacy tests added (17 Swift tests total), but none executed in Linux. Xcode compilation, Dock preferences/launchd behavior and menu-panel rendering still require the included Mac checks.

# LockIn 1.3

- Block AI toggle on the main screen and in Edit, saved per setup. Blocks 31 curated service domains and selected embedded AI routes; additional AI websites are customizable. Never Block wins; Only Allow cannot override Block AI.
- Local Google AI Overview/AI Mode hiding with mutation detection, protected ordinary-result regions, and restoration on pause/stop/toggle/expiry. Coverage is best effort and may change with Google markup.
- Printing-style preset manager: save current as new, use, edit, rename, duplicate, replace with current, and delete. Snapshots include timer mode, indefinite setting, cadence, rules, Strict and Block AI. Custom remembers its timer mode across preset selection.
- Nuclear toggle is completely hidden for indefinite Focus; controller and start guards reject nuclear indefinite. Block AI and preset mutations are locked during Nuclear Focus.
- Website input now has a short placeholder plus a full wrapping hint. Domain/app names and explanatory text wrap; app picker actions no longer compete with long headings.

Validation: 31 browser tests (including five DOM fixtures) and 6 watchdog simulations passed, plus static Swift/project checks. One added Swift migration/round-trip test is included but not executed here. Actual Xcode build and native Safari/Chrome behavior remain unverified in Linux.

# LockIn 1.2

- Top-level Focus / Pomodoro switch. Pomodoro preserves the previous cycle. Focus offers one timed session with no breaks, or an indefinite stopwatch.
- Indefinite time freezes during pause, survives relaunch, and records elapsed time in history. Nuclear Mode is unavailable for indefinite sessions.
- Prominent Name · Edit button contains all app/website and Block/Only Allow controls. Ordinary sessions can edit rules while running without resetting the timer; Nuclear sessions lock edits.
- Timed Focus ends and unlocks without starting a break. Nuclear Pomodoro still waits at its unlocked break.
- Browser labels support indefinite Focus; a renewable 90-second lease prevents cached indefinite rules from locking websites endlessly when the app is offline.
- Saved 1.0/1.1 sessions keep Pomodoro behavior. Existing presets, history and pairing are preserved.

- Extension popup includes current timer, available Pause/Resume/Stop, Stop confirmation and Open LockIn. Authenticated controls check the session ID and Nuclear lock on the Mac.
- Automatic URL pairing with native consent and a short-lived one-time challenge; the connection code remains a backup.

Validation: 22 browser tests and 6 watchdog simulations passed, plus static source/project checks. Native Xcode compilation and Mac/browser runtime checks remain required.

# LockIn 1.1

- Custom starts with no built-in presets. Presets can be created at any time or optionally during setup. Untouched examples from 1.0 are removed while edited/user presets and active-session rules are preserved.
- Window content scrolls and the timer scales with available space. Main/settings/editor sizes are more flexible.
- Dedicated Website Rules editor with clear entry, Add, validation and Save Rules. It works independently of browser pairing.
- App picker checks Launch Services, running apps, symlinks and Safari's system application folder.
- Standard shields include Quit App, with a short opportunity to answer normal unsaved-work prompts.
- Nuclear Mode requires confirmation for one Focus, locks early-exit and policy controls, and installs an expiring watchdog to reopen the app if it quits. The original deadline survives relaunch; expiry unlocks everything and waits for the break.
- Replaced deprecated activation calls/options. Disabled copying/stripping signed extension binaries and Debug dylib splitting in the project settings to address the reported build warnings.
- Browser protocol is unchanged; existing paired extensions remain compatible.

Validation: 16 JavaScript tests, 6 simulated watchdog tests, Swift grammar parsing and Xcode project/resource checks passed. Xcode compilation and native Mac behavior remain unverified here. See TESTING.md.
