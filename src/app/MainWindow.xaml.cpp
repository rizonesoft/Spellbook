#include "MainWindow.xaml.h"

#include <filesystem>
#include <vector>

#include <microsoft.ui.xaml.window.h>
#include <spdlog/spdlog.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.Windows.ApplicationModel.Resources.h>

#include "MainWindow.g.cpp"
#include "pch.h"

namespace winrt::Spellbook::implementation
{
void MainWindow::initialize(bool smoke)
{
    Microsoft::Windows::ApplicationModel::Resources::ResourceLoader strings;
    Title(strings.GetString(L"AppTitle"));
    SystemBackdrop(Microsoft::UI::Xaml::Media::MicaBackdrop{});
    ExtendsContentIntoTitleBar(true);
    SetTitleBar(TitleBar());

    std::vector<wchar_t> path(32768);
    const auto length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (length == 0 || length >= path.size())
    {
        winrt::throw_last_error();
    }
    const auto icon = std::filesystem::path{path.data()}.parent_path() / L"spellbook.ico";
    AppWindow().SetIcon(icon.wstring());
    AppWindow().Resize({960, 640});
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
