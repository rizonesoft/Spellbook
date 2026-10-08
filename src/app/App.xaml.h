#pragma once

#include <optional>

#include "spellbook/storage/sqlite_prompt_repository.hpp"

#include "App.xaml.g.h"
#include "app_runtime.hpp"

namespace winrt::Spellbook::implementation
{
struct App : AppT<App>
{
    App(::spellbook::app::LaunchOptions options, int& exit_code);
    void OnLaunched(Microsoft::UI::Xaml::LaunchActivatedEventArgs const& args);

private:
    void fail(winrt::hstring const& message);

    ::spellbook::app::LaunchOptions options_;
    int& exit_code_;
    std::optional<::spellbook::storage::SqlitePromptRepository> repository_;
    Microsoft::UI::Xaml::Window window_{nullptr};
};
}  // namespace winrt::Spellbook::implementation
