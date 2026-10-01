# Verification report

Verified in the delivery environment (Linux, 2026-09-30):

- **31 passing Node.js tests**, including **five jsdom fixtures** for Google panel hiding, preserving regular results, restoration, dynamic injection, reused containers and spoof-domain exclusion, plus **6 passing watchdog shell tests** with simulated clock/process/open commands. The actual embedded script is exercised for expiry, no duplicate relaunch of a running app, closed-app recovery, malformed PID/deadline, missing app, and literal paths containing spaces/shell metacharacters. These do not verify launchd or Launch Services.
- **Browser rule checks:** Domain normalization, malformed inputs, boundary matching, Never Block precedence, both modes, pause/break/expiry, version validation, stale rejection, and declarative policy parity across 480 URL/mode combinations.
- Background-worker tests run the actual shared background script with simulated browser APIs: cached Focus after restart, lost connection, expired cache, authoritative break, stale messages, content-script privilege boundary, explicit disconnect, Swift idle payload, and expiration alarm.
- JavaScript syntax checks on all shared scripts.
- Xcode OpenStep project successfully parsed; all three native targets, embed phase, source membership and resource references verified.
- All Swift files passed a tree-sitter grammar parse. **This is not a compiler or SDK type check.**
- Both extension manifests, local HTML assets, plist/entitlement XML, scheme XML, icon catalogs, and shared/generated browser source parity checked.
- Archives are checked for missing files and ZIP integrity after packaging.

Not executed here:

- Xcode build, Swift tests, native launch, signing, Keychain access, notifications, full-screen/multiple-display behavior, and Safari loading.
- Real Chrome/Safari runtime integration, localhost browser permissions, DNR API acceptance, and background suspension behavior. A Chromium test-runtime download was unavailable in this environment; tests therefore use simulated APIs, not a real browser.

## On your Mac

Run `./Scripts/verify-mac.sh` from the project. This builds the actual app + Safari target and runs twenty XCTest core tests via Swift Package Manager. Node tests also run if Node is installed. No Node install is required to use LockIn.

Use one-minute phases for a quick end-to-end check:

1. Block preset: select a harmless test app and `example.com`. Start Focus, switch into the app, verify it hides and a shield appears. Go Back must restore an allowed app. An unselected app must work.
2. Only Allow: allow Safari/Chrome and one work app; allow `example.com`. Confirm the work app and site work, another normal app/site is blocked, and Finder/System Settings/LockIn remain available.
3. Add a conflicting app/site to Never Block; it must immediately work in both modes. Remove it during Focus and verify the active preset applies again.
4. Pair Safari and Chrome separately. Both should show the same preset/time/rule mode. Visit a blocked site, including a subdomain and an already-open tab. Break, pause, resume, end, and rule edits must affect both browsers. Try a trailing-dot hostname and similar-looking nonmatching hostname.
5. Check short and long breaks, every-fourth long-break cadence, Skip Break, manual next-phase starts, end-early confirmation/history, and notification toggles.
6. Quit LockIn during standard Focus: it should end and send an unlock before exit. Force quit during standard Focus: extensions retain policy to the known deadline, then unlock. Reopen before the deadline and verify recovery. Restart a browser during Focus and after expiry. Disconnect/re-pair without restart. Run with localhost unavailable and verify the reconnect message.
7. Sleep past Focus end and wake; verify one completed Focus, unlocked break, and no invented completed sessions. Test pause through sleep/relaunch.
8. Move a blocked app to another display or full-screen Space; activate it, switch to an allowed app, unplug a display, and verify no orphan shields. Check Stage Manager and native full-screen behavior on your macOS version.
9. Check Standard and Strict with an unsaved document. Strict must request normal termination only and must never force-quit. Cancel any save dialog and return to LockIn.
10. Restart Safari and repeat Allow Unsigned Extensions if required. Verify both extensions have permission on all sites; private/incognito windows need separate browser permission if desired.

A successful unit test run cannot establish that all platform behavior is bug-free. These Mac-only checks remain required before treating this as a verified daily-use build.

## 1.1 Mac verification additions

