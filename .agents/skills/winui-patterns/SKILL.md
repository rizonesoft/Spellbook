---
name: winui-patterns
description: Implement or review Spellbook's WinUI 3 app layer using its C++/WinRT ownership, XAML, binding, threading, resources, and native interoperability conventions. Use before changing src/app/.
---

# WinUI Patterns

Use `standards/ui.md` for visual and interaction policy and `standards/cpp.md` for C++ conventions. ADR 0002 selects WinUI 3, C++/WinRT, and an unpackaged self-contained folder. Read the current source before copying a pattern; generated headers under `artifacts/` are compiler evidence, never files to edit or commit.

## App and object lifetime

`src/app/app_entry.cpp` parses arguments, initializes a single-threaded WinRT apartment, and enters `Application::Start`. `App.xaml.cpp` owns bootstrap, repository lifetime, and the projected window reference. `MainWindow.xaml.cpp` is the current shell; `App` constructs its implementation with `winrt::make_self`, initializes it, retains the projected `Window`, and activates it. Use `winrt::make` for a projected object or `make_self` when implementation access is needed. Do not allocate XAML implementation objects with `new` or put them on the stack.

Keep event callbacks safe across closure: capture `get_weak()` for callbacks that should not keep a window alive, resolve it inside the callback, and return if expired. A callback on a long-lived publisher must be revoked when its consumer closes; use an event revoker or retain and remove its token. Avoid a strong-reference cycle from a publisher back to its owner. `MainWindow`'s rendering revoker and weak smoke callback show the local pattern. Keep coroutine state alive deliberately and cancel work on close; a strong reference prevents destruction but does not mean the window is still open.

## XAML and presentation adapters

Declare controls and layout in `.xaml`; code-behind translates UI events to service calls and displays results. `TreeView`, `ListView`, `TextBox`, `ContentDialog`, `NavigationView`, and `InfoBar` are WinUI controls. View models may hold selection, editable display state, and property notifications. Validation, autosave decisions, search, and persistence rules belong in core/storage, with tests below the UI.

Expose compiled-binding properties through the runtime class's `.idl`, implement the generated signatures, and raise `Microsoft::UI::Xaml::Data::INotifyPropertyChanged` for changing properties. `{x:Bind}` defaults to `OneTime`; specify `Mode=OneWay` or `Mode=TwoWay` deliberately. A collection that changes after binding needs an observable collection and UI-thread notifications. `TextBox.Text` normally updates its binding source on lost focus; live autosave must explicitly use `TextChanged` or a supported property-change update trigger, then call the core autosave policy.

Register new `.xaml`, `.idl`, headers, and every owned `.cpp` in `src/app/Spellbook.vcxproj`. Generated `.g.h`/`.g.cpp` files belong in `artifacts/build/<preset>/app-obj/GeneratedFiles`; include the generated implementation as the established window does. Keep source declarations unconditional so Debug and Release have the same owned-source coverage. The project force-includes `pch.h` to put COM declarations before C++/WinRT headers; it does not use a compiled precompiled header. Preserve that ordering.

## Threads and asynchronous actions

XAML objects have UI-thread affinity. Capture `DispatcherQueue()` on the UI thread before starting background work; use `Microsoft::UI::Dispatching::DispatcherQueue.TryEnqueue` to deliver a result. Check its boolean return: shutdown can reject work. Queue callbacks resolve a weak owner and check that the result still belongs to the current operation. Report unexpected failures through the action's error path; a canceled action may discard its result.

For a coroutine entered on the UI thread, capture `winrt::apartment_context` before `co_await winrt::resume_background()`, then `co_await` that saved context before accessing UI again. Keep exceptions inside an async action boundary that logs and reports them; do not let an exception escape `winrt::fire_and_forget`. Do not capture a coroutine lambda's short-lived closure by reference across suspension. Retain or cancel an operation intentionally, and keep database access serialized under its service owner rather than sharing a connection unsafely among workers.

