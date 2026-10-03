#include <filesystem>
#include <memory>
#include <random>
#include <string>

#include <catch2/catch_test_macros.hpp>

#include "spellbook/storage/sqlite_prompt_repository.hpp"

using spellbook::storage::IPromptRepository;
using spellbook::storage::latest_schema_version;
using spellbook::storage::SqlitePromptRepository;
using spellbook::storage::StorageError;

TEST_CASE("a new in-memory repository is at schema version 1 with no prompts", "[repository]")
{
    auto repo = SqlitePromptRepository::open_in_memory();
    CHECK(repo.schema_version() == 1);
    CHECK(repo.schema_version() == latest_schema_version());
    CHECK(repo.prompt_count() == 0);
    CHECK(repo.migration().from_version == 0);
}

TEST_CASE("the repository is usable through IPromptRepository", "[repository]")
{
    std::unique_ptr<IPromptRepository> repo =
        std::make_unique<SqlitePromptRepository>(SqlitePromptRepository::open_in_memory());
    CHECK(repo->schema_version() == latest_schema_version());
    CHECK(repo->prompt_count() == 0);
}

TEST_CASE("schema 1 has every table the domain model names", "[repository][schema]")
{
    auto repo = SqlitePromptRepository::open_in_memory();
    for (const char* table : {"folders", "prompts", "tags", "prompt_tags", "prompt_versions", "prompts_fts"})
    {
        auto s = repo.database().prepare("SELECT COUNT(*) FROM sqlite_master WHERE name = ?");
        s.bind(1, table).step();
        INFO("table " << table);
        CHECK(s.column_int64(0) == 1);
    }
}

TEST_CASE("FTS5 indexes prompts through the triggers, with diacritics folded", "[repository][fts]")
{
    auto repo = SqlitePromptRepository::open_in_memory();
    auto& db = repo.database();
    db.exec("INSERT INTO prompts (title, body, created_at, updated_at) VALUES "
            "('Caf\xC3\xA9 review', 'Summarise this menu', 1, 1), ('Code review', 'Find the bug', 1, 1)");
    CHECK(repo.prompt_count() == 2);

    auto count_matches = [&](const char* query)
    {
        auto s = db.prepare("SELECT COUNT(*) FROM prompts_fts WHERE prompts_fts MATCH ?");
        s.bind(1, query).step();
        return s.column_int64(0);
    };
    CHECK(count_matches("review") == 2);
    CHECK(count_matches("cafe") == 1);  // remove_diacritics: "cafe" finds "Caf\u00E9"
    CHECK(count_matches("bug") == 1);

    db.exec("UPDATE prompts SET body = 'Find the regression' WHERE title = 'Code review'");
    CHECK(count_matches("bug") == 0);
    CHECK(count_matches("regression") == 1);

    db.exec("DELETE FROM prompts WHERE title = 'Code review'");
    CHECK(count_matches("regression") == 0);
}

TEST_CASE("foreign keys are enforced on every connection", "[repository][schema]")
{
    auto repo = SqlitePromptRepository::open_in_memory();
    CHECK_THROWS_AS(repo.database().exec("INSERT INTO prompt_tags (prompt_id, tag_id) VALUES (999, 999)"),
                    StorageError);
}

TEST_CASE("reopening a database file keeps its schema and data", "[repository]")
{
    std::random_device rd;
    const auto dir = std::filesystem::temp_directory_path() / ("spellbook-repo-" + std::to_string(rd()));
    std::filesystem::create_directories(dir);
    const auto file = dir / "spellbook.db";
    {
        auto repo = SqlitePromptRepository::open(file);
        CHECK(repo.migration().from_version == 0);
        repo.database().exec("INSERT INTO prompts (title, created_at, updated_at) VALUES ('kept', 1, 1)");
    }
    {
        auto repo = SqlitePromptRepository::open(file);
        CHECK(repo.migration().from_version == latest_schema_version());
        CHECK_FALSE(repo.migration().changed());
        CHECK(repo.prompt_count() == 1);
    }
    std::error_code ec;
    std::filesystem::remove_all(dir, ec);
}
