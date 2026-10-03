#include "main_window.hpp"

#include <commctrl.h>
#include <dwmapi.h>

#include <string>

#include <spdlog/spdlog.h>

#include "spellbook/core/text.hpp"
#include "spellbook/core/version.hpp"

#include "res/resource.h"

namespace spellbook::app
{
namespace
{

constexpr wchar_t kClassName[] = L"Spellbook.MainWindow";
constexpr int kInitialWidthDip = 960;
constexpr int kInitialHeightDip = 640;
constexpr int kMinWidthDip = 480;
constexpr int kMinHeightDip = 320;
constexpr COLORREF kDarkBackground = RGB(0x20, 0x20, 0x20);
constexpr COLORREF kDarkText = RGB(0xF3, 0xF3, 0xF3);
constexpr COLORREF kDarkSubtleText = RGB(0xA0, 0xA0, 0xA0);
constexpr COLORREF kLightSubtleText = RGB(0x5F, 0x5F, 0x5F);
// DWMWA_USE_IMMERSIVE_DARK_MODE: named in the Windows 11 SDK; 20 since Windows 10 20H1.
constexpr DWORD kDwmUseImmersiveDarkMode = 20;

int scale(int dip, UINT dpi)
{
    return MulDiv(dip, static_cast<int>(dpi), USER_DEFAULT_SCREEN_DPI);
}

// The "Choose your app mode" setting: AppsUseLightTheme = 0 means dark.
bool apps_use_dark_theme()
{
    DWORD value = 1;
    DWORD size = sizeof(value);
    const LSTATUS rc =
        RegGetValueW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                     L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &value, &size);
    return rc == ERROR_SUCCESS && value == 0;
}

}  // namespace

MainWindow* MainWindow::create(HINSTANCE instance, const Options& options)
{
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = &MainWindow::window_proc;
    wc.hInstance = instance;
    wc.hIcon = LoadIconW(instance, MAKEINTRESOURCEW(IDI_SPELLBOOK));
    wc.hIconSm = wc.hIcon;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = nullptr;  // painted in WM_PAINT, in the theme's colour
    wc.lpszClassName = kClassName;
    if (RegisterClassExW(&wc) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS)
    {
        spdlog::error("RegisterClassExW failed: {}", GetLastError());
        return nullptr;
    }

    auto* self = new MainWindow(options);
    const UINT dpi = GetDpiForSystem();
    const std::wstring title = core::utf8_to_wide(core::app_name());
    HWND hwnd = CreateWindowExW(0, kClassName, title.c_str(), WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,
                                CW_USEDEFAULT, scale(kInitialWidthDip, dpi), scale(kInitialHeightDip, dpi),
                                nullptr, nullptr, instance, self);
    if (hwnd == nullptr)
    {
        spdlog::error("CreateWindowExW failed: {}", GetLastError());
        delete self;  // WM_NCCREATE never stored it
        return nullptr;
    }
    ShowWindow(hwnd, options.show_command);
    UpdateWindow(hwnd);
    return self;
}

MainWindow::~MainWindow()
{
    if (heading_font_ != nullptr)
    {
        DeleteObject(heading_font_);
    }
    if (body_font_ != nullptr)
    {
        DeleteObject(body_font_);
    }
    if (background_ != nullptr)
    {
        DeleteObject(background_);
    }
    if (icon_big_ != nullptr)
    {
        DestroyIcon(icon_big_);
    }
    if (icon_small_ != nullptr)
    {
        DestroyIcon(icon_small_);
    }
}

