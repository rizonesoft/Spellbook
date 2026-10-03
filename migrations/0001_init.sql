-- 0001_init: the Spellbook schema at version 1.
--
-- Applied by src/storage/src/migrator.cpp inside one transaction, which then
-- sets PRAGMA user_version = 1. A shipped migration is never edited: a change
-- is a new file (see .claude/skills/add-migration/SKILL.md).
--
-- Conventions: text is UTF-8; times are INTEGER milliseconds since the Unix
-- epoch, UTC; booleans are INTEGER 0 or 1 with a CHECK; ids are INTEGER
-- PRIMARY KEY (the rowid). UI copy calls these Spells, Chapters, Sigils, and
-- Revisions; the schema keeps the plain domain names.

CREATE TABLE folders (
    id          INTEGER PRIMARY KEY,
    parent_id   INTEGER REFERENCES folders(id) ON DELETE CASCADE,
    name        TEXT    NOT NULL CHECK (length(trim(name)) > 0),
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
);

-- Sibling folders have distinct names. Top-level folders (parent_id NULL) are
-- covered by the second index, since NULLs never collide in a UNIQUE index.
CREATE UNIQUE INDEX folders_sibling_name ON folders(parent_id, name COLLATE NOCASE) WHERE parent_id IS NOT NULL;
CREATE UNIQUE INDEX folders_root_name ON folders(name COLLATE NOCASE) WHERE parent_id IS NULL;

CREATE TABLE prompts (
    id           INTEGER PRIMARY KEY,
    title        TEXT    NOT NULL,
    body         TEXT    NOT NULL DEFAULT '',
    description  TEXT    NOT NULL DEFAULT '',
    folder_id    INTEGER REFERENCES folders(id) ON DELETE SET NULL,
    is_favorite  INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
    created_at   INTEGER NOT NULL,
    updated_at   INTEGER NOT NULL,
    use_count    INTEGER NOT NULL DEFAULT 0 CHECK (use_count >= 0),
    last_used_at INTEGER
);

CREATE INDEX prompts_folder ON prompts(folder_id);
CREATE INDEX prompts_updated ON prompts(updated_at DESC);
CREATE INDEX prompts_last_used ON prompts(last_used_at DESC);
CREATE INDEX prompts_use_count ON prompts(use_count DESC);

CREATE TABLE tags (
    id    INTEGER PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE COLLATE NOCASE CHECK (length(trim(name)) > 0)
);

CREATE TABLE prompt_tags (
    prompt_id  INTEGER NOT NULL REFERENCES prompts(id) ON DELETE CASCADE,
    tag_id     INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (prompt_id, tag_id)
) WITHOUT ROWID;

CREATE INDEX prompt_tags_tag ON prompt_tags(tag_id);

-- Revisions: the text of a prompt as it was before an edit replaced it.
CREATE TABLE prompt_versions (
    id           INTEGER PRIMARY KEY,
    prompt_id    INTEGER NOT NULL REFERENCES prompts(id) ON DELETE CASCADE,
    version_no   INTEGER NOT NULL CHECK (version_no >= 1),
    title        TEXT    NOT NULL,
    body         TEXT    NOT NULL,
    description  TEXT    NOT NULL DEFAULT '',
    created_at   INTEGER NOT NULL,
    UNIQUE (prompt_id, version_no)
);

-- Full-text search over title, body, and description. External-content FTS5:
-- the text lives once, in prompts, and the triggers below keep the index in step.
-- unicode61 with diacritics removed, so "cafe" finds "café".
CREATE VIRTUAL TABLE prompts_fts USING fts5(
    title,
    body,
    description,
    content = 'prompts',
    content_rowid = 'id',
    tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER prompts_fts_insert AFTER INSERT ON prompts BEGIN
    INSERT INTO prompts_fts(rowid, title, body, description)
    VALUES (new.id, new.title, new.body, new.description);
END;

CREATE TRIGGER prompts_fts_delete AFTER DELETE ON prompts BEGIN
    INSERT INTO prompts_fts(prompts_fts, rowid, title, body, description)
    VALUES ('delete', old.id, old.title, old.body, old.description);
END;

CREATE TRIGGER prompts_fts_update AFTER UPDATE OF title, body, description ON prompts BEGIN
    INSERT INTO prompts_fts(prompts_fts, rowid, title, body, description)
    VALUES ('delete', old.id, old.title, old.body, old.description);
    INSERT INTO prompts_fts(rowid, title, body, description)
    VALUES (new.id, new.title, new.body, new.description);
END;