- Fresh install: no presets; Custom is selected. Setup can optionally save a named preset. On upgrade, untouched shipped examples disappear while edited/user presets and active rules remain.
- Resize the main window down to 360×460 and up to a large display: content scrolls when needed and the timer scales. Resize settings/editor windows; controls remain reachable.
- Set arbitrary custom minutes, rules and long-break cadence. Relaunch and verify they persist. Save as a preset, create/duplicate/delete presets, and delete the last one: Custom remains usable.
- Use Website Rules with `youtube.com`, a full URL, an invalid address, and a duplicate. Add must show the normalized list; Save Rules commits it. Cancel must preserve the old rules. Test without any paired browser, then with both browsers connected, in both rule modes.
- Safari must appear in the app picker even while closed. Check apps in /Applications, ~/Applications, system folders, a symlink, and a running app outside those folders. The manual picker remains available.
- Standard shield: Quit App with a harmless app and an unsaved document. Normal save prompt is reachable for 30 seconds. Cancel the prompt and verify blocking returns; no force quit is used.
- Nuclear Focus: choose one minute. Cancelling confirmation must not install an agent or start a session. Confirming must save the original deadline and lock Pause/End/rule and Never Block edits across main UI, menu and shield. Cmd-Q hides; closing the window leaves Focus active.
- Nuclear recovery: **outside Xcode**, use the built LockIn.app from a stable location. Force quit it; watchdog should reopen it in about two seconds, restore the same session/deadline, and reconnect browsers. No second app instance or overlapping sync servers should appear. Repeat force quit near expiry; it must never restart a new locked Focus after the deadline.
- Nuclear expiry: shields and browser rules release, an unlocked waiting break appears, LaunchAgent file disappears and job unloads. Start the break manually; subsequent Focus has no inherited Nuclear flag.
- Background installation failure: deny/disable the background item or use a test account where LaunchAgents cannot be written. No locked session should begin if installation fails; an error appears. OS-level disabling after start remains an intentional escape.
- Sleep/logout/relaunch across the deadline: no new locked cycle; a waiting break and one completed Focus. Do not infer active blocking while the Mac is asleep or another user is logged in.

The four new Swift core tests cover fresh custom setup, old-file decoding and nuclear lock boundary/recovery. They are included but **not run in this Linux environment**.

## 1.2 Mac verification additions

- Top mode switch: new and restored legacy sessions use Pomodoro. The switch is disabled until the current session ends; the selected idle mode persists across relaunch.
- Timed Focus with one minute: no break, one completed history entry, app/browser unlock and ready screen. Repeat with Nuclear Mode; watchdog cleans up without any new phase.
- Indefinite Focus: stopwatch counts up with no deadline, apps and sites enforce both modes, pause unlocks/freezes, resume continues, and End records elapsed minutes. Pause and resume through relaunch. Nuclear is hidden and rejected by the controller.
- Indefinite lease: browser remains blocked well beyond 90 seconds while connected. Force quit the app; last cached rules expire after the 90-second lease. Reopen and reconnect. This requires real browser checks; alarms can be delayed by browser scheduling.
- Live Edit: in timed, indefinite and Pomodoro sessions, add/remove apps and domains, switch Block/Only Allow, and Save. Both browsers and app shields update without resetting the timer. Cancel preserves old rules. Repeat in Nuclear: Edit, Never Block mutations and pause/end must be unavailable.
- Main heading is Name · Edit, with a visible bordered pencil button and no separate Website Rules button. The editor contains both apps and sites and hides timer controls during a run.
- Chrome: update files in the same unpacked folder and Reload; pairing remains intact. Popup/blocked pages show Indefinite Focus, rather than the internal lease countdown.

Two added Swift core tests cover legacy mode, Focus completion routing, indefinite enforcement and elapsed pause/recovery. They are included but not executed in Linux.

## Extension controls and automatic pairing checks on Mac

