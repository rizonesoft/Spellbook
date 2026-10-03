#include "spellbook/core/version.hpp"

#include "spellbook/core/build_info.hpp"

namespace spellbook::core
{

std::string_view app_name() noexcept
{
    return "Spellbook";
}

std::string_view version() noexcept
{
    return build_info::kSemVer;
}

std::string version_banner()
{
    std::string banner{app_name()};
    banner += ' ';
    banner += version();
    return banner;
}

}  // namespace spellbook::core
