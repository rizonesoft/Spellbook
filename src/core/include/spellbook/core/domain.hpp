#pragma once

#include <chrono>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

// The domain model. Plain data, no behaviour yet: the services that act on it
// arrive with the milestones in todo/implementation-plan.md (CRUD in M1,
// import in M2, search in M3, templates in M4). Field names match the columns
// in migrations/0001_init.sql. Text is UTF-8. Times are UTC, millisecond
// precision, stored as INTEGER milliseconds since the Unix epoch.
//
// UI copy calls these Spell, Chapter, Sigil, Rune, and Revisions (see
// standards/ui.md, "Theme vocabulary"); code and schema keep the plain names.

namespace spellbook::core
{

using Id = std::int64_t;
using Timestamp = std::chrono::sys_time<std::chrono::milliseconds>;

struct Folder
{
    Id id = 0;
    std::optional<Id> parent_id;  // nullopt for a top-level folder
    std::string name;
    std::int64_t sort_order = 0;
    Timestamp created_at{};
    Timestamp updated_at{};
};

struct Tag
{
    Id id = 0;
    std::string name;  // unique, compared case-insensitively
};

struct Prompt
{
    Id id = 0;
    std::string title;
    std::string body;
    std::string description;
    std::optional<Id> folder_id;  // nullopt: not filed in any folder
    bool is_favorite = false;
    Timestamp created_at{};
    Timestamp updated_at{};
    std::int64_t use_count = 0;
    std::optional<Timestamp> last_used_at;
    std::vector<Id> tag_ids;
};

// One saved state of a prompt's text, written before an edit replaces it.
struct PromptVersion
{
    Id id = 0;
    Id prompt_id = 0;
    std::int64_t version_no = 0;  // 1, 2, 3 ... per prompt
    std::string title;
    std::string body;
    std::string description;
    Timestamp created_at{};
};

// A {{name}} placeholder found in a prompt body. Detected, not stored: M4
// decides how an optional default is written (todo/03-app/TODO-04 §1).
struct TemplateVariable
{
    std::string name;
    std::optional<std::string> default_value;
};

}  // namespace spellbook::core