- Launch LockIn via Open LockIn while running, closed-window and fully quit. Confirm its URL is registered for the rebuilt app.
- Automatic pairing: click Connect Automatically in Chrome and Safari, allow the OS to open LockIn, then approve its prompt. Popup closure must not cancel pairing. Each extension should reconnect without copying a code. Deny the prompt, let a request expire, and verify the backup code still works.
- Timed Focus/Pomodoro popup counts down, paused timer freezes, Resume continues, and Stop confirms/unlocks. Indefinite popup counts elapsed time, excludes pauses, and stops correctly. Waiting phases show planned time; controls never start a waiting phase by accident.
- Nuclear: Pause and Stop are absent. A direct authenticated /control request must return 403 during Nuclear Focus. A stale prior-session ID returns 409 after a phase transition. No request from a content script can pair, read settings, pause/resume or stop.
- URL contains only a random ephemeral challenge and browser name; credential is claimed over localhost after consent, stored in Keychain/extension storage and never exposed in the link. Multiple claims cannot retrieve the same approved credential.
- Browser disconnect/crash: controls disable and cached indefinite policy expires; reconnected controls target the current session.

Four new simulated worker tests cover authenticated stop/unlock, offline and Nuclear rejection, automatic token claim and pairing expiry. Platform URL launch, consent and actual HTTP integration remain unverified here.

## 1.3 verification additions

- Toggle Block AI in an ordinary active session: ChatGPT/Claude/Gemini and the curated service list block immediately in both browsers. Remove the toggle or pause/end: sites restore. Allow-listed AI sites still block; Never Block AI exceptions work. Add and remove an extra AI domain in Edit.
- Google search: test a query that actually generates an AI Overview, including one injected after load. The overview and AI Mode links hide, normal results remain visible, and Web search still works. Toggle off/pause/stop and verify visibility returns. Test supported regional Google domains and a Google Never Block exception. Fixtures validate the algorithm, not Google's current live DOM.
- Nuclear: Block AI cannot change through the main toggle, editor or presets. No Nuclear toggle is present for indefinite Focus, including when an indefinite preset is selected from the manager. Switch back to a timed setup and verify a fresh explicit decision is required.
- Presets: Save Current as New with Focus/Indefinite/Block AI, switch to another setup, return and verify all fields restore. Rename, edit, duplicate, replace with a current Pomodoro setup, delete, and delete the last preset. History and Custom remain. Try replacing an active ordinary preset: its timer remains unchanged. Active preset deletion and switching stay unavailable.
- At minimum widths, website hint, validation feedback, full domain/app names and timer labels wrap; Add/Save/Cancel remain reachable. Check long preset names and long domain entries in Settings as well as Edit.

DOM fixture tests are optional development tests: install jsdom 26 in a separate development directory and expose its node_modules using NODE_PATH, then run Scripts/validate.py. Without jsdom these five tests explicitly skip. LockIn and its extensions have no runtime dependency on jsdom. All 31 browser tests and six watchdog tests were executed for this delivery. Thirteen Swift tests are included; none were executed without macOS/Xcode.

## 1.4 Mac verification (required for Dock and menu behavior)

The new Dock runtime could not be exercised on Linux. Four additional Swift tests cover exact order/payload recovery after serialization, preserving unrelated Dock additions/deletions, all-removed recovery without duplicates, and migration of the optional toggle. Seventeen Swift tests are included but unexecuted here. Static project checks verify the helper includes only Foundation/Dock sources, builds as an app dependency and embeds in Resources.

1. Build the full project with Scripts/verify-mac.sh: app, Safari extension and LockInDockRecovery tool must all compile. Verify Contents/Resources/LockInDockRecovery is executable and signed locally. Run the app outside Xcode from a stable path.
2. Pin several harmless CLOSED apps among other shortcuts. Block nonadjacent ones, enable the Dock toggle and start a one-minute Focus. Snapshot must exist before removal; other apps, spacers and Downloads are unchanged. Pause, resume, end, let it expire, break and toggle off: removed tiles return to the same positions without duplicates.
3. Repeat Only Allow with Never Block conflict and protected system app IDs. Unknown/non-app tiles remain. Live add/remove app rules and switch rule mode: Dock changes without resetting the Focus timer. Nuclear refuses edits.
4. Add a new unrelated shortcut and unpin/reorder an unrelated one during Focus. End: keep those edits, restore only removed shortcuts beside original surviving neighbors. Re-pin a hidden shortcut during Focus: no duplicate after restoration.
5. Force quit before the deadline and leave LockIn closed. The helper must restore after deadline within launchd scheduling and remove its LaunchAgent registration file. Relaunch before expiry: same snapshot/session/deadline, continued hiding. Relaunch after expiry: restore and no new Focus. Repeat with indefinite Focus: restore after the last 90-second lease; live Focus continuously renews it.
6. Crash/interrupt between snapshot write and preference update, then between preference update and journal completion. Retry/relaunch must restore once, preserving metadata. Deny LaunchAgent installation: no Dock removal. Simulate preference/write failure: error shown, recovery snapshot retained. Check user-managed Dock: refuse unsupported state without rewriting it.
7. Normal Quit restores first. Nuclear Cmd-Q hides the app and keeps shortcuts hidden until deadline. Watchdog recovery must coexist with Dock recovery without duplicate app instances. Sleep/logout across deadline: restoration on next running user session.
8. Running blocked app can still have a Dock icon; closing it removes that running icon. The toggle must not close the app or lose unsaved work. Recent apps and minimized windows are intentionally untouched.
9. Menu bar: Ready, timed Focus, indefinite, paused, waiting break and Nuclear card/status all readable. Test Pause/Resume/Stop confirmation, Skip Break, Open LockIn and Settings. Nuclear has no Stop/Pause/Quit. Long preset names wrap; VoiceOver labels and light/dark appearance work.

