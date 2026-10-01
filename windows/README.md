# LockIn for Windows

Native WPF desktop app, Windows 10/11, .NET 8. The GitHub workflow produces self-contained x64 and ARM64 EXEs. It installs no system service and needs no administrator privileges.

## Build

```powershell
dotnet run --project windows/LockIn.CoreTests/LockIn.CoreTests.csproj
dotnet publish windows/LockIn.Windows/LockIn.Windows.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishTrimmed=false -o publish
```

Run `publish/LockIn.exe`. Keep the EXE in a stable directory. First launch registers the per-user `lockin://` protocol. Browser pairing uses the same universal extension and loopback API as macOS. Pair separately on each machine. App selection uses executable paths, so select Windows `.exe` files rather than Mac app bundles.

## Platform mapping

- Focus/Pomodoro, indefinite Focus, presets, live rule edits, Block AI, history, notifications, pause/stop checks, Nuclear emergency quota and authenticated Add Time are implemented.
- The system tray popup replaces the Mac menu bar. Closing the main window hides it; idle-only Quit exits both app and recovery. Click the tray icon for controls or double-click to open LockIn.
- Visible blocked app windows are hidden even when unfocused. A journal saves window placement, process identity and window handle before hiding. Allowed windows are restored with their placement on pause/end or recovery. Strict mode removes the app shield's normal Quit App control; Windows never forcibly terminates unsaved apps.
- Windows shell processes and executables inside the Windows system directory are protected from blocking. Elevated/protected apps that Windows will not let LockIn inspect can remain available. App blocking is best effort; it is not a Windows security boundary.
- Dock pinned shortcut hiding has no Windows counterpart in this version. Taskbar pins are left alone; blocking still hides application windows.
- Nuclear verification uses Windows's credential prompt and verifies the current account's password with Windows. A Windows Hello PIN is not the account password. If account policy does not allow password verification, Nuclear cannot be enabled. LockIn does not store the password. Browser tokens are protected with per-user Windows DPAPI.
- While a session exists, a second process watches for crashes, and a per-user Run entry resumes on sign-in. The app refreshes the watcher's lease and relaunches a stopped watcher. Recovery respects the saved wall-clock deadline, including added time. It does not make the app Task Manager/admin-proof or run while the machine is powered off.

Data lives under `%LOCALAPPDATA%\LockIn`. Settings are atomically saved; corrupted state is preserved as a recovery copy rather than silently resetting Nuclear. Recovery expects the EXE to remain at the registered path.

## Manual checks before a release

1. On both x64 and ARM64 (if distributing both), launch the EXE, resize the window and test the tray popup.
2. Create/edit/rename/replace/delete presets; start from Custom with no presets.
3. Block a selected `.exe`, including an unfocused visible window. Pause/end and verify window positions return. Test normal Quit App with a save dialog; Strict must hide that button.
4. Pair Chrome, Brave, Edge and Firefox via automatic link and backup code. Test timer sync and extension pause/resume/stop. Firefox's unsigned temporary add-on needs reloading after a browser restart.
5. Check timed/indefinite Focus, Pomodoro breaks, waiting phases and paused timers. Add time while running and paused. Quit must be absent during every session.
6. Test Nuclear account verification, required-password Add Time, rejected passwords, no pause/rule edits, two monthly emergency ends and canceling a check. Test normal Pause checks versus harder Stop checks.
7. Kill only the main process during a timed session and verify recovery; then kill only the watcher. Check resumed state and window restoration after a deadline. This is a recovery test, not a promise that both processes cannot be killed.
8. Test Block AI on normal Google search and AI Mode, including Never Block exceptions.

Automated core tests run on every build. The source has been compiled against Windows desktop reference assemblies, but the interactive checks above require a real Windows session.
