# LockIn

A Mac and Windows focus app that gives you some space from distracting apps, websites and AI. Pick a timer, choose what to block (or what to allow), and start. Everything syncs locally with your browser. No account or subscription.

## What it does

- **Focus:** one timed session, or an indefinite stopwatch with no breaks.
- **Add time:** extend any timed phase during a session, including Nuclear. If Nuclear requires authentication, verify before adding time. Paused timers stay paused.
- **Pomodoro:** focus, short breaks and long breaks, with your own durations.
- **Custom setups and presets:** start without presets, then save, rename, duplicate, edit, replace or delete your own.
- **Block / Only Allow:** separate app and website rules, plus global Never Block exceptions. Ordinary session rules can change while running; Nuclear rules cannot.
- **Block AI:** blocks a curated set of AI sites, with your own additions. Regular Google searches use Web results to avoid AI Overviews; Images and other explicit categories stay available. AI Mode is blocked. Coverage of unlisted services or AI embedded elsewhere is not guaranteed.
- **App shields:** hide visible blocked apps even when their windows are unfocused. Strict Blocking also requests normal app termination. It does not force-quit unsaved documents.
- **Dock cleanup (Mac):** optionally hide blocked pinned shortcuts and restore their positions, using a saved recovery journal. Running-app Dock icons are managed by macOS and may remain.
- **Menu bar and extension controls:** time left, pause/resume/stop when permitted, and Open LockIn. Pair automatically with a `lockin://` link, or use a backup code.
- **Exit checks:** optional for ordinary timed sessions, with easier Pause checks and harder Stop checks. Cancel a check and keep focusing whenever you want.
- **Nuclear:** no pause or rule changes. Two emergency exits per calendar month, each requiring a check. First enabling uses native account authentication, then you choose future verification behavior. Nuclear is unavailable for indefinite Focus.
- **History and phase notifications.** A purple interface, resizable main window and scrollable settings.

**Quit LockIn is shown only when there is no session.** During a session, closing the window (or Cmd-Q on Mac) hides the app and keeps it running. End the session first to quit.

## Download

