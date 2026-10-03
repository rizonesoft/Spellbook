#include <array>

#include <catch2/catch_test_macros.hpp>

#include "spellbook/storage/database.hpp"
#include "spellbook/storage/migrations.hpp"

using spellbook::storage::Database;
using spellbook::storage::embedded_migrations;
using spellbook::storage::latest_schema_version;
using spellbook::storage::migrate;
using spellbook::storage::Migration;
using spellbook::storage::StorageError;

TEST_CASE("embedded_migrations holds migrations/*.sql in version order from 1", "[migrations]")
{
    const auto all = embedded_migrations();
    REQUIRE_FALSE(all.empty());
    CHECK(all.front().version == 1);
    CHECK(all.front().name == "0001_init.sql");
    for (std::size_t i = 0; i < all.size(); ++i)
    {
        CHECK(all[i].version == static_cast<int>(i) + 1);
        CHECK_FALSE(all[i].sql.empty());
    }
}

TEST_CASE("latest_schema_version is the highest embedded migration", "[migrations]")
{
    CHECK(latest_schema_version() == embedded_migrations().back().version);
    CHECK(latest_schema_version() >= 1);
}

TEST_CASE("migrate takes a new database to the latest version, then is a no-op", "[migrations]")
{
    Database db = Database::open_in_memory();
    const auto first = migrate(db, embedded_migrations());
    CHECK(first.from_version == 0);
    CHECK(first.to_version == latest_schema_version());
    CHECK(first.changed());

    const auto second = migrate(db, embedded_migrations());
    CHECK(second.from_version == latest_schema_version());
    CHECK_FALSE(second.changed());
}

TEST_CASE("migrate applies only the steps above the current version", "[migrations]")
{
    const std::array<Migration, 2> steps{{
        {1, "0001_a.sql", "CREATE TABLE a (x INTEGER);"},
        {2, "0002_b.sql", "CREATE TABLE b (x INTEGER);"},
    }};
    Database db = Database::open_in_memory();
    migrate(db, std::span{steps}.first(1));
    CHECK(db.user_version() == 1);
    const auto result = migrate(db, steps);
    CHECK(result.from_version == 1);
    CHECK(result.to_version == 2);
}

TEST_CASE("a failing step rolls back and leaves the last complete version", "[migrations]")
{
    const std::array<Migration, 2> steps{{
        {1, "0001_a.sql", "CREATE TABLE a (x INTEGER);"},
        {2, "0002_bad.sql", "CREATE TABLE b (x INTEGER); NOT VALID SQL;"},
    }};
    Database db = Database::open_in_memory();
    CHECK_THROWS_AS(migrate(db, steps), StorageError);
    CHECK(db.user_version() == 1);
    CHECK_FALSE(db.in_transaction());
    // Table b was created inside the failed step's transaction, so it is gone.
    CHECK_THROWS_AS(db.prepare("SELECT * FROM b"), StorageError);
}

TEST_CASE("migrate refuses a database newer than this build", "[migrations]")
{
    Database db = Database::open_in_memory();
    db.set_user_version(latest_schema_version() + 1);
    CHECK_THROWS_AS(migrate(db, embedded_migrations()), StorageError);
    CHECK(db.user_version() == latest_schema_version() + 1);  // untouched
}

TEST_CASE("migrate refuses a migration list with a gap", "[migrations]")
{
    const std::array<Migration, 2> steps{{
        {1, "0001_a.sql", "CREATE TABLE a (x INTEGER);"},
        {3, "0003_c.sql", "CREATE TABLE c (x INTEGER);"},
    }};
    Database db = Database::open_in_memory();
    CHECK_THROWS_AS(migrate(db, steps), StorageError);
    CHECK(db.user_version() == 0);
}
