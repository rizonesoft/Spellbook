#include <regex>
#include <string>

#include <catch2/catch_test_macros.hpp>

#include "spellbook/core/version.hpp"

TEST_CASE("app_name is Spellbook", "[version]")
{
    CHECK(spellbook::core::app_name() == "Spellbook");
}

TEST_CASE("version is a SemVer string derived from git", "[version]")
{
    const std::string v{spellbook::core::version()};
    // MAJOR.MINOR.PATCH with an optional prerelease (0.0.0-alpha.12, 0.0.0-local).
    const std::regex semver{R"(^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$)"};
    CHECK(std::regex_match(v, semver));
}

TEST_CASE("version_banner joins the name and the version", "[version]")
{
    const std::string expected =
        std::string{spellbook::core::app_name()} + " " + std::string{spellbook::core::version()};
    CHECK(spellbook::core::version_banner() == expected);
}
