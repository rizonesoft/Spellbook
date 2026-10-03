#include <string>
#include <string_view>

#include <catch2/catch_test_macros.hpp>

#include "spellbook/core/text.hpp"

using spellbook::core::is_valid_utf8;
using spellbook::core::utf8_to_wide;
using spellbook::core::wide_to_utf8;

namespace
{
// Spells real prompts carry: accents, CJK, emoji (outside the BMP), and punctuation.
constexpr std::string_view kMixedUtf8 = "Caf\xC3\xA9 \xE6\x97\xA5\xE6\x9C\xAC \xF0\x9F\xAA\x84 {{name}}";
constexpr std::wstring_view kMixedWide = L"Caf\u00E9 \u65E5\u672C \U0001FA84 {{name}}";
}  // namespace

TEST_CASE("utf8_to_wide converts ASCII, multi-byte, and astral text", "[text]")
{
    CHECK(utf8_to_wide("").empty());
    CHECK(utf8_to_wide("plain") == L"plain");
    CHECK(utf8_to_wide(kMixedUtf8) == kMixedWide);
}

TEST_CASE("wide_to_utf8 converts back, surrogate pairs included", "[text]")
{
    CHECK(wide_to_utf8(L"").empty());
    CHECK(wide_to_utf8(kMixedWide) == kMixedUtf8);
}

TEST_CASE("UTF-8 and UTF-16 round-trip without loss", "[text]")
{
    CHECK(wide_to_utf8(utf8_to_wide(kMixedUtf8)) == kMixedUtf8);
    CHECK(utf8_to_wide(wide_to_utf8(kMixedWide)) == kMixedWide);
}

TEST_CASE("utf8_to_wide replaces each maximal invalid subpart with one U+FFFD", "[text]")
{
    CHECK(utf8_to_wide("a\x80"
                       "b") == L"a\uFFFDb");     // stray continuation byte
    CHECK(utf8_to_wide("a\xC3") == L"a\uFFFD");  // truncated at the end
    CHECK(utf8_to_wide("\xE6\x97"
                       "x") == L"\uFFFDx");              // truncated 3-byte form: one U+FFFD, x kept
    CHECK(utf8_to_wide("\xC0\xAF") == L"\uFFFD\uFFFD");  // overlong '/' is two invalid bytes
    CHECK(utf8_to_wide("\xED\xA0\x80") == L"\uFFFD\uFFFD\uFFFD");            // encoded surrogate
    CHECK(utf8_to_wide("\xF4\x90\x80\x80") == L"\uFFFD\uFFFD\uFFFD\uFFFD");  // above U+10FFFF
}

TEST_CASE("wide_to_utf8 replaces an unpaired surrogate with U+FFFD", "[text]")
{
    const std::wstring lone_high{L'a', static_cast<wchar_t>(0xD83E), L'b'};
    const std::wstring lone_low{static_cast<wchar_t>(0xDE84)};
    CHECK(wide_to_utf8(lone_high) == "a\xEF\xBF\xBD"
                                     "b");
    CHECK(wide_to_utf8(lone_low) == "\xEF\xBF\xBD");
}

TEST_CASE("is_valid_utf8 accepts well-formed text and rejects malformed text", "[text]")
{
    CHECK(is_valid_utf8(""));
    CHECK(is_valid_utf8("plain ASCII"));
    CHECK(is_valid_utf8(kMixedUtf8));
    CHECK_FALSE(is_valid_utf8("\x80"));
    CHECK_FALSE(is_valid_utf8("Caf\xE9"));  // Windows-1252 "Caf\u00E9", the shape M2 import must detect
    CHECK_FALSE(is_valid_utf8("\xC0\xAF"));
    CHECK_FALSE(is_valid_utf8("\xED\xA0\x80"));
    CHECK_FALSE(is_valid_utf8("\xF5\x80\x80\x80"));
}