Browser regression suite and six watchdog simulations passed again in this release; no claim of native Dock/menu integration testing is made.

## 1.5 Mac verification additions

Portable results: 32 browser tests and 11 actual embedded-shell simulations passed. Five new recovery tests cover literal argument handling, relaunch-once, no duplicate running app, renewable lease, explicit stop removing lease, expiry/malformed input and invalid PID handling. Twenty Swift tests are included but not executed in Linux.

- Nuclear: no Pause through main, menu, shield or direct authenticated control. Emergency Exit appears in app/menu/extension with remaining monthly count. Passing and confirming consumes one; failures, cancellation, natural expiry or save failure consume none. After two exits, a third is unavailable. Relaunch preserves quota; simulate month boundary in a development copy and check reset. Do not infer tamper-proof enforcement from a local ledger.
- Force each task in a development test: ink color differs from word, center arrow answer ignores flankers, six N-back digits stream at one per second and final answer compares last with two-back, flash appears only once for one second and input enables after 60 seconds, arithmetic and ordering accept correct input/normalization. One wrong answer restarts the attempt; a second switches task. No rapid double-submit skips rounds or charges twice.
- Keep Focusing at any step or after passing closes the check, keeps the original Focus and deadline, and uses no exit. Close the check window, reopen, or relaunch: task/failure count remains, round progress restarts. Let Focus expire while a check is open: no later session can be stopped by a stale check.
- Ordinary timed with checks enabled: unlimited successful Pause/Resume and Stop. Pause has five rounds/minimum twenty seconds and excludes N-back/flash; Stop is harder/longer. No monthly quota is consumed. Resume has no challenge. Toggle cannot disable a check for a running session. Indefinite has no toggle/checks; waiting/breaks unlock normally.
- Extension: test ordinary no-check control, ordinary gated pause/stop, Nuclear Emergency Exit, quota exhaustion, offline and stale session ID. Native check must open; session remains unchanged until pass + confirmation. Content scripts cannot invoke controls or send proof. Update/reload Chrome and rebuilt Safari.
- Cmd-Q/menu Quit/application Quit during running, paused, waiting and indefinite sessions hides instead of ending. Explicit authorized Stop removes agent; Quit after that exits normally. Active Focus Disconnect is hidden/refused.
- Recovery outside Xcode: force quit ONLY the app and verify reopen/same session/deadline. Kill ONLY watchdog and verify launchd reschedules it. Unload its registration while app is active and verify app reinstalls it. Test pause/resume/phase changes against deadline file, emergency end against original Nuclear watchdog, and no restart after authorized end or expired lease. Disabling both processes/agents is outside the protection guarantee.

Native challenge timing, SwiftUI window opening, monthly ledger transaction failures and launchd behavior remain unverified here.

## 1.6 native checks