LRESULT CALLBACK MainWindow::window_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
{
    MainWindow* self = nullptr;
    if (msg == WM_NCCREATE)
    {
        const auto* cs = reinterpret_cast<const CREATESTRUCTW*>(lparam);
        self = static_cast<MainWindow*>(cs->lpCreateParams);
        self->hwnd_ = hwnd;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    else
    {
        self = reinterpret_cast<MainWindow*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    }

    if (self == nullptr)
    {
        return DefWindowProcW(hwnd, msg, wparam, lparam);
    }
    if (msg == WM_NCDESTROY)
    {
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
        delete self;
        return DefWindowProcW(hwnd, msg, wparam, lparam);
    }
    return self->handle(msg, wparam, lparam);
}

LRESULT MainWindow::handle(UINT msg, WPARAM wparam, LPARAM lparam)
{
    switch (msg)
    {
    case WM_CREATE:
        on_create();
        return 0;
    case WM_DPICHANGED:
        on_dpi_changed(HIWORD(wparam), reinterpret_cast<const RECT*>(lparam));
        return 0;
    case WM_SETTINGCHANGE:
        if (lparam != 0 && lstrcmpiW(reinterpret_cast<LPCWSTR>(lparam), L"ImmersiveColorSet") == 0)
        {
            apply_theme();
            InvalidateRect(hwnd_, nullptr, TRUE);
        }
        return 0;
    case WM_GETMINMAXINFO:
    {
        auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
        info->ptMinTrackSize = {scale(kMinWidthDip, dpi_), scale(kMinHeightDip, dpi_)};
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;  // WM_PAINT fills the whole client area
    case WM_PAINT:
        paint();
        return 0;
    case WM_CLOSE:
        DestroyWindow(hwnd_);
        return 0;
    case WM_DESTROY:
        spdlog::info("Main window closed");
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(hwnd_, msg, wparam, lparam);
    }
}

void MainWindow::on_create()
{
    dpi_ = GetDpiForWindow(hwnd_);
    apply_theme();
    rebuild_fonts();
    update_icons();
    spdlog::info("Main window created at {} DPI ({} theme)", dpi_, dark_ ? "dark" : "light");
}

void MainWindow::on_dpi_changed(UINT dpi, const RECT* suggested)
{
    dpi_ = dpi;
    rebuild_fonts();
    update_icons();
    SetWindowPos(hwnd_, nullptr, suggested->left, suggested->top, suggested->right - suggested->left,
                 suggested->bottom - suggested->top, SWP_NOZORDER | SWP_NOACTIVATE);
    InvalidateRect(hwnd_, nullptr, TRUE);
}

void MainWindow::apply_theme()
{
    dark_ = apps_use_dark_theme();
    const BOOL use_dark = dark_ ? TRUE : FALSE;
    // Best effort: an older Windows ignores the attribute and keeps a light title bar.
    DwmSetWindowAttribute(hwnd_, kDwmUseImmersiveDarkMode, &use_dark, sizeof(use_dark));
    if (background_ != nullptr)
    {
        DeleteObject(background_);
    }
    background_ = CreateSolidBrush(dark_ ? kDarkBackground : GetSysColor(COLOR_WINDOW));
}

void MainWindow::rebuild_fonts()
{
    NONCLIENTMETRICSW metrics{};
    metrics.cbSize = sizeof(metrics);
    if (!SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0, dpi_))
    {
        return;  // keep the previous fonts; painting falls back to the stock font if none
    }
    LOGFONTW body = metrics.lfMessageFont;
    LOGFONTW heading = metrics.lfMessageFont;
    heading.lfHeight = MulDiv(heading.lfHeight, 2, 1);
    heading.lfWeight = FW_SEMIBOLD;

    if (heading_font_ != nullptr)
    {
        DeleteObject(heading_font_);
    }
    if (body_font_ != nullptr)
    {
        DeleteObject(body_font_);
    }
    heading_font_ = CreateFontIndirectW(&heading);
    body_font_ = CreateFontIndirectW(&body);
}

void MainWindow::update_icons()
{
    HINSTANCE instance = GetModuleHandleW(nullptr);
    HICON big_icon = nullptr;
    HICON small_icon = nullptr;
    LoadIconWithScaleDown(instance, MAKEINTRESOURCEW(IDI_SPELLBOOK), GetSystemMetricsForDpi(SM_CXICON, dpi_),
                          GetSystemMetricsForDpi(SM_CYICON, dpi_), &big_icon);
    LoadIconWithScaleDown(instance, MAKEINTRESOURCEW(IDI_SPELLBOOK),
                          GetSystemMetricsForDpi(SM_CXSMICON, dpi_),
                          GetSystemMetricsForDpi(SM_CYSMICON, dpi_), &small_icon);
    // Not "small": <rpcndr.h> defines it as a macro.
    if (big_icon != nullptr)
    {
        SendMessageW(hwnd_, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(big_icon));
        if (icon_big_ != nullptr)
        {
            DestroyIcon(icon_big_);
        }
        icon_big_ = big_icon;
    }
    if (small_icon != nullptr)
    {
        SendMessageW(hwnd_, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(small_icon));
        if (icon_small_ != nullptr)
        {
            DestroyIcon(icon_small_);
        }
        icon_small_ = small_icon;
    }
}

void MainWindow::paint()
{
    PAINTSTRUCT ps{};
    HDC dc = BeginPaint(hwnd_, &ps);
    RECT client{};
    GetClientRect(hwnd_, &client);
    FillRect(dc, &client, background_ != nullptr ? background_ : GetSysColorBrush(COLOR_WINDOW));

    SetBkMode(dc, TRANSPARENT);
    const COLORREF text = dark_ ? kDarkText : GetSysColor(COLOR_WINDOWTEXT);
    const COLORREF subtle = dark_ ? kDarkSubtleText : kLightSubtleText;

    // UI copy uses the theme vocabulary sparingly, with the plain meaning beside it
    // (standards/ui.md). The string table that makes it switchable lands in M1.
    const bool empty = options_.prompt_count == 0;
    const std::wstring heading = empty ? L"Your grimoire is empty" : L"Your grimoire is open";
    const std::wstring detail =
        empty ? L"Spells (your saved prompts) will appear here."
              : std::to_wstring(options_.prompt_count) + L" spells (saved prompts) stored.";

    const int gap = scale(8, dpi_);
    RECT heading_rect = client;
    RECT detail_rect = client;
    HGDIOBJ old =
        SelectObject(dc, heading_font_ != nullptr ? heading_font_ : GetStockObject(DEFAULT_GUI_FONT));
    RECT measure = client;
    DrawTextW(dc, heading.c_str(), -1, &measure, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
    const int heading_height = measure.bottom - measure.top;
    const int middle = (client.top + client.bottom) / 2;
    heading_rect.top = middle - heading_height - gap / 2;
    heading_rect.bottom = middle - gap / 2;
    SetTextColor(dc, text);
    DrawTextW(dc, heading.c_str(), -1, &heading_rect, DT_CENTER | DT_SINGLELINE | DT_BOTTOM | DT_NOPREFIX);

    SelectObject(dc, body_font_ != nullptr ? body_font_ : GetStockObject(DEFAULT_GUI_FONT));
    detail_rect.top = middle + gap / 2;
    SetTextColor(dc, subtle);
    DrawTextW(dc, detail.c_str(), -1, &detail_rect, DT_CENTER | DT_SINGLELINE | DT_TOP | DT_NOPREFIX);

    SelectObject(dc, old);
    EndPaint(hwnd_, &ps);
}

}  // namespace spellbook::app
