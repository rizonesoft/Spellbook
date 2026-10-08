---
name: winui-patterns
description: Build and review Spellbook WinUI 3 surfaces in C++/WinRT, following the repository's XAML, lifetime, resource, threading, and interoperability patterns. Read for work in src/app/.
---

# Spellbook WinUI Surface Patterns

This skill is independently maintained for Claude. `CLAUDE.md` governs its workflow; `standards/ui.md` defines the product policy and `standards/cpp.md` defines code style. ADR 0002 owns the hybrid-build and self-contained-folder decisions.

## Start from the shipped shell

Read `src/app/app_entry.cpp`, `App.xaml.cpp`, `MainWindow.xaml.cpp`, and the matching XAML before editing. The entry point parses arguments, initializes the STA, and calls WinUI `Application::Start`. App owns startup services and a projected window reference. It constructs MainWindow through `winrt::make_self`, calls `initialize`, retains its projected `Window`, and activates it. Use `winrt::make` when only the projected interface is needed. XAML runtime implementations are reference-counted objects, never manually allocated/deleted or stack objects.

A new surface puts layout in XAML and event-to-service translation in code-behind. Use the actual WinUI control (`TreeView`, `ListView`, `TextBox`, `ContentDialog`, `NavigationView`, or `InfoBar`), retaining keyboard and accessibility behavior. Presentation models adapt service data into selection/display properties and notifications; business decisions, validation, autosave policy, SQL, and durable writes stay below app.

Add each XAML/IDL/header/source to `Spellbook.vcxproj`. Its unconditional owned-source entries are checked against the tree for all configurations. Build-generated headers and implementation fragments remain under `artifacts/build/<preset>/app-obj/GeneratedFiles`. Preserve the project's forced `pch.h` include: COM declarations must precede projected headers; this is not a compiled PCH. Follow the existing generated-implementation inclusion pattern instead of editing `.g.*` output.

## Binding and copy

Declare a runtime class's public binding properties in IDL, implement their generated accessors, and raise `INotifyPropertyChanged` when values change. `{x:Bind}` starts as `OneTime`; explicitly choose `OneWay` or `TwoWay` where live updates are required. Mutable bound collections need observable notifications delivered on the UI thread. A `TextBox.Text` source update normally waits for lost focus: use `TextChanged` or a supported property-change update trigger when the core autosave policy needs each edit.

Store all normal visible labels and tooltips in `Strings/en-US/Resources.resw`. Fixed XAML properties use `x:Uid` and property-qualified keys; code uses the MRT Core `ResourceLoader` from `Microsoft.Windows.ApplicationModel.Resources`. Ship the PRI alongside the app. The app vocabulary adapter planned in D01 T01 §4 selects themed/plain resources and refreshes visible properties on a settings change. Static `x:Uid` application does not perform that switch by itself. Logs and domain names stay plain; error and destructive-action copy is plain in both modes. A pre-XAML startup error is the explicit native fallback exception.

## Lifetime and thread changes

Capture weak references for callbacks that must not retain a closed surface. Resolve the weak reference in the callback, and stop when it is gone. Remove subscriptions to longer-lived publishers on close; retain event tokens or use revokers. Avoid a window-child callback cycle. A coroutine must retain the state it needs across suspension, but must separately check cancellation/closure even if a strong reference keeps the object alive. Avoid reference captures to a short-lived coroutine lambda closure.

Only the UI thread touches XAML objects and raises their notifications. Capture the window's `Microsoft::UI::Dispatching::DispatcherQueue` before leaving that thread, then post results with `TryEnqueue`. Its false return means the queue may be shutting down; do not pretend delivery succeeded. Ignore canceled or obsolete results, and report unexpected failures through the originating action. Background service work must serialize database access; do not concurrently reuse the startup connection from arbitrary worker threads.

A coroutine started on the UI thread may save `winrt::apartment_context`, `co_await winrt::resume_background()` for work, and await the saved context before touching controls again. Catch and report errors at the async action boundary, especially for `winrt::fire_and_forget`, where an uncaught exception is fatal. Never synchronously wait for an async result on the UI thread.

The currently pinned projection does not supply `winrt::resume_foreground` for the Microsoft UI queue. The overload in `Windows.System.h` takes a different `Windows::System::DispatcherQueue`; it is not interchangeable. Some current Learn examples obscure this distinction. Use the two supported patterns above and compile-check any replacement against the pinned headers. Adding WIL or an await adapter is a separate dependency/design decision, not an incidental documentation fix.

## Window appearance and interactions

XAML automatically scales DIP layout and typography. Keep spacing in the 4-DIP grid and use theme typography; do not manually DPI-scale control dimensions. `AppWindow` native bounds use physical pixels, so preserve the shell's conversion for initial 960 by 640 and minimum 480 by 320 DIP dimensions, including minimum-size refresh on a `XamlRoot` change.

Use theme resources for brushes/styles; an explicit user theme applies through supported `RequestedTheme` on the content root, while default follows Windows. Honor high contrast and opaque fallback. The shell uses `MicaBackdrop` plus `ExtendsContentIntoTitleBar` and `SetTitleBar`; keep drag regions, system caption controls, icon, and keyboard behavior usable when changing that area.

A `ContentDialog` needs the content element's live `XamlRoot` before `ShowAsync`. Queue dialogs rather than opening multiple simultaneously on one UI thread, await the result before changing data, and restore focus. Show a recoverable action error with meaningful context through the surface's dialog or `InfoBar`. Startup failures before XAML use `show_startup_error`; `--smoke` must never wait for a dialog.

Native interoperability remains deliberate and local: the shipped shell uses it for DPI lookup, paths, command-line arguments, and startup error fallback; planned hotkeys/tray integration also require it. Use W APIs and RAII. UTF-16/hstring is a UI boundary; core/storage text is UTF-8. Convert using `winrt::to_hstring`/`to_string` or existing strict text helpers as appropriate. No WinRT or Windows header enters the lower layers.

## Evidence to collect

Run the repository's build/test gates and the section checkpoint. Check a changed surface's keyboard route, focus, relevant DPI/text scaling, high contrast, and light/dark appearance. Stable automation IDs identify controls to the UI driver; accessible names tell assistive technology their meaning. They are distinct requirements. The planned UI driver and visual matrix own shared capture infrastructure. Use isolated `--data-dir` in every test; smoke requires it. Record a meaningful action log and database readback for writes, without logging prompt contents.

## Microsoft references

Consult [C++/WinRT lifetime](https://learn.microsoft.com/en-us/windows/apps/develop/cpp-winrt/weak-references), [binding properties](https://learn.microsoft.com/en-us/windows/apps/develop/cpp-winrt/binding-property), and [asynchronous contexts](https://learn.microsoft.com/en-us/windows/apps/develop/cpp-winrt/concurrency-2), checking the queue compatibility exception above against installed headers. For the surface itself use [resource IDs](https://learn.microsoft.com/en-us/windows/apps/develop/platform/xaml/x-uid-directive), [dialog controls](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/dialogs-and-flyouts/dialogs), [theme resources](https://learn.microsoft.com/en-us/windows/apps/develop/platform/xaml/xaml-theme-resources), and [title bar customization](https://learn.microsoft.com/en-us/windows/apps/develop/title-bar?tabs=winui3).
