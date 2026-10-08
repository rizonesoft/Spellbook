#include "App.xaml.h"

#include <exception>
#include <utility>

#include <spdlog/spdlog.h>
#include <winrt/Microsoft.UI.Xaml.h>

#include "spellbook/core/text.hpp"

#include "MainWindow.xaml.h"
#include "app_paths.hpp"
#include "logging.hpp"
#include "pch.h"

namespace winrt::Spellbook::implementation
{
App::App(::spellbook::app::LaunchOptions options, int& exit_code)
    : options_(std::move(options))
    , exit_code_(exit_code)
{
    UnhandledException(
        [this](auto const&, Microsoft::UI::Xaml::UnhandledExceptionEventArgs const& args)
        {
            args.Handled(true);
            fail(args.Message());
        });
}

void App::fail(winrt::hstring const& message)
{
    exit_code_ = 1;
    spdlog::critical("Fatal: {}", winrt::to_string(message));
    if (!options_.smoke)
    {
        MessageBoxW(nullptr, message.c_str(), L"Spellbook", MB_OK | MB_ICONERROR);
    }
    Exit();
}

void App::OnLaunched(Microsoft::UI::Xaml::LaunchActivatedEventArgs const&)
{
    try
    {
        const auto data_dir = options_.data_dir ? *options_.data_dir : ::spellbook::app::default_data_dir();
        std::filesystem::create_directories(data_dir);
        ::spellbook::app::init_logging(::spellbook::app::log_dir(data_dir));
        const auto db_path = ::spellbook::app::database_path(data_dir);
        repository_.emplace(::spellbook::storage::SqlitePromptRepository::open(db_path));
        const auto& migration = repository_->migration();
        spdlog::info("Database {} at schema version {} (was {})",
                     ::spellbook::core::wide_to_utf8(db_path.wstring()), migration.to_version,
                     migration.from_version);

        auto window = winrt::make_self<MainWindow>();
        window->initialize(options_.smoke);
        window_ = window.as<Microsoft::UI::Xaml::Window>();
        window_.Activate();
    }
    catch (winrt::hresult_error const& error)
    {
        fail(error.message());
    }
    catch (std::exception const& error)
    {
        fail(winrt::to_hstring(error.what()));
    }
}
}  // namespace winrt::Spellbook::implementation
