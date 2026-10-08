---
name: win32-ui-patterns
description: The Win32 patterns Spellbook's UI uses -- window classes and ownership, the message loop, child controls, DPI, dark mode, resources, Unicode, and the common pitfalls. Use before writing or reviewing anything in src/app/.
---

# Win32 UI Patterns

Spellbook's UI is plain Win32 with Common Controls v6. These are the patterns already in `src/app/` and the ones later sections must follow, so every window behaves the same. The policy (copy, vocabulary, colours) is in `standards/ui.md`.

## Window ownership

`MainWindow` (`src/app/main_window.cpp`) is the template:

- `create()` allocates the object and passes `this` as `lpCreateParams`.
- `WM_NCCREATE` stores it with `SetWindowLongPtrW(hwnd, GWLP_USERDATA, ...)` and sets `hwnd_`.
- Other messages fetch it with `GetWindowLongPtrW` and call the member `handle()`.
- `WM_NCDESTROY` clears the pointer and `delete`s the object: the window owns its C++ object, and nothing else deletes it.
- Every GDI object and icon the object creates is released in its destructor.

Child panes follow the same pattern with their own class name (`Spellbook.<Pane>`), or subclass a common control with `SetWindowSubclass` (comctl32), never `SetWindowLongPtr(GWLP_WNDPROC)`.

## The message loop

`main.cpp` runs `GetMessageW` / `TranslateMessage` / `DispatchMessageW`. When accelerators arrive (`D01 T01 §6`), they go through one `TranslateAcceleratorW` for the main window, and modeless dialogs through `IsDialogMessageW`, both before `TranslateMessage`. Handle `GetMessageW` returning -1.

## Creating controls

- Create children in `WM_CREATE`, size them in `WM_SIZE` (one layout function), never at fixed pixel positions.
- Common controls: `InitCommonControlsEx` once in `main.cpp` (already done for standard and Win95 classes).
- Set the font on every child with `WM_SETFONT` using the window's DPI-scaled message font; rebuild and resend it on `WM_DPICHANGED`.
- Give every control an id (`IDC_*` in `res/resource.h`) and handle `WM_COMMAND` and `WM_NOTIFY` in the parent by id.
- Labels come from the vocabulary table (`D01 T01 §4`), converted with `core::utf8_to_wide`.

## DPI

- Per-Monitor-V2 is declared in `res/spellbook.manifest`; do not call `SetProcessDpiAwareness*` as well.
- Scale every DIP value with `MulDiv(dip, dpi, USER_DEFAULT_SCREEN_DPI)` using `GetDpiForWindow(hwnd)`.
- Metrics: `GetSystemMetricsForDpi`, `SystemParametersInfoForDpi`. Never the DPI-unaware versions.
- `WM_DPICHANGED`: update `dpi_`, rebuild fonts and icons, `SetWindowPos` to the suggested `RECT` in `lParam`, relayout.
- Icons: `LoadIconWithScaleDown` at `SM_CXICON` / `SM_CXSMICON` for the DPI, sent with `WM_SETICON`.

## Dark mode

- Title bar: `DwmSetWindowAttribute(hwnd, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &use_dark, sizeof(BOOL))`.
- Detect: `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme` (0 = dark). Re-read on `WM_SETTINGCHANGE` with `lParam` "ImmersiveColorSet".
- Tree and list views: `SetWindowTheme(hwnd, L"DarkMode_Explorer", nullptr)`. Edits and statics: `WM_CTLCOLOREDIT` / `WM_CTLCOLORSTATIC` returning a brush the window owns. Full treatment is `D05 T01 §1`.

## Painting

- Return 1 from `WM_ERASEBKGND` and fill the whole client area in `WM_PAINT` to avoid flicker.
- `BeginPaint` / `EndPaint` always in pairs; restore the old font with `SelectObject` before `EndPaint`.

## Resources and the manifest

- `res/spellbook.rc` holds the icon and embeds `res/spellbook.manifest` as `RT_MANIFEST` id 1; the linker's own manifest is off (`/MANIFEST:NO`). The version block is generated from `res/version.rc.in`.
- New dialogs prefer code-built layouts (DPI-correct by construction) over `.rc` `DIALOGEX` templates; if a template is used, it uses `DS_SHELLFONT` and "MS Shell Dlg 2".

## Unicode

W APIs only (`UNICODE` is defined for every target). Convert at the boundary with `core::utf8_to_wide` and `core::wide_to_utf8`. `wchar_t` buffers sized from the API's reported length, never a guessed `MAX_PATH`.

## Threads

The UI thread never waits on disk or the database for longer than a frame. Work runs on a `std::jthread`; results return with `PostMessageW(hwnd, WM_APP + n, ...)` carrying an owned pointer the handler deletes. Never touch an HWND from a worker thread.

## Pitfalls

- `small` and `near`/`far` are macros from `<rpcndr.h>`: never name a variable `small`.
- `min` and `max` macros: `NOMINMAX` is defined for every target; keep it.
- `GetMessageW` returns -1 on error; `while (GetMessageW(...))` treats that as a message.
- `CommandLineToArgvW` memory is freed with `LocalFree`.
- `SetWindowLongPtrW` returns 0 both for "previous value 0" and for failure; check `GetLastError` when it matters.
- A message box during `--smoke` hangs CI: unattended paths report through the exit code and the log only.
- Screenshots from a DPI-unaware PowerShell are offset at scaling above 100 percent; capture from a DPI-aware tool or account for it.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
