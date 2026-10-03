#pragma once

#include <windows.h>

#include <cstdint>

namespace spellbook::app
{

// The top-level window. M0 shows an empty grimoire: a heading and one line of
// guidance, painted with the system message font at the window's DPI, in the
// light or dark colours the user chose for apps. M1 replaces the client area
// with the list and editor panes (todo/01-library/TODO-01).
class MainWindow
{
public:
    struct Options
    {
        std::int64_t prompt_count = 0;
        int show_command = SW_SHOWDEFAULT;
    };

    // Registers the window class and creates and shows the window. Returns
    // nullptr (and logs the Win32 error) when creation fails.
    static MainWindow* create(HINSTANCE instance, const Options& options);

    [[nodiscard]] HWND hwnd() const noexcept { return hwnd_; }

    MainWindow(const MainWindow&) = delete;
    MainWindow& operator=(const MainWindow&) = delete;
    MainWindow(MainWindow&&) = delete;
    MainWindow& operator=(MainWindow&&) = delete;
    ~MainWindow();

private:
    explicit MainWindow(const Options& options)
        : options_(options)
    {
    }
    static LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
    LRESULT handle(UINT msg, WPARAM wparam, LPARAM lparam);

    void on_create();
    void on_dpi_changed(UINT dpi, const RECT* suggested);
    void apply_theme();
    void rebuild_fonts();
    void update_icons();
    void paint();

    Options options_;
    HWND hwnd_ = nullptr;
    UINT dpi_ = USER_DEFAULT_SCREEN_DPI;
    bool dark_ = false;
    HFONT heading_font_ = nullptr;
    HFONT body_font_ = nullptr;
    HBRUSH background_ = nullptr;
    HICON icon_big_ = nullptr;
    HICON icon_small_ = nullptr;
};

}  // namespace spellbook::app
