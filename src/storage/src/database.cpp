#include "spellbook/storage/database.hpp"

#include <sqlite3.h>

#include <string>
#include <utility>

namespace spellbook::storage
{
namespace
{

[[noreturn]] void fail(sqlite3* db, int rc, std::string_view doing)
{
    std::string what{doing};
    what += ": ";
    what += (db != nullptr) ? sqlite3_errmsg(db) : sqlite3_errstr(rc);
    throw StorageError(what, rc);
}

std::string path_to_utf8(const std::filesystem::path& file)
{
    const std::u8string u8 = file.u8string();
    return {reinterpret_cast<const char*>(u8.data()), u8.size()};
}

// A failed sqlite3_open_v2 may still hand back a handle that must be closed;
// the message is read from it first, then the handle is released.
[[noreturn]] void fail_open(sqlite3* db, int rc, std::string_view doing)
{
    std::string what{doing};
    what += ": ";
    what += (db != nullptr) ? sqlite3_errmsg(db) : sqlite3_errstr(rc);
    sqlite3_close_v2(db);
    throw StorageError(what, rc);
}

}  // namespace

StorageError::StorageError(const std::string& what, int sqlite_code)
    : std::runtime_error(what)
    , code_(sqlite_code)
{
}

Database Database::open(const std::filesystem::path& file)
{
    sqlite3* db = nullptr;
    const std::string name = path_to_utf8(file);
    const int rc = sqlite3_open_v2(
        name.c_str(), &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nullptr);
    if (rc != SQLITE_OK)
    {
        fail_open(db, rc, "opening " + name);
    }
    sqlite3_extended_result_codes(db, 1);
    return Database{db};
}

Database Database::open_in_memory()
{
    sqlite3* db = nullptr;
    const int rc = sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nullptr);
    if (rc != SQLITE_OK)
    {
        fail_open(db, rc, "opening an in-memory database");
    }
    sqlite3_extended_result_codes(db, 1);
    return Database{db};
}

Database::Database(Database&& other) noexcept
    : db_(std::exchange(other.db_, nullptr))
{
}

Database& Database::operator=(Database&& other) noexcept
{
    if (this != &other)
    {
        if (db_ != nullptr)
        {
            sqlite3_close_v2(db_);
        }
        db_ = std::exchange(other.db_, nullptr);
    }
    return *this;
}

Database::~Database()
{
    if (db_ != nullptr)
    {
        sqlite3_close_v2(db_);
    }
}

void Database::exec(std::string_view sql)
{
    const std::string text{sql};
    char* message = nullptr;
    const int rc = sqlite3_exec(db_, text.c_str(), nullptr, nullptr, &message);
    if (rc != SQLITE_OK)
    {
        std::string what = "executing SQL: ";
        what += (message != nullptr) ? message : sqlite3_errstr(rc);
        sqlite3_free(message);
        throw StorageError(what, rc);
    }
}

Statement Database::prepare(std::string_view sql) const
{
    sqlite3_stmt* stmt = nullptr;
    const int rc = sqlite3_prepare_v2(db_, sql.data(), static_cast<int>(sql.size()), &stmt, nullptr);
    if (rc != SQLITE_OK)
    {
        fail(db_, rc, "preparing SQL");
    }
    return Statement{db_, stmt};
}

int Database::user_version() const
{
    Statement s = prepare("PRAGMA user_version");
    s.step();
    return static_cast<int>(s.column_int64(0));
}

void Database::set_user_version(int version)
{
    // PRAGMA takes no bound parameters; the value is an int, so this is safe.
    exec("PRAGMA user_version = " + std::to_string(version));
}

bool Database::in_transaction() const noexcept
{
    return sqlite3_get_autocommit(db_) == 0;
}

Statement::Statement(Statement&& other) noexcept
    : db_(std::exchange(other.db_, nullptr))
    , stmt_(std::exchange(other.stmt_, nullptr))
{
}

Statement& Statement::operator=(Statement&& other) noexcept
{
    if (this != &other)
    {
        sqlite3_finalize(stmt_);
        db_ = std::exchange(other.db_, nullptr);
        stmt_ = std::exchange(other.stmt_, nullptr);
    }
    return *this;
}

Statement::~Statement()
{
    sqlite3_finalize(stmt_);
}

Statement& Statement::bind(int index, std::int64_t value)
{
    const int rc = sqlite3_bind_int64(stmt_, index, value);
    if (rc != SQLITE_OK)
    {
        fail(db_, rc, "binding an integer");
    }
    return *this;
}

Statement& Statement::bind(int index, std::string_view utf8)
{
    const int rc = sqlite3_bind_text64(stmt_, index, utf8.data(), utf8.size(), SQLITE_TRANSIENT, SQLITE_UTF8);
    if (rc != SQLITE_OK)
    {
        fail(db_, rc, "binding text");
    }
    return *this;
}

Statement& Statement::bind_null(int index)
{
    const int rc = sqlite3_bind_null(stmt_, index);
    if (rc != SQLITE_OK)
    {
        fail(db_, rc, "binding null");
    }
    return *this;
}

bool Statement::step()
{
    const int rc = sqlite3_step(stmt_);
    if (rc == SQLITE_ROW)
    {
        return true;
    }
    if (rc == SQLITE_DONE)
    {
        return false;
    }
    fail(db_, rc, "stepping a statement");
}

void Statement::reset()
{
    sqlite3_reset(stmt_);
    sqlite3_clear_bindings(stmt_);
}

std::int64_t Statement::column_int64(int column) const
{
    return sqlite3_column_int64(stmt_, column);
}

std::string Statement::column_text(int column) const
{
    const auto* text = reinterpret_cast<const char*>(sqlite3_column_text(stmt_, column));
    const int size = sqlite3_column_bytes(stmt_, column);
    return (text != nullptr) ? std::string(text, static_cast<std::size_t>(size)) : std::string{};
}

bool Statement::column_is_null(int column) const
{
    return sqlite3_column_type(stmt_, column) == SQLITE_NULL;
}

}  // namespace spellbook::storage
