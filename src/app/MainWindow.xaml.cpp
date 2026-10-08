#include "MainWindow.xaml.h"

#include <filesystem>
#include <vector>

#include <spdlog/spdlog.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Interop.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.Windows.ApplicationModel.Resources.h>

#include "MainWindow.g.cpp"
#include "pch.h"

namespace winrt::Spellbook::implementation
{
namespace
{
constexpr int kInitialWidthDip = 960;
constexpr int kInitialHeightDip = 640;
constexpr int kMinimumWidthDip = 480;
constexpr int kMinimumHeightDip = 320;
constexpr DWORD kMaximumPathLength = 32768;

int window_dpi(MainWindow& window)
{
    const HWND handle = Microsoft::UI::GetWindowFromWindowId(window.AppWindow().Id());
    return static_cast<int>(GetDpiForWindow(handle));
}
}  // namespace

void MainWindow::update_size_limits()
{
    const int dpi = window_dpi(*this);
    const auto presenter = AppWindow().Presenter().as<Microsoft::UI::Windowing::OverlappedPresenter>();
    presenter.PreferredMinimumWidth(MulDiv(kMinimumWidthDip, dpi, USER_DEFAULT_SCREEN_DPI));
    presenter.PreferredMinimumHeight(MulDiv(kMinimumHeightDip, dpi, USER_DEFAULT_SCREEN_DPI));
}

void MainWindow::initialize(bool smoke)
{
    Microsoft::Windows::ApplicationModel::Resources::ResourceLoader strings;
    Title(strings.GetString(L"AppTitle"));
    SystemBackdrop(Microsoft::UI::Xaml::Media::MicaBackdrop{});
    ExtendsContentIntoTitleBar(true);
    SetTitleBar(TitleBar());

    std::vector<wchar_t> path(kMaximumPathLength);
    const auto length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (length == 0 || length >= path.size())
    {
        winrt::throw_last_error();
    }
    const auto icon = std::filesystem::path{path.data()}.parent_path() / L"spellbook.ico";
    AppWindow().SetIcon(icon.wstring());
    const int dpi = window_dpi(*this);
    AppWindow().Resize({MulDiv(kInitialWidthDip, dpi, USER_DEFAULT_SCREEN_DPI),
                        MulDiv(kInitialHeightDip, dpi, USER_DEFAULT_SCREEN_DPI)});
    update_size_limits();
    Root().Loaded(
        [weak = get_weak()](auto const&, auto const&)
        {
            if (auto window = weak.get())
            {
                window->Root().XamlRoot().Changed(
                    [weak](auto const&, auto const&)
                    {
                        if (auto live = weak.get())
                        {
                            live->update_size_limits();
                        }
                    });
            }
        });
    Closed([](auto const&, auto const&) { spdlog::info("Main window closed"); });
    spdlog::info("Main window created: WinUI 3, Mica, custom title bar");

    if (smoke)
    {
        Root().Loaded(
            [weak = get_weak()](auto const&, auto const&)
            {
                if (auto window = weak.get())
                {
                    window->rendering_ = Microsoft::UI::Xaml::Media::CompositionTarget::Rendering(
                        winrt::auto_revoke,
                        [weak](auto const&, auto const&)
                        {
                            if (auto live = weak.get())
                            {
                                live->rendering_.revoke();
                                if (!live->DispatcherQueue().TryEnqueue(
                                        Microsoft::UI::Dispatching::DispatcherQueuePriority::Low,
                                        [weak]
                                        {
                                            if (auto ready = weak.get())
                                            {
                                                spdlog::info("Smoke run: window painted, closing");
                                                ready->Close();
                                            }
                                        }))
                                {
                                    throw winrt::hresult_error(E_FAIL, L"Could not schedule smoke shutdown");
                                }
                            }
                        });
                }
            });
    }
}
}  // namespace winrt::Spellbook::implementation
