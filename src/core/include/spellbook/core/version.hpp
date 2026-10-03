#pragma once

#include <string>
#include <string_view>

namespace spellbook::core
{

// The product name, as shown in the title bar, the About box, and file metadata.
[[nodiscard]] std::string_view app_name() noexcept;

// The SemVer version this binary was built as, derived from git tags at configure
// time (cmake/SpellbookVersion.cmake), for example "0.1.0" or "0.0.0-alpha.12".
[[nodiscard]] std::string_view version() noexcept;

// "Spellbook 0.1.0": the one-line identity written at the top of every log.
[[nodiscard]] std::string version_banner();

}  // namespace spellbook::core
