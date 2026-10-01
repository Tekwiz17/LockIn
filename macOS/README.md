# LockIn 1.6.2

A local Mac focus timer with app shields, Safari and Chromium website blocking, Block / Only Allow presets, global Never Block, phase notifications, history, and menu-bar controls. Requires **macOS 14+ and Xcode 15+**. No account, paid Developer Program, Screen Time API, or third-party dependency is required to build.

## Open LockIn

1. Unzip **LockIn-Mac.zip** and open **LockIn/LockIn.xcodeproj**.
2. Select the **LockIn** scheme and **My Mac**, then **Product → Run**.
3. Both targets use local ad-hoc signing (`Sign to Run Locally`). Leave Team empty. If Xcode has overridden signing, select each target → Signing & Capabilities → turn off automatic signing → Signing Certificate **Sign to Run Locally**. Do not select a provisioning profile.
4. Start with **Custom**: enter Focus / Short Break / Long Break minutes, use the prominent pencil **Edit** button for apps, websites and Block / Only Allow rules. No built-in presets are created. **Presets → Save Current as New Preset…** saves a reusable setup. First-run setup can optionally save one too.
5. The window and timer resize with the available space; small windows scroll. Closing the window leaves the timer and menu-bar controls running. **Quit/Cmd-Q** hides LockIn while any session exists. End using the app or extension first, then Quit.

Upgrading from 1.0 keeps history, browser pairing, edited presets and Never Block rules. Untouched shipped examples are removed unless one is the active session's rules. Existing active Focus sessions keep their rules and deadline.

The embedded **LockInSafari** target builds automatically with the app. No project generation or package installation is needed. `Scripts/verify-mac.sh` builds the app and runs the Swift core tests on your Mac.

## Safari

1. Build and run the Mac app once. In **Safari → Settings → Advanced**, enable **Show features for web developers** (older Safari: Show Develop menu).
2. Choose **Develop → Allow Unsigned Extensions**. This may need repeating after Safari restarts.
3. In **Safari → Settings → Extensions**, enable **LockIn**, then grant access to **all websites**. The Mac app's Settings → Browsers → Manage Safari Extension button opens that pane.
4. Pair using the steps below. If the extension is not listed, keep the built app in a stable location, launch it, and restart Safari. `Scripts/register-safari.sh` registers the built app/extension with the local system if needed.

## Chrome / Chromium

1. Unzip **LockIn-Chrome.zip**.
2. Open **chrome://extensions**, turn on **Developer Mode**, select **Load unpacked**, and choose the **LockIn-Chrome** folder containing `manifest.json`.
3. Allow site access on all sites. Pair below. Other Chromium browsers use their own Extensions page. Chrome 120+ is required.

## Connect each browser

In the extension, select **Connect Automatically**. It opens `lockin://pair` with a random, one-time challenge; approve the native prompt in LockIn. The extension claims its credential through the local service, even if its popup closes. Approval and claim expire after two minutes, and no long-term credential is placed in the URL. If the browser does not launch the scheme, use the backup code.

Backup: in LockIn **Settings → Browsers → Create Connection Code**. Copy that code into the extension popup, click **Connect to LockIn**, and approve the Mac dialog promptly. The code lasts two minutes and works once; create another for your other browser. Saved credentials reconnect automatically. If macOS or the browser asks about local network access, permit it for local sync; the server only listens on `127.0.0.1:19287`.

## Focus and Pomodoro

The top switch selects **Focus** or **Pomodoro** before a session begins. End the current session before switching modes. Existing saved sessions retain Pomodoro behavior.

- **Pomodoro:** the existing Focus → Short Break / Long Break cycle, cadence and automatic-start settings.
- **Focus → Timed:** one countdown with no breaks. Expiry records completion, unlocks everything and returns to ready.
- **Focus → Indefinite:** elapsed-time stopwatch with no breaks. Pause unlocks and freezes elapsed time; resume continues; End records the time and unlocks. It survives relaunch. Nuclear Mode is unavailable for this option, both in the UI and controller.

The setup heading is simply **Name · Edit**. The pencil is a prominent button. Its editor contains apps, websites and rule mode; the main screen has no separate website editor. During ordinary sessions, Add/Remove or change Block / Only Allow and **Save** to apply immediately. The running timer is preserved. Nuclear sessions lock editing in the UI and controller.