Download the app or source ZIPs from [Releases](https://github.com/Tekwiz17/LockIn/releases). Release files are uploaded separately by the project owner; they may not be available yet.

- **Mac app:** a release containing `LockIn.app` (possibly inside a ZIP).
- **Windows app:** a self-contained `LockIn.exe` for x64 or ARM64, when uploaded by the owner. Automated builds are available in [Actions](https://github.com/Tekwiz17/LockIn/actions/workflows/build.yml) → a successful run → Artifacts. GitHub may require sign-in to download artifacts.
- **Xcode source:** `LockIn-Mac.zip`, for building the Mac app yourself.
- **Browser extension:** `LockIn-Browser-Extension.zip`. The **same folder and manifest** work in Brave, Chrome, Edge and Firefox. Use current browser versions; the dual-background manifest requires Chromium 121+ / Firefox 121+.

The browser extension needs the Mac or Windows app running. It does not block other apps by itself.

## Install the Mac app

Requires **macOS 14 or later**. Download the app from this repo's Releases, unzip if needed, move `LockIn.app` to Applications and open it. Keep it in that location for background recovery. Allow its background item if macOS asks.

**This project uses a free Apple developer account. Distributed builds are not Developer ID signed or notarized by Apple.** Local ad-hoc signing is used for building; it does not make the app an Apple-verified download. Expect an unidentified-developer / cannot-verify warning.

To allow this specific app:

1. Try opening LockIn once and dismiss the warning.
2. Open **System Settings → Privacy & Security**.
3. Find the LockIn notice and select **Open Anyway**.
4. Confirm **Open**, using your Mac password or Touch ID if prompted.

Follow [Apple's instructions](https://support.apple.com/102445). Only override the warning if you trust this download. You do not need to disable Gatekeeper for your whole Mac. If macOS says the app will damage your computer, or the download is damaged, do not treat that as the same warning; download again or build from source.

## Build with Xcode

Requires **Xcode 15+** and macOS 14+.

For the Xcode ZIP, unzip and open `LockIn/LockIn.xcodeproj`. For this repository, open `macOS/LockIn.xcodeproj`.

Select **LockIn → My Mac**, then **Product → Run**. Targets are set to **Sign to Run Locally**, with no Team or provisioning profile required. If Xcode overrides this, turn off automatic signing on the app and extension targets, leave Team empty and choose **Sign to Run Locally**. The Safari extension and Dock recovery helper build with the app.

When upgrading, stop your current session first, replace the sources and rebuild. If old diagnostics repeat, use **Product → Clean Build Folder**. Your history, presets and pairing are stored separately from the source files.

## Install or build the Windows app

Requires **Windows 10/11**. Download the Windows build for your architecture from Releases, or the matching successful Actions artifact. Extract `LockIn.exe`, move it to a stable folder and launch it. No separate .NET installation is needed for the published self-contained EXE. The first launch registers `lockin://` for your user account; browser pairing works like the Mac app. The tray icon in the taskbar's notification area opens session controls. Closing the window keeps LockIn in the tray; **Quit LockIn appears only while idle**.

**Windows builds are unsigned.** SmartScreen may show an unrecognized-app warning. If you trust this exact download and Windows offers the option, choose **More info → Run anyway**. Managed policies or Smart App Control may prevent this option; do not disable device-wide protection to work around them. See [Microsoft's SmartScreen guidance](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation).

Windows maps the menu bar to a tray popup and app rules to executable paths. Select apps with the running-app picker or add their `.exe` files. It preserves the purple visual theme and Focus/Pomodoro features. Dock shortcut hiding is Mac-only; Windows taskbar pins are unchanged. Native password verification uses your Windows account password, **not a Hello PIN**. If Windows cannot verify the account, Nuclear cannot start. See [Windows setup, feature mapping and release checks](https://github.com/Tekwiz17/LockIn/blob/main/windows/README.md).

To build from source, install the .NET 8 SDK and run from the repository root:

```powershell
dotnet run --project windows/LockIn.CoreTests/LockIn.CoreTests.csproj
dotnet publish windows/LockIn.Windows/LockIn.Windows.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishTrimmed=false -o publish
```

The workflow automatically tests and publishes x64 and ARM64 EXEs and packages the universal browser extension on pushes to `main`, pull requests and manual runs. It uploads Actions artifacts; it does **not** create Releases. The owner publishes release assets separately.

## Install the browser extension

Unzip `LockIn-Browser-Extension.zip` and keep the extracted folder in a stable location. If using this repository directly, use its `browser-extension` folder. Grant site access on the sites you want to enforce, including Google for Block AI.

| Browser | Extension page | Steps |
| --- | --- | --- |
| Chrome | `chrome://extensions` | Enable Developer mode → Load unpacked → choose the folder containing `manifest.json`. |
| Brave | `brave://extensions` | Enable Developer mode → Load unpacked → choose that same folder. |
| Edge | `edge://extensions` | Enable Developer mode → Load unpacked → choose that same folder. |
| Firefox | `about:debugging#/runtime/this-firefox` | Load Temporary Add-on → choose that folder's `manifest.json`. |

**Firefox's unsigned temporary add-on is removed when Firefox restarts.** Reload it after a restart. A permanent installation in standard Firefox requires a Mozilla-signed add-on; this source ZIP is not one. See [Mozilla's temporary-installation guide](https://extensionworkshop.com/documentation/develop/temporary-installation-in-firefox/). Check `about:addons` and allow the extension to run on all required sites if Firefox asks for site access.

### Safari

Safari uses the extension embedded in `LockIn.app`, rather than loading the universal ZIP directly.

1. Run the Mac app once.
2. In Safari Settings → Advanced, enable features for web developers.
3. Select **Develop → Allow Unsigned Extensions**. Repeat after Safari restarts if needed.
4. In **Safari Settings → Extensions**, enable LockIn and grant access to the websites you want blocked.
5. Pair below. LockIn Settings → Browsers can open Safari's extension settings.

### Pair each browser

Keep LockIn open. Click its extension icon, then **Connect Automatically**. Allow the browser to open the `lockin://` link and approve the connection in the desktop app. The browser is named automatically using its available identity APIs (Brave, Chrome, Edge, Firefox or Safari). If identity is hidden or unavailable, it may use Chromium.

Backup: create a connection code in **LockIn Settings → Browsers**, enter it in the extension and approve the native prompt. Codes last two minutes and work once. Pair each browser separately. If local-network access is requested, allow the browser to contact the desktop app; sync listens only on `127.0.0.1:19287`.

When updating, replace files inside the existing unpacked folder and Reload the extension. Reload already-open websites too so they get the new content scripts. Firefox temporary installation may need repeating.

## Limits and privacy

Rules, history, credentials and recovery data stay on your device. No website text or screenshots are sent to a server. Browser naming does not save a fingerprint.

Blocking is best effort using each platform's desktop and browser APIs. App-window behavior, browser permissions and changing website layouts can affect it. Google Never Block exceptions override Block AI. Removing browser permissions or the extension defeats its enforcement.

Recovery can reopen LockIn after a single process disappears. It is **not Force Quit, Task Manager or Terminal proof**: the device owner can kill both processes, disable recovery or alter local files. Monthly exits also use local state. Nothing executes while the device is off; saved timed deadlines still pass. Paused/waiting/indefinite recovery uses a renewable lease rather than a permanent lock.

## Source and checks

- `macOS/`: Xcode project, Swift source, embedded Safari resources, recovery helper, build scripts and tests.
- `windows/`: native WPF app, loopback sync, per-user recovery, tray controls and portable core tests.
- `.github/workflows/build.yml`: Windows EXE builds, universal extension ZIP and Mac native build checks.
- `browser-extension/`: universal extension source and ready-to-load manifest.

The portable checks cover policy, browser naming, AI hiding fixtures, browser sync and recovery simulations. **57 browser/recovery tests and 36 Windows core checks pass**, plus Swift grammar/project checks and Windows desktop reference compilation. GitHub Actions adds native Mac compilation and Windows publish checks. Actual browser installation and Windows GUI behavior need testing on those platforms. On a Mac, run `macOS/Scripts/verify-mac.sh` and follow `macOS/TESTING.md`.

The common background manifest follows [Mozilla's cross-browser guidance](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/background#cross-browser_manifest_v3_background_scripts). Browser-specific native behavior still needs testing.
