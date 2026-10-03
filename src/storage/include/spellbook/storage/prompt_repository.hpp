#pragma once

#include <cstdint>

namespace spellbook::storage
{

// Where prompts live. The app and core services talk to this interface only,
// so the SQLite implementation can be swapped (a MySQL one is the documented
// alternative in docs/adr/0001-tech-stack.md) without touching anything above it.
//
// M0 carries only what the skeleton proves: the schema version and a count.
// M1 adds create, read, update, delete, and folders (todo/01-library/TODO-01).
class IPromptRepository
{
public:
    virtual ~IPromptRepository() = default;

    // The schema version the store is at (PRAGMA user_version for SQLite).
    [[nodiscard]] virtual int schema_version() const = 0;

    // How many prompts are stored.
    [[nodiscard]] virtual std::int64_t prompt_count() const = 0;

protected:
    IPromptRepository() = default;
    IPromptRepository(const IPromptRepository&) = default;
    IPromptRepository& operator=(const IPromptRepository&) = default;
    IPromptRepository(IPromptRepository&&) = default;
    IPromptRepository& operator=(IPromptRepository&&) = default;
};

}  // namespace spellbook::storage
