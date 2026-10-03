#pragma once

#include <string>
#include <string_view>

// Text encoding at the boundary. Spellbook holds text as UTF-8 internally and
// converts to UTF-16 (wchar_t) only where it calls a Win32 W API. These are
// written in standard C++ so core stays free of Windows headers and every case
// is unit-testable; wchar_t is UTF-16 on the only platform Spellbook targets.

namespace spellbook::core
{

static_assert(sizeof(wchar_t) == 2, "Spellbook targets Windows, where wchar_t is a UTF-16 code unit");

// True when every byte sequence in `text` is well-formed UTF-8 (no overlong
// forms, no surrogates, nothing above U+10FFFF). The import path (M2) uses this
// to tell UTF-8 files from legacy code-page files.
[[nodiscard]] bool is_valid_utf8(std::string_view text) noexcept;

// UTF-8 to UTF-16. Malformed sequences become U+FFFD, one per maximal invalid
// subpart, so a bad byte never truncates or drops the text after it.
[[nodiscard]] std::wstring utf8_to_wide(std::string_view text);

// UTF-16 to UTF-8. An unpaired surrogate becomes U+FFFD.
[[nodiscard]] std::string wide_to_utf8(std::wstring_view text);

}  // namespace spellbook::core
