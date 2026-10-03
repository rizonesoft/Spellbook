#pragma once

#include <filesystem>

#include "spellbook/storage/database.hpp"
#include "spellbook/storage/migrations.hpp"
#include "spellbook/storage/prompt_repository.hpp"

namespace spellbook::storage
{

// IPromptRepository over one SQLite file with FTS5. Opening it configures the
// connection (foreign keys on, WAL journal for files, a busy timeout) and
// applies every pending migration, so a repository that exists is a
// repository at the current schema.
class SqlitePromptRepository final : public IPromptRepository
{
public:
    // Opens or creates the database file. The parent folder must exist.
    [[nodiscard]] static SqlitePromptRepository open(const std::filesystem::path& file);
    // A private in-memory store at the current schema, for tests.
    [[nodiscard]] static SqlitePromptRepository open_in_memory();

    [[nodiscard]] int schema_version() const override;
    [[nodiscard]] std::int64_t prompt_count() const override;

    // What opening did to the schema (from and to versions), for the log.
    [[nodiscard]] const MigrationResult& migration() const noexcept { return migration_; }

    // The connection, for storage-level tests and the dev migrate tool.
    [[nodiscard]] Database& database() noexcept { return db_; }

private:
    SqlitePromptRepository(Database db, bool is_file);
    Database db_;
    MigrationResult migration_{0, 0};
};

}  // namespace spellbook::storage