For indefinite Focus, browser state carries a renewable **90-second deadline**, refreshed while LockIn runs. The extensions enforce that lease and label it Indefinite Focus. If LockIn stops responding, cached restrictions expire after the last lease, subject to browser scheduling. This avoids an endless cached website lock. Ordinary Quit no longer ends a session; it hides LockIn until you stop through the app or extension. Existing older extensions can enforce these finite leases; update to see the indefinite label.

For Chrome, replace files inside the existing unpacked extension folder using the new Chrome ZIP, then Reload in chrome://extensions. Keeping the same folder preserves pairing. Safari resources are embedded in the rebuilt Mac app.

## Preset management

Open **Presets → Manage Presets…** or the sliders button beside Edit. Select a saved setup to **Use Preset, Edit, Rename, Duplicate, Replace with Current**, or **Delete**. Save Current as New stores the current Focus/Pomodoro mode, timed/indefinite choice, all durations, cadence, rules, Strict Blocking and Block AI. Replace with Current retains the destination preset's name and identity. Custom retains its own timer mode when switching back. Presets are optional; installation still starts with none.

Selecting a different setup or deleting its active preset requires ending the session. Ordinary running rules can be edited or replaced without resetting the clock. Nuclear Focus locks preset mutations and Block AI in both the UI and controller.

## Block AI

Turn on **Block AI** inside Edit. During active Focus it blocks 31 curated AI service domains, including ChatGPT, Claude, Gemini, Copilot, Perplexity, Grok, DeepSeek, Poe, NotebookLM, Midjourney and several other chat/music/image/video tools. It also blocks Google AI Mode (`udm=50`), Bing chat/Copilot, X Grok and Hugging Face chat routes while leaving those services' ordinary search/social/docs routes subject to your regular rules. **Edit → Additional AI Websites** lets you add missing services. The list lives in `BrowserExtensions/Shared/ai-policy.js`.

On supported Google search domains, a local content script hides detected AI Overview panels and AI Mode links/buttons. It watches for panels injected after load and restores visibility when you pause, stop, enter a break, disable Block AI or the cached Focus expires. Containers containing the ordinary results region are protected. **Never Block exceptions win**, including a Google exception for overview hiding. Only Allow entries do not override Block AI.

Coverage is best effort: Google changes its markup, translated headings and regional domains differ, and new AI services appear. This does not block AI embedded in every website, native AI apps, browser assistants or unlisted services. You can add extra website/app rules. No Google page text is sent to LockIn. Use Google's **Web** filter if an overview is missed; Google offers this filter as a text-results alternative ([Google help](https://support.google.com/websearch/answer/14901683)). Update both app and extension for this feature; older extensions ignore the new optional fields.

## Hide blocked Dock shortcuts

In **Edit**, enable **Hide Blocked Apps from Dock**, then Save. While Focus is active, LockIn removes pinned app shortcuts that its normal app policy blocks (both Block and Only Allow), respecting Never Block and protected macOS apps. Live edits update the hidden set. Pause, a break, end, toggle-off restores the shortcuts; Quit while a session exists now hides LockIn. Nuclear Focus locks this setting along with other rules.

The snapshot stores full Dock tile metadata, GUIDs, order and a recovery deadline in `~/Library/Application Support/LockIn/dock-snapshot.json` **before** changing the Dock. A separate bundled **LockInDockRecovery** command-line executable runs through a per-user LaunchAgent every 15 seconds. It restores expired snapshots without opening LockIn. Timed sessions use their original deadline; indefinite sessions use a renewable 90-second lease, so a crash cannot hide icons forever. Relaunch uses the snapshot to continue an active Focus or recover an ended one. A file lock coordinates app/helper writes; the snapshot is retained when recovery fails.

With an unchanged Dock, restored items occupy their exact original positions. If you add/delete/reorder other shortcuts during Focus, recovery restores only LockIn's removed items beside their surviving original neighbors, keeping your other changes. Do not move/delete the built app during Focus: the helper must remain available. Enable its background item if macOS asks. Recovery after sleep/logout occurs when your user session runs again; scheduling may delay it.

**macOS limitation:** this hides pinned shortcuts, not the icons of apps that are still running, recent apps or minimized windows. It never closes apps or changes their bundles. The Dock briefly restarts to apply shortcut changes. Managed/unsupported Dock layouts are refused instead of guessed. No global Dock reset, Finder restart, administrator rights, or third-party utility is used. The shortcut layout uses macOS preferences conventions, which may change in beta versions.

If recovery fails, open LockIn again and end the session or disable the toggle; it will retry from the retained snapshot. Keep `dock-snapshot.json` until successful restoration. For manual recovery, run `LockIn.app/Contents/Resources/LockInDockRecovery` after the recorded deadline (no sudo).

