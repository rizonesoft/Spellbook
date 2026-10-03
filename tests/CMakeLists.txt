# One Catch2 test executable per production library. ctest discovers every
# TEST_CASE by name, so `pwsh scripts/test.ps1 -Filter <regex>` selects them.
include(Catch)

add_executable(spellbook_core_tests
    core/text_tests.cpp
    core/version_tests.cpp)
target_link_libraries(spellbook_core_tests PRIVATE spellbook::core Catch2::Catch2WithMain)
spellbook_set_warnings(spellbook_core_tests)
catch_discover_tests(spellbook_core_tests TEST_PREFIX "core: ")

add_executable(spellbook_storage_tests
    storage/database_tests.cpp
    storage/migrator_tests.cpp
    storage/sqlite_prompt_repository_tests.cpp)
target_link_libraries(spellbook_storage_tests PRIVATE spellbook::storage unofficial::sqlite3::sqlite3 Catch2::Catch2WithMain)
spellbook_set_warnings(spellbook_storage_tests)
catch_discover_tests(spellbook_storage_tests TEST_PREFIX "storage: ")
