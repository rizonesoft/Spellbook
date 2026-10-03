#include "logging.hpp"

#include <memory>
#include <string>
#include <vector>

#include <spdlog/sinks/msvc_sink.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/spdlog.h>

#include "spellbook/core/version.hpp"

namespace spellbook::app
{
namespace
{
constexpr std::size_t kMaxFileBytes = std::size_t{5} * 1024 * 1024;
constexpr std::size_t kMaxFiles = 5;
}  // namespace

void init_logging(const std::filesystem::path& log_dir)
{
    std::filesystem::create_directories(log_dir);

    // spdlog takes a narrow file name. The app manifest sets the process code page
    // to UTF-8, so a UTF-8 path opens correctly even under a non-ASCII user name.
    const std::u8string u8 = (log_dir / L"spellbook.log").u8string();
    const std::string file{reinterpret_cast<const char*>(u8.data()), u8.size()};

    std::vector<spdlog::sink_ptr> sinks;
    sinks.push_back(std::make_shared<spdlog::sinks::rotating_file_sink_mt>(file, kMaxFileBytes, kMaxFiles));
#ifndef NDEBUG
    sinks.push_back(std::make_shared<spdlog::sinks::msvc_sink_mt>());
#endif
    auto logger = std::make_shared<spdlog::logger>("spellbook", sinks.begin(), sinks.end());
    logger->set_pattern("%Y-%m-%d %H:%M:%S.%e [%l] %v");
    logger->set_level(spdlog::level::info);
    logger->flush_on(spdlog::level::info);
    spdlog::set_default_logger(logger);

    spdlog::info("{} starting", core::version_banner());
}

void shutdown_logging() noexcept
{
    spdlog::shutdown();
}

}  // namespace spellbook::app
