// Spellbook.exe entry point: parse the command line, set up logging and the
// database, open the main window, and run the message loop.
//
// Command line (for development, CI, and support; not shown to users):
//   --data-dir <path>   use <path> instead of %LOCALAPPDATA%\Spellbook
//   --smoke             start fully, paint the window once, then exit 0
//                       (the launch smoke run by scripts/run.ps1 -Smoke and CI)

#include <windows.h>

#include <commctrl.h>
#include <shellapi.h>

#include <exception>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include <spdlog/spdlog.h>

#include "spellbook/core/text.hpp"
#include "spellbook/core/version.hpp"
#include "spellbook/storage/sqlite_prompt_repository.hpp"

#include "app_paths.hpp"
#include "logging.hpp"
#include "main_window.hpp"

namespace
{

struct CommandLine
{
    std::optional<std::filesystem::path> data_dir;
    bool smoke = false;
};

CommandLine parse_command_line()
{
    CommandLine cl;
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argv == nullptr)
    {
        return cl;
    }
    for (int i = 1; i < argc; ++i)
    {
        const std::wstring arg = argv[i];
        if (arg == L"--smoke")
        {
            cl.smoke = true;
        }
        else if (arg == L"--data-dir" && i + 1 < argc)
        {
            cl.data_dir = std::filesystem::path{argv[++i]};
        }
    }
    LocalFree(reinterpret_cast<HLOCAL>(argv));
    return cl;
}

void show_fatal(const std::string& message_utf8)
{
    const std::wstring text = spellbook::core::utf8_to_wide("Spellbook could not start.\n\n" + message_utf8);
    const std::wstring caption = spellbook::core::utf8_to_wide(spellbook::core::app_name());
    MessageBoxW(nullptr, text.c_str(), caption.c_str(), MB_OK | MB_ICONERROR);
}

int run(HINSTANCE instance, int show_command, const CommandLine& cl)
{
    INITCOMMONCONTROLSEX icc{sizeof(icc), ICC_STANDARD_CLASSES | ICC_WIN95_CLASSES};
    InitCommonControlsEx(&icc);

    const std::filesystem::path data_dir = cl.data_dir.value_or(spellbook::app::default_data_dir());
    std::filesystem::create_directories(data_dir);
    spellbook::app::init_logging(spellbook::app::log_dir(data_dir));

    const std::filesystem::path db_path = spellbook::app::database_path(data_dir);
    auto repository = spellbook::storage::SqlitePromptRepository::open(db_path);
    const auto& migration = repository.migration();
    spdlog::info("Database {} at schema version {} (was {})",
                 spellbook::core::wide_to_utf8(db_path.wstring()), migration.to_version,
                 migration.from_version);

    spellbook::app::MainWindow::Options options;
    options.prompt_count = repository.prompt_count();
    options.show_command = cl.smoke ? SW_SHOWNOACTIVATE : show_command;
    spellbook::app::MainWindow* window = spellbook::app::MainWindow::create(instance, options);
    if (window == nullptr)
    {
        throw std::runtime_error("the main window could not be created; see the log for the Windows error");
    }
    if (cl.smoke)
    {
        spdlog::info("Smoke run: window painted, closing");
        PostMessageW(window->hwnd(), WM_CLOSE, 0, 0);
    }

    MSG msg{};
    BOOL got = 0;
    while ((got = GetMessageW(&msg, nullptr, 0, 0)) != 0)
    {
        if (got == -1)
        {
            throw std::runtime_error("GetMessageW failed");
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    spdlog::info("{} exiting", spellbook::core::version_banner());
    return static_cast<int>(msg.wParam);
}

}  // namespace

int WINAPI wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE /*previous*/, _In_ LPWSTR /*command_line*/,
                    _In_ int show_command)
{
    const CommandLine cl = parse_command_line();
    int code = 1;
    try
    {
        code = run(instance, show_command, cl);
    }
    catch (const std::exception& e)
    {
        spdlog::critical("Fatal: {}", e.what());
        if (!cl.smoke)  // a smoke run is unattended: report through the exit code and the log only
        {
            show_fatal(e.what());
        }
    }
    spellbook::app::shutdown_logging();
    return code;
}
