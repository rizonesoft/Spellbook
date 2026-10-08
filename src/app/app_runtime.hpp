#pragma once

#include <filesystem>
#include <optional>
#include <string_view>

namespace spellbook::app
{
struct LaunchOptions
{
    std::optional<std::filesystem::path> data_dir;
    bool smoke = false;
};

void show_startup_error(std::wstring_view reason);
}  // namespace spellbook::app