- Run Scripts/verify-mac.sh and confirm the reported Combine / Binding diagnostics are absent. The signed extension stripping notice is a Debug packaging warning, not a Swift compile failure.
- First enable Nuclear in main or Edit: cancel authentication and verify it stays off; authenticate and choose each future policy. Start a Nuclear session and check the chosen behavior. Changing the policy requires authentication. No Nuclear option appears for indefinite Focus.
- Verify Block AI exists only inside Edit, and all rule changes remain unavailable in Nuclear. Reload both extensions. Check the extension status for any network compatibility warning, Google Overview hiding before/after a late panel appears, AI Mode and AI service blocking, and Never Block exceptions. Test actual current Google pages; DOM fixtures cannot establish live-site coverage.
- Mental math Stop/Nuclear uses multiplication and a 12/10-second response timer. Pause uses easier expressions and 15 seconds. Timeouts fail attempts, two failures change task, and cancellation keeps Focus. Verify the 90/120-second Stop/Nuclear minimum and 20-second ordinary Pause minimum.
- Start with a blocked app visible behind another app, beside it, and on another monitor. It should hide without clicking. Repeat with new windows opened programmatically, rule edits during ordinary Focus, Spaces/full-screen apps and waking. Allowed/Never Block apps must stay visible. Pause/break/end permits normal windows again. If macOS rejects hiding an app, report its name; enforcement relies on the OS window list and application-hide API.
- Blocked-app screen has Open LockIn / Go Back and non-strict Quit App, with no pause action. Check Quit App's 30-second unsaved-work grace and strict behavior. Check small displays and dark appearance.

Portable verification: 36 JavaScript/DOM tests and 11 shell simulation tests passed, with no skipped tests; all Swift files passed grammar parsing. This environment cannot compile AppKit/SwiftUI or run native windows.

## 1.6.1 native browser checks

- Verify the new 1.6.1 source header in ExitChallenge.swift and explicit Binding setters in MainView; clean and rebuild the updated project. Enable rebuilt Safari; reload Chrome and already-open Google tabs.
- Close/reopen the extension during a stable Focus: initial reconnect should return current state immediately, with no 20-second wait. Pause/Resume/Stop works while a long poll is pending. Test stale credentials, offline app, session changed, Nuclear pause forbidden and challenge handoff. Controls remain authenticated; cached permissions cannot override native restrictions.
- No unsupported-regex warning should appear on supported browsers; if a rule is still rejected, its compatibility warning must not disable sync or session controls. Test Only Allow and Never Block to verify precedence after requestDomains changes.
- Google: test an unexpanded Overview, a generating placeholder, People Also Ask, responding into AI Mode, late-injected panels and changing queries through SPA navigation. Normal results stay visible. Pause, expiry and Never Block restore permitted UI. AI Mode URL checks run every 100 ms locally; actual navigation/paint latency depends on the browser.
- 53 portable tests passed, including collapsed markers, existing-node attribute changes, local SPA/expiry handling, immediate reconnect and authenticated control during pending polling. This is fixture/simulation coverage; test current Google layouts on Safari and Chrome.

## 1.6.2 native checks

- With Block AI on, search Google from the address bar, Google homepage and an already-open result page. Confirm Web results (`udm=14`) without an Overview, with query preserved. Test Images/Videos, pagination and changing queries; no redirect loop. AI Mode still blocks. Turn Block AI off or Never Block Google: ordinary results should be permitted. A missing extension/site permission is not an enforced policy.
- Quit LockIn at idle and in an ordinary timed/indefinite session: confirmation, Dock restoration, nil saved session, removed recovery registration and no relaunch. Quit during an exit check requires completion first; cancelling via Keep Focusing leaves the session active and cancels pending quit. Nuclear Quit requires and consumes an emergency exit, never pauses, and rejects when monthly exits are exhausted.
- Ensure the timer/icon/buttons on app shields are purple even when the main window is closed; extension controls and website block page use the same #6c63ff. Inspect light/dark appearances.
- 55 portable tests pass. Added cases cover Web routing query/category preservation and existing-tab/Never Block behavior; native quit remains unverified in Linux.

## 1.6.3

Verify Quit is absent during running, paused, waiting and break sessions and appears after ending; direct quitPermanently rejects an existing session. Test the same browser ZIP in Chrome, Brave, Edge and Firefox, both automatic and backup pairing. Confirm accurate names, permissions, reconnect, controls, Never Block, AI blocking and expiry. Firefox temporary loading is removed at browser restart. 57 portable tests pass; native browser installations remain unverified.
