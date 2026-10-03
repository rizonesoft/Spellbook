#pragma once

#include <span>
#include <string_view>

namespace spellbook::storage
{

class Database;

// One schema step: migrations/NNNN_name.sql, embedded into the binary at build
// time by cmake/EmbedMigrations.cmake. `version` is NNNN; versions run 1, 2, 3
// with no gaps (the build fails on a gap).
struct Migration
{
    int version;
    std::string_view name;
    std::string_view sql;
};

// Every migration in migrations/, in version order.
[[nodiscard]] std::span<const Migration> embedded_migrations() noexcept;

// The schema version this build creates: the highest embedded migration.
[[nodiscard]] int latest_schema_version() noexcept;

struct MigrationResult
{
    int from_version;
    int to_version;
    [[nodiscard]] bool changed() const noexcept { return from_version != to_version; }
};

// Brings `db` up to the newest migration in `migrations`. Each step runs in its
// own transaction together with its PRAGMA user_version bump, so a failure
// leaves the database at the last complete version. Throws StorageError when
// the database is newer than this build (a downgrade is refused, never forced),
// when `migrations` has a gap, or when a step fails.
MigrationResult migrate(Database& db, std::span<const Migration> migrations);

}  // namespace spellbook::storage
