# spellbook_storage: IPromptRepository and its SQLite implementation, plus the
# migration runner. Depends on core; never on the app.

set(_migrations_cpp "${CMAKE_CURRENT_BINARY_DIR}/generated/embedded_migrations.cpp")
file(GLOB _migration_files CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/migrations/*.sql")
add_custom_command(
    OUTPUT "${_migrations_cpp}"
    COMMAND "${CMAKE_COMMAND}"
        "-DMIGRATIONS_DIR=${PROJECT_SOURCE_DIR}/migrations"
        "-DOUTPUT=${_migrations_cpp}"
        -P "${PROJECT_SOURCE_DIR}/cmake/EmbedMigrations.cmake"
    DEPENDS ${_migration_files} "${PROJECT_SOURCE_DIR}/cmake/EmbedMigrations.cmake"
    COMMENT "Embedding migrations/*.sql"
    VERBATIM)

add_library(spellbook_storage STATIC
    src/database.cpp
    src/migrator.cpp
    src/sqlite_prompt_repository.cpp
    "${_migrations_cpp}")
add_library(spellbook::storage ALIAS spellbook_storage)

target_include_directories(spellbook_storage PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(spellbook_storage
    PUBLIC spellbook::core
    PRIVATE unofficial::sqlite3::sqlite3 spdlog::spdlog)
spellbook_set_warnings(spellbook_storage)
