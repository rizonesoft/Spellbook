#pragma once

#include <filesystem>
#include <optional>

namespace spellbook::app
{
struct LaunchOptions
{
    std::optional<std::filesystem::path> data_dir;
    bool smoke = false;
};
}  // namespace spellbook::app
