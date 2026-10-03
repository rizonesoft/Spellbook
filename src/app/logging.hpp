#pragma once

#include <filesystem>

namespace spellbook::app
{

// Sends spdlog's default logger to <log_dir>\spellbook.log (rotating: 5 files of
// 5 MB) and, in Debug builds, to the debugger output window. Call once, first.
void init_logging(const std::filesystem::path& log_dir);

// Flushes and closes every sink. Call once, last.
void shutdown_logging() noexcept;

}  // namespace spellbook::app
