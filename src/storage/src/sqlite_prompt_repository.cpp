#include "spellbook/storage/sqlite_prompt_repository.hpp"

#include <utility>

namespace spellbook::storage
{

SqlitePromptRepository SqlitePromptRepository::open(const std::filesystem::path& file)
{
    return SqlitePromptRepository{Database::open(file), true};
}

SqlitePromptRepository SqlitePromptRepository::open_in_memory()
{
    return SqlitePromptRepository{Database::open_in_memory(), false};
}

SqlitePromptRepository::SqlitePromptRepository(Database db, bool is_file)
    : db_(std::move(db))
{
    db_.exec("PRAGMA foreign_keys = ON");
    db_.exec("PRAGMA busy_timeout = 5000");
    if (is_file)
    {
        // WAL: readers never block the writer, and a crash mid-write leaves the
        // last committed state intact.
        db_.exec("PRAGMA journal_mode = WAL");
        db_.exec("PRAGMA synchronous = NORMAL");
    }
    migration_ = migrate(db_, embedded_migrations());
}

int SqlitePromptRepository::schema_version() const
{
    return db_.user_version();
}

std::int64_t SqlitePromptRepository::prompt_count() const
{
    Statement s = db_.prepare("SELECT COUNT(*) FROM prompts");
    s.step();
    return s.column_int64(0);
}

}  // namespace spellbook::storage