## Menu-bar popup

The menu bar now opens a native window-style panel inspired by the extension: LockIn header, session card, large timer, mode/preset, lock status, progress, rule counts and Block AI status. Pause/Resume, Stop with confirmation, Start waiting phase and Skip Break appear when available. Nuclear hides Pause/Quit, shows its unlock time, and offers Emergency Exit while a monthly exit remains. Open LockIn is a full-width button; Settings and today's minutes remain accessible. Errors are shown in the panel too.

## Extension popup

The popup shows remaining time for timed phases, frozen remaining time when paused, or elapsed time for indefinite Focus. Pause/Resume and Stop are available only for ordinary sessions, and disabled while disconnected. Stop requires confirmation. Nuclear sessions have no Pause/Stop buttons; the server also refuses requests against them. Open LockIn is a button that launches the Mac app using its URL scheme.

## How rules work

- **Block:** selected apps/sites are unavailable during Focus; everything else works.
- **Only Allow:** only selected apps/sites work. **Add the browser itself to Allowed Apps** if you want to browse; website permissions are separate.
- **Never Block** wins in either mode. Finder, System Settings, LockIn, and essential components remain available.
- **Pause, waiting for the next phase, and breaks unlock everything.** Strict mode additionally requests normal app termination; it never force-quits.
- **Edit → Website Rules:** enter one domain or full HTTP(S) URL, click **Add**, and then **Save**. Invalid and duplicate entries show a message. This editor works before pairing a browser. Preset/custom rule edits apply on Save; timer edits apply to the next phase. Never Block edits apply immediately outside Nuclear Focus.
- **Quit App** on a standard shield requests normal termination, with 30 seconds to answer any unsaved-work prompt. Cancelling the prompt doesn't permanently unlock the app. Strict Blocking continues to request normal termination; it never force-quits.
- Domains include subdomains, accept full HTTP(S) URLs, and are matched at host boundaries. International names must use their ASCII/punycode form. IPv6 literals and wildcard rules aren't supported. Up to 400 domains per list.

## Exit checks and monthly Nuclear exits

Every Nuclear Focus allows **no Pause**. It can be ended early through **Emergency Exit** after an attention check, up to **two successful emergency exits per calendar month**. The counter is per local LockIn installation, persisted with the session state, and uses the time zone fixed on its first use. Failed/cancelled checks cost nothing; quota is charged and the session ended in the same atomic write only after passing and confirming. Months do not carry unused exits forward. Local files and the system clock are not a tamper-proof quota store.

For ordinary **timed** Focus/Pomodoro, enable **Edit → Require Exit Checks** before the next Focus begins. This is snapshotted into the session and cannot be changed for that running Focus. Ordinary pauses/stops are **unlimited**. Pause uses three short rounds and a minimum eight-second check; Stop uses six rounds and a minimum twenty seconds (eight rounds for Nuclear). Resume is immediate. Indefinite Focus never requires exit checks; its Edit toggle is hidden. Breaks and waiting phases don't require checks.

LockIn automatically chooses a Stroop ink-color task, center-arrow flanker task, streamed two-back task, one-minute number flash, mental arithmetic, or number ordering. The easier pause pool excludes two-back and the minute-long flash. The number flash appears once for one second at a random point between 10 and 45 seconds; answer after a full minute. A wrong answer fails the attempt; after two failed attempts a different task is selected automatically. These are lightweight attention tasks inspired by psychological experiments, not validated clinical assessments.

**Keep Focusing** cancels the check immediately. Focus keeps running, no exit is used, and the chosen task/failure count is retained for the next attempt (including after relaunch). Completed rounds restart after cancelling. Natural expiry still unlocks on time; challenges are tied to the original session ID and cannot end a later session.

The extension offers Pause…/Stop… or Emergency Exit and opens the native check through the authenticated control request. Answers and approval stay in the Mac app; the extension cannot submit a passed-check flag or bypass quota. Upgrade both app and extensions for the new controls. Active-session Disconnect is hidden; active Focus disconnect requests are refused by the worker.

## Session recovery and Quit

During any session, including paused/waiting/indefinite sessions, Cmd-Q and ordinary application Quit keep the session running by hiding LockIn. Explicit Stop/End in the app or extension is required to end early, including the applicable check. Natural expiry still ends/transitions automatically.

