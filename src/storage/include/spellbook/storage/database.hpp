#pragma once

#include <cstdint>
#include <filesystem>
#include <stdexcept>
#include <string>
#include <string_view>

struct sqlite3;
struct sqlite3_stmt;

namespace spellbook::storage
{

// Every SQLite failure surfaces as this, carrying the SQLite result code and
// the message SQLite gave, prefixed with what Spellbook was doing.
class StorageError : public std::runtime_error
{
public:
    StorageError(const std::string& what, int sqlite_code);
    [[nodiscard]] int sqlite_code() const noexcept { return code_; }

private:
    int code_;
};

class Statement;

// An open SQLite connection (RAII). Not thread-safe: one Database per thread.
class Database
{
public:
    // Opens (creating if absent) the database file. The path may hold any
    // Unicode characters; it is passed to SQLite as UTF-8.
    static Database open(const std::filesystem::path& file);
    // A private in-memory database, for tests.
    static Database open_in_memory();

    Database(Database&& other) noexcept;
    Database& operator=(Database&& other) noexcept;
    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;
    ~Database();

    // Runs one or more statements that return no rows.
    void exec(std::string_view sql);
    [[nodiscard]] Statement prepare(std::string_view sql) const;

    // PRAGMA user_version: the schema version the migrations have reached.
    [[nodiscard]] int user_version() const;
    void set_user_version(int version);

    [[nodiscard]] bool in_transaction() const noexcept;
    [[nodiscard]] sqlite3* handle() const noexcept { return db_; }

private:
    explicit Database(sqlite3* db) noexcept
        : db_(db)
    {
    }
    sqlite3* db_ = nullptr;
};

// A prepared statement (RAII). Bind indexes are 1-based, column indexes 0-based.
class Statement
{
public:
    Statement(Statement&& other) noexcept;
    Statement& operator=(Statement&& other) noexcept;
    Statement(const Statement&) = delete;
    Statement& operator=(const Statement&) = delete;
    ~Statement();

    Statement& bind(int index, std::int64_t value);
    Statement& bind(int index, std::string_view utf8);
    Statement& bind_null(int index);

    // Advances to the next row: true while a row is available, false when done.
    bool step();
    void reset();

    [[nodiscard]] std::int64_t column_int64(int column) const;
    [[nodiscard]] std::string column_text(int column) const;
    [[nodiscard]] bool column_is_null(int column) const;

private:
    friend class Database;
    Statement(sqlite3* db, sqlite3_stmt* stmt) noexcept
        : db_(db)
        , stmt_(stmt)
    {
    }
    sqlite3* db_ = nullptr;
    sqlite3_stmt* stmt_ = nullptr;
};

}  // namespace spellbook::storage
