#include <filesystem>
#include <random>
#include <string>

#include <catch2/catch_test_macros.hpp>

#include "spellbook/storage/database.hpp"

using spellbook::storage::Database;
using spellbook::storage::StorageError;

namespace
{
// A fresh folder under the system temp directory, removed at scope exit. Tests
// never touch the real %LOCALAPPDATA% (standards/testing.md).
struct TempDir
{
    std::filesystem::path path;
    TempDir()
    {
        std::random_device rd;
        path = std::filesystem::temp_directory_path() / ("spellbook-test-" + std::to_string(rd()));
        std::filesystem::create_directories(path);
    }
    // remove_all with an error_code reports failures through ec; it can throw only
    // std::bad_alloc, which ends a test run anyway.
    ~TempDir()  // NOLINT(bugprone-exception-escape)
    {
        std::error_code ec;
        std::filesystem::remove_all(path, ec);  // best effort: a leftover temp folder is harmless
    }
    TempDir(const TempDir&) = delete;
    TempDir& operator=(const TempDir&) = delete;
    TempDir(TempDir&&) = delete;
    TempDir& operator=(TempDir&&) = delete;
};
}  // namespace

TEST_CASE("Database::open creates a file under a non-ASCII path", "[database]")
{
    TempDir dir;
    const auto file = dir.path / L"Gr\u00EFmoire \u65E5\u672C" / L"spellbook.db";
    std::filesystem::create_directories(file.parent_path());
    {
        Database db = Database::open(file);
        db.exec("CREATE TABLE t (x INTEGER)");
    }
    CHECK(std::filesystem::exists(file));
}

TEST_CASE("exec, prepare, bind, and step round-trip values", "[database]")
{
    Database db = Database::open_in_memory();
    db.exec("CREATE TABLE t (n INTEGER, s TEXT, z TEXT)");
    db.prepare("INSERT INTO t VALUES (?, ?, ?)")
        .bind(1, std::int64_t{42})
        .bind(2, "\xE2\x9C\xA8 spell")
        .bind_null(3)
        .step();

    auto s = db.prepare("SELECT n, s, z FROM t");
    REQUIRE(s.step());
    CHECK(s.column_int64(0) == 42);
    CHECK(s.column_text(1) == "\xE2\x9C\xA8 spell");
    CHECK(s.column_is_null(2));
    CHECK_FALSE(s.step());
}

TEST_CASE("user_version reads and writes PRAGMA user_version", "[database]")
{
    Database db = Database::open_in_memory();
    CHECK(db.user_version() == 0);
    db.set_user_version(7);
    CHECK(db.user_version() == 7);
}

TEST_CASE("in_transaction follows BEGIN and COMMIT", "[database]")
{
    Database db = Database::open_in_memory();
    CHECK_FALSE(db.in_transaction());
    db.exec("BEGIN");
    CHECK(db.in_transaction());
    db.exec("COMMIT");
    CHECK_FALSE(db.in_transaction());
}

TEST_CASE("SQL errors throw StorageError with the SQLite message", "[database]")
{
    Database db = Database::open_in_memory();
    CHECK_THROWS_AS(db.exec("NOT SQL"), StorageError);
    CHECK_THROWS_AS(db.prepare("SELECT * FROM missing_table"), StorageError);
    try
    {
        db.exec("SELECT * FROM missing_table");
        FAIL("expected a StorageError");
    }
    catch (const StorageError& e)
    {
        CHECK(std::string{e.what()}.find("missing_table") != std::string::npos);
        CHECK(e.sqlite_code() != 0);
    }
}

TEST_CASE("Database::open refuses a path inside a missing folder", "[database]")
{
    TempDir dir;
    CHECK_THROWS_AS(Database::open(dir.path / "absent" / "x.db"), StorageError);
}

TEST_CASE("Statement::reset allows a statement to run again", "[database]")
{
    Database db = Database::open_in_memory();
    db.exec("CREATE TABLE t (n INTEGER)");
    auto insert = db.prepare("INSERT INTO t VALUES (?)");
    insert.bind(1, std::int64_t{1}).step();
    insert.reset();
    insert.bind(1, std::int64_t{2}).step();
    auto count = db.prepare("SELECT COUNT(*) FROM t");
    count.step();
    CHECK(count.column_int64(0) == 2);
}
