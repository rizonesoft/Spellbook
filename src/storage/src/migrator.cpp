#include <string>

#include <spdlog/spdlog.h>

#include "spellbook/storage/database.hpp"
#include "spellbook/storage/migrations.hpp"

namespace spellbook::storage
{

int latest_schema_version() noexcept
{
    const auto all = embedded_migrations();
    return all.empty() ? 0 : all.back().version;
}

MigrationResult migrate(Database& db, std::span<const Migration> migrations)
{
    const int from = db.user_version();
    const int latest = migrations.empty() ? 0 : migrations.back().version;

    for (std::size_t i = 0; i < migrations.size(); ++i)
    {
        if (migrations[i].version != static_cast<int>(i) + 1)
        {
            throw StorageError("migration list has a gap at " + std::string{migrations[i].name}, 0);
        }
    }
    if (from > latest)
    {
        throw StorageError("the database is at schema version " + std::to_string(from) +
                               ", newer than this Spellbook understands (" + std::to_string(latest) +
                               "); update Spellbook to open it",
                           0);
    }

    for (const Migration& m : migrations)
    {
        if (m.version <= from)
        {
            continue;
        }
        db.exec("BEGIN IMMEDIATE");
        try
        {
            db.exec(m.sql);
            db.set_user_version(m.version);
            db.exec("COMMIT");
        }
        catch (...)
        {
            if (db.in_transaction())
            {
                db.exec("ROLLBACK");
            }
            throw;
        }
        spdlog::info("Applied migration {} ({})", m.version, m.name);
    }

    const int to = db.user_version();
    return {from, to};
}

}  // namespace spellbook::storage
