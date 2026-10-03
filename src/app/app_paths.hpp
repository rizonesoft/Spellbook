#pragma once

#include <filesystem>

namespace spellbook::app
{

// %LOCALAPPDATA%\Spellbook: the database, the logs, and (from M5) settings.
// Throws std::runtime_error when Windows cannot name the folder.
[[nodiscard]] std::filesystem::path default_data_dir();

// The database file inside a data folder.
[[nodiscard]] std::filesystem::path database_path(const std::filesystem::path& data_dir);

// The log folder inside a data folder.
[[nodiscard]] std::filesystem::path log_dir(const std::filesystem::path& data_dir);

}  // namespace spellbook::app
