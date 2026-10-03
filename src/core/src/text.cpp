#include "spellbook/core/text.hpp"

#include <cstdint>

namespace spellbook::core
{
namespace
{

constexpr char32_t kReplacement = 0xFFFD;

struct Decoded
{
    char32_t code_point;  // kReplacement when !valid
    bool valid;
};

// Decodes one code point starting at `i` and advances `i`. On a malformed
// sequence it consumes the maximal subpart (the longest valid prefix, or one
// byte), which is the substitution practice the Unicode Standard recommends
// (chapter 3, "U+FFFD Substitution of Maximal Subparts").
Decoded decode_one(std::string_view s, std::size_t& i) noexcept
{
    const auto byte = [&](std::size_t k) { return static_cast<std::uint8_t>(s[k]); };
    const std::uint8_t b0 = byte(i);
    if (b0 < 0x80)
    {
        ++i;
        return {b0, true};
    }

    std::size_t need = 0;
    char32_t cp = 0;
    std::uint8_t lo = 0x80;  // allowed range of the second byte
    std::uint8_t hi = 0xBF;
    if (b0 >= 0xC2 && b0 <= 0xDF)
    {
        need = 1;
        cp = b0 & 0x1Fu;
    }
    else if (b0 >= 0xE0 && b0 <= 0xEF)
    {
        need = 2;
        cp = b0 & 0x0Fu;
        if (b0 == 0xE0)
        {
            lo = 0xA0;  // no overlong forms
        }
        else if (b0 == 0xED)
        {
            hi = 0x9F;  // no surrogates
        }
    }
    else if (b0 >= 0xF0 && b0 <= 0xF4)
    {
        need = 3;
        cp = b0 & 0x07u;
        if (b0 == 0xF0)
        {
            lo = 0x90;  // no overlong forms
        }
        else if (b0 == 0xF4)
        {
            hi = 0x8F;  // nothing above U+10FFFF
        }
    }
    else
    {
        ++i;  // a stray continuation byte, C0, C1, or F5..FF
        return {kReplacement, false};
    }

    std::size_t k = i + 1;
    for (std::size_t n = 0; n < need; ++n, ++k)
    {
        const std::uint8_t first_lo = (n == 0) ? lo : std::uint8_t{0x80};
        const std::uint8_t first_hi = (n == 0) ? hi : std::uint8_t{0xBF};
        if (k >= s.size() || byte(k) < first_lo || byte(k) > first_hi)
        {
            i = k;  // the valid prefix is the maximal subpart; the failing byte is reread
            return {kReplacement, false};
        }
        cp = (cp << 6) | (byte(k) & 0x3Fu);
    }
    i = k;
    return {cp, true};
}

void append_utf16(std::wstring& out, char32_t cp)
{
    if (cp < 0x10000)
    {
        out.push_back(static_cast<wchar_t>(cp));
        return;
    }
    cp -= 0x10000;
    out.push_back(static_cast<wchar_t>(0xD800 + (cp >> 10)));
    out.push_back(static_cast<wchar_t>(0xDC00 + (cp & 0x3FF)));
}

void append_utf8(std::string& out, char32_t cp)
{
    if (cp < 0x80)
    {
        out.push_back(static_cast<char>(cp));
    }
    else if (cp < 0x800)
    {
        out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
    else if (cp < 0x10000)
    {
        out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
    else
    {
        out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
}

}  // namespace

bool is_valid_utf8(std::string_view text) noexcept
{
    std::size_t i = 0;
    while (i < text.size())
    {
        if (!decode_one(text, i).valid)
        {
            return false;
        }
    }
    return true;
}

std::wstring utf8_to_wide(std::string_view text)
{
    std::wstring out;
    out.reserve(text.size());
    std::size_t i = 0;
    while (i < text.size())
    {
        append_utf16(out, decode_one(text, i).code_point);
    }
    return out;
}

std::string wide_to_utf8(std::wstring_view text)
{
    std::string out;
    out.reserve(text.size());
    for (std::size_t i = 0; i < text.size(); ++i)
    {
        const auto unit = static_cast<char32_t>(text[i]);
        if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < text.size())
        {
            const auto next = static_cast<char32_t>(text[i + 1]);
            if (next >= 0xDC00 && next <= 0xDFFF)
            {
                append_utf8(out, 0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00));
                ++i;
                continue;
            }
        }
        if (unit >= 0xD800 && unit <= 0xDFFF)
        {
            append_utf8(out, kReplacement);  // unpaired surrogate
            continue;
        }
        append_utf8(out, unit);
    }
    return out;
}

}  // namespace spellbook::core