**Pinned-header exception:** current Microsoft Learn examples suggest `winrt::resume_foreground` for a WinUI dispatcher. The pinned generated headers here expose that helper for `Windows::System::DispatcherQueue`, not `Microsoft::UI::Dispatching::DispatcherQueue`; they are different types. Use the supported `TryEnqueue` or UI-captured `apartment_context` patterns above. Do not silently add WIL, another adapter, or a second dispatcher. Recheck headers and compile a small probe before changing this choice after a package upgrade.

## Resources, dialogs, and errors

User-facing copy lives in `src/app/Strings/en-US/Resources.resw`. Use `x:Uid` with property-qualified keys for fixed XAML copy, or `Microsoft::Windows::ApplicationModel::Resources::ResourceLoader` for code-created text. The generated PRI is required at runtime. Themed/plain vocabulary selection belongs in the app resource adapter under D01 T01 §4; domain/schema/log names remain plain. `x:Uid` alone does not implement runtime vocabulary switching: refresh affected properties when the setting changes. Errors and destructive confirmations use plain meaning in either mode.

Assign a `ContentDialog` the live content root's `XamlRoot` before `ShowAsync`; serialize dialogs on a UI thread and restore sensible focus after dismissal. Await the user's result before a destructive service call. For expected recoverable errors, use a suitable dialog or `InfoBar`, naming the action and reason. `show_startup_error` is a deliberate native fallback before XAML/resources are available. Smoke paths log and return a failing exit code instead of showing any dialog.

## Theme, geometry, and interoperability

Use WinUI theme brushes/styles with `{ThemeResource}` and supported `RequestedTheme` on the content root for an explicit choice; the default follows the system. Provide usable high-contrast and opaque fallback behavior. `MainWindow` sets `MicaBackdrop`, extends content into the title bar, and registers its drag region with `SetTitleBar`; preserve caption-button clearance, drag behavior, keyboard access, and the app icon.

XAML layout and fonts use DIPs and scale automatically; do not multiply XAML dimensions by DPI. Native `AppWindow` resize/presenter bounds use pixels. The current shell converts 960 by 640 initial and 480 by 320 minimum DIPs at that boundary and refreshes minimum limits when `XamlRoot` changes. Verify layout at the contract's scales, including minimum size and text scaling.

Use native APIs only for a documented capability or boundary: current shell DPI lookup, command-line parsing, paths, and startup error fallback are examples; global hotkeys and tray integration are later planned interop. Keep handles/resources under RAII and W APIs at the boundary. Core/storage remain UTF-8 and cannot include Windows/WinRT headers. Use `winrt::to_hstring`/`to_string` or the existing strict text helpers at the relevant boundary. Keep `NOMINMAX` and the COM include order.

## Verify the change

Use the repository build-and-test runners. Exercise async failure, closure, keyboard/focus, theme/contrast, and DPI behavior relevant to the changed surface. Give interactive controls stable automation IDs and accessible names; IDs do not replace accessible names. The UI-driver and visual-matrix sections own the shared automation infrastructure. Tests always use isolated `--data-dir`; smoke additionally requires that argument. Never claim a screenshot alone proves persistence: read back the isolated database and cite the action log without prompt text.

## Primary references

- [Ownership and weak references](https://learn.microsoft.com/en-us/windows/apps/develop/cpp-winrt/weak-references)
- [Observable properties and compiled binding](https://learn.microsoft.com/en-us/windows/apps/develop/cpp-winrt/binding-property)
- [Threading and coroutine contexts](https://learn.microsoft.com/en-us/windows/apps/develop/cpp-winrt/concurrency-2), read with the pinned-header exception above
- [Windows App SDK threading migration](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/guides/threading)
- [Resource identifiers](https://learn.microsoft.com/en-us/windows/apps/develop/platform/xaml/x-uid-directive), [dialogs](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/dialogs-and-flyouts/dialogs), and [title bars](https://learn.microsoft.com/en-us/windows/apps/develop/title-bar?tabs=winui3)

Codex owns this independent skill. Follow `AGENTS.md` for writer selection, review, and commits.