The app plus a per-user shell watchdog form a recovery pair: the watchdog checks the app every two seconds and reopens the same built app if it disappears. The app checks the watchdog registration every fifteen seconds and reinstalls it if unloaded. launchd also schedules a killed watchdog again every fifteen seconds. Nuclear uses its original deadline watchdog; ordinary sessions use `com.lockin.mac.session-recovery`. Running timed phases use their saved deadline; paused, waiting and indefinite sessions renew a ninety-second lease. Authorized End removes the lease and agent.

This is **resistance to a single process kill**, not Force Quit/Terminal proof. macOS permits its owner to kill both processes, disable background agents/extensions, edit local files, restart or turn off the computer. Keep the built app in a stable location; allow its background item. A short blocking gap is possible during recovery, and OS scheduling may delay restarts. No administrator rights, privileged daemon, SIP changes or interference with system recovery tools is used. See [Apple Force Quit](https://support.apple.com/en-us/102586) and [Apple launchd guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html).

## Nuclear Mode

For timed Focus or Pomodoro, select Nuclear Mode on the main window, start, and review the confirmation. Consent applies to **one Focus**. Until its original deadline, pause and edits to the rules, timer, Never Block lists and browser disconnections are unavailable. Emergency Exit is the only in-app early end: pass a check and use one of two monthly exits. Menu and Cmd-Q hide LockIn rather than ending Focus. Closing its window keeps it running.

On confirmation, LockIn saves the deadline and installs a per-user background watchdog in `~/Library/LaunchAgents/com.lockin.mac.nuclear.plist`. It checks every two seconds and uses Launch Services to reopen the same app in the background after a crash or force quit. There can be a brief app-blocking gap during relaunch; extensions keep their cached policy until the deadline. Run the built app from a stable location and allow its background item if macOS prompts. Moving/removing/rebuilding the app during a locked Focus can prevent recovery. If installation fails, the locked start is cancelled and an error is shown.

At expiry, the watchdog stops and removes its registration file independently; the app unloads the service, releases shields, and ends timed Focus or enters an **unlocked, waiting break** in Pomodoro. A subsequent Pomodoro work interval is standard unless you end the cycle and explicitly confirm another Nuclear Focus. Nothing runs while asleep, logged out, or powered off; time still passes and expiry is checked when LockIn resumes. macOS allows disabling extensions/background items, switching users and editing local files, so this is not tamper-proof or a replacement for Screen Time.

If a native bug requires recovery, disable LockIn's background item in System Settings, force quit LockIn, and disable the browser extension. The saved deadline still expires. Developer cleanup: `launchctl bootout gui/$(id -u)/com.lockin.mac.nuclear`, then remove `~/Library/LaunchAgents/com.lockin.mac.nuclear.plist` if it remains. This is deliberately an OS-level escape, not an early-end button inside Nuclear Focus.

## Permissions, privacy & limits

No Accessibility or Screen Recording access is required. Standard app blocking hides the blocked app and presents one shield per screen, including secondary displays. It is a voluntary focus aid, **not a security boundary**: activation can briefly precede hiding, an app may refuse termination, and you can disable extensions/background items or switch users. Standard Focus can also be ended inside LockIn. Protected macOS screens and browser-internal pages aren't blocked. Only top-level HTTP(S) website navigation is restricted; this is not a firewall for downloads, embedded content, or other browsers.

When LockIn becomes unavailable, each extension keeps its cached Focus policy **until its saved end time**. Background suspension, browser permission prompts, and sleep can delay updates; expiration is rechecked on worker startup, alarms, and the blocked page. Disconnect in the extension to immediately clear its cached policy. Disconnect in the app revokes its credential, with any current cached Focus lasting to its deadline. Leave LockIn running for automatic phase transitions. After a long sleep or restart, it completes at most one elapsed phase and begins the next phase from the current time, rather than inventing sessions completed while asleep.

Presets, history, and recovery state are saved atomically in `~/Library/Application Support/LockIn/state.json`; connection secrets are stored in Keychain and extension-local storage. No browsing history, page content, or keystrokes are collected. The shared sync service exposes authenticated, session-scoped Pause/Resume/Stop controls and a state feed; it has no rule-write endpoint. Nuclear controls are rejected by the Mac app. Content scripts cannot access credentials or invoke these controls. Never paste connection credentials into diagnostics.

## Source & verification

`Core/` contains the Swift models and policy. `MacApp/` contains the native UI and services. `BrowserExtensions/Shared/` is the only editable browser source; `Scripts/build_extensions.py` refreshes the included ready-to-load Chrome and Safari outputs. `Scripts/make_project.py` reproduces the included Xcode project. `Scripts/package.sh` verifies and packages both ZIPs. Icon generation alone needs Pillow; all generated assets are already included.

**Read TESTING.md:** Linux tests and structural checks passed, but this delivery has not been compiled with Xcode or run on a Mac. The Mac verification script and manual checklist are included; a zero-bug guarantee would not be honest.

Developer references: [Apple local Safari extension testing](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension), [Safari background compatibility](https://developer.apple.com/documentation/safariservices/optimizing-your-web-extension-for-safari), [Chrome declarative rules](https://developer.chrome.com/docs/extensions/reference/api/declarativeNetRequest), [Chrome worker lifecycle](https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle).

## Changes in 1.6

App shields have no Pause/Unblock button. Use the main app, menu bar or extension for session controls. Every 0.3 seconds during active Focus, LockIn checks on-screen application window owners and hides blocked apps even when their windows are unfocused. Activation still shows the blocking screen. Pauses, breaks, Never Block and the explicit Quit App save-prompt grace remain respected. Native multi-display, Spaces and full-screen behavior needs testing on your Mac.

Nuclear Mode is available in Edit and the main setup, and hidden for indefinite Focus. First enabling requires the macOS authentication prompt, supporting login password or available Touch ID. After verification, choose authentication every time or first time only. Edit lets you change that preference after another authentication. The app never receives the password.

Exit checks now use timed answers, 12 Stop rounds / 16 Nuclear rounds (number flash remains one minute), with minimum durations of 90 / 120 seconds. Ordinary Pause checks use five easier rounds and a 20-second minimum. Mental math includes larger multiplication expressions with a visible response countdown; a timeout fails the attempt. Keep Focusing still cancels without changing the session or consuming an exit.

Extension AI route regexes were simplified. Unsupported network rules are filtered when the browser supports validation; rejected rules no longer prevent sync or Google AI hiding from starting. Google span headings and additional Overview module markers are detected. Coverage remains best effort as Google changes its pages.

## 1.6.1 browser fixes

Reconnection now requests an immediate state rather than long-polling a cached revision on startup. Paired Pause/Stop controls can call the authenticated native endpoint even while the state feed is reconnecting; the Mac still validates credentials, session identity and Nuclear restrictions. Domain network rules use the browser's requestDomains matcher and a small shared regex, while Google AI Mode uses one domain-scoped route rule instead of separate compiled patterns for each regional domain.

Collapsed and generating Google Overviews now include YzCcne, folsrch and plain div heading variants, with guarded CSS and attribute/text observation. Local URL checks run every 100 ms to catch AI Mode SPA navigation without waiting for the five-second state refresh. Cached Focus expiry and Never Block still take precedence. These checks are best effort, not a guarantee of hiding every future Google layout.

If Xcode repeats warnings about missing Combine or method-reference Binding setters, check the files you are building: ExitChallenge.swift in this ZIP imports Combine directly and starts with a 1.6.1 comment; MainView uses explicit setter closures. Replace the project sources using the latest Mac ZIP, open its project, and Product → Clean Build Folder before rebuilding. Native compilation is unverified here.

53 portable tests pass (42 JavaScript/DOM and 11 shell), plus Swift grammar and project checks. Rebuild Safari, reload Chrome in its existing unpacked folder, and reload open Google tabs so they use the new content scripts.

## 1.6.2 Overview prevention, Quit and purple theme

When Block AI is active, ordinary Google searches automatically switch to Web results (`udm=14`). Google documents that this filter excludes AI Overviews: https://support.google.com/websearch/answer/14901683 . Existing search query, pagination and language parameters are retained. Images, Videos and other explicit search categories stay available; AI Mode remains blocked. Google Never Block exceptions still win. Regular results are briefly withheld while the initial local policy check completes to limit an Overview flash; failure releases that hold after two seconds. CSS/DOM Overview hiding remains a fallback. Rebuild Safari, reload Chrome and reload existing Google tabs.

The bottom Quit LockIn button confirms and ends the session, removes recovery, restores Dock shortcuts and exits without reopening. For gated sessions, pass and confirm the exit check first; Nuclear consumes one monthly emergency exit, with no bypass when none remain. Keep Focusing cancels the pending quit. Cmd-Q retains the prior hide-during-session behavior.

App shields explicitly use #6c63ff purple even when they are hosted outside the main window. Extension controls and the website blocking page use the same purple accents.

55 portable tests pass, plus Swift grammar/project checks. Native quit, Dock restoration, macOS compilation and live browser rendering need verification on your Mac.
