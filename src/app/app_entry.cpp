#include <shellapi.h>

#include <exception>
#include <stdexcept>
#include <string>
#include <string_view>

#include <spdlog/spdlog.h>
#include <winrt/Microsoft.UI.Xaml.h>

#include "spellbook/core/text.hpp"
#include "spellbook/core/version.hpp"

#include "App.xaml.h"
#include "logging.hpp"
#include "pch.h"

namespace
{
struct LocalArguments
{
    LPWSTR* value = nullptr;
    ~LocalArguments() { LocalFree(value); }
};

void parse_command_line(spellbook::app::LaunchOptions& options)
{
    int count = 0;
    const LocalArguments arguments{CommandLineToArgvW(GetCommandLineW(), &count)};
    if (!arguments.value)
    {
        throw std::runtime_error("Windows could not read the command line");
    }
    // Detect smoke before validation so malformed smoke invocations never show a dialog.
    for (int index = 1; index < count; ++index)
    {
        options.smoke = options.smoke || std::wstring_view{arguments.value[index]} == L"--smoke";
    }
    for (int index = 1; index < count; ++index)
    {
        const std::wstring_view argument{arguments.value[index]};
        if (argument == L"--smoke")
        {
            options.smoke = true;
        }
        else if (argument == L"--data-dir")
        {
            if (index + 1 >= count || std::wstring_view{arguments.value[index + 1]}.starts_with(L"--") ||
                std::wstring_view{arguments.value[index + 1]}.empty())
            {
                throw std::runtime_error("--data-dir requires a folder path");
            }
            options.data_dir = std::filesystem::path{arguments.value[++index]};
        }
        else
        {
            throw std::runtime_error("Unknown command-line option");
        }
    }
    if (options.smoke && !options.data_dir)
    {
        throw std::runtime_error("--smoke requires --data-dir to protect the user library");
    }
}
}  // namespace

namespace spellbook::app
{
void show_startup_error(std::wstring_view reason)
{
    // This fallback must work even before WinRT/XAML resources initialize.
    std::wstring message{L"Spellbook could not start.\n\n"};
    message.append(reason);
    const auto caption = core::utf8_to_wide(core::app_name());
    MessageBoxW(nullptr, message.c_str(), caption.c_str(), MB_OK | MB_ICONERROR);
}
}  // namespace spellbook::app

int WINAPI wWinMain(_In_ HINSTANCE, _In_opt_ HINSTANCE, _In_ LPWSTR, _In_ int)
{
    int exit_code = 0;
    spellbook::app::LaunchOptions options;
    try
    {
        parse_command_line(options);
        winrt::init_apartment(winrt::apartment_type::single_threaded);
        winrt::Microsoft::UI::Xaml::Application::Start(
            [&](auto const&) { winrt::make<winrt::Spellbook::implementation::App>(options, exit_code); });
        spdlog::info("{} exiting", spellbook::core::version_banner());
    }
    catch (winrt::hresult_error const& error)
    {
        spdlog::critical("Fatal: {}", winrt::to_string(error.message()));
        if (!options.smoke)
        {
            spellbook::app::show_startup_error(error.message().c_str());
        }
        exit_code = 1;
    }
    catch (std::exception const& error)
    {
        spdlog::critical("Fatal: {}", error.what());
        if (!options.smoke)
        {
            spellbook::app::show_startup_error(spellbook::core::utf8_to_wide(error.what()));
        }
        exit_code = 1;
    }
    spellbook::app::shutdown_logging();
    return exit_code;
}
