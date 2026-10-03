cmake_minimum_required(VERSION 3.28)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(SpellbookVersion)
spellbook_resolve_version(SPELLBOOK_VERSION SPELLBOOK_VERSION_MAJOR SPELLBOOK_VERSION_MINOR SPELLBOOK_VERSION_PATCH)

project(Spellbook
    VERSION ${SPELLBOOK_VERSION_MAJOR}.${SPELLBOOK_VERSION_MINOR}.${SPELLBOOK_VERSION_PATCH}
    DESCRIPTION "Your grimoire of AI prompts."
    HOMEPAGE_URL "https://github.com/rizonesoft/Spellbook"
    LANGUAGES C CXX)

if(NOT WIN32 OR NOT MSVC)
    message(FATAL_ERROR "Spellbook builds only with MSVC on Windows. Use a CMake preset from CMakePresets.json.")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# Static CRT, matching the x64-windows-static vcpkg triplet: one self-contained exe.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

include(SpellbookWarnings)

# The four-part file version carries the CI run number in its last field.
set(SPELLBOOK_FILE_BUILD 0)
if(DEFINED ENV{GITHUB_RUN_NUMBER})
    math(EXPR SPELLBOOK_FILE_BUILD "$ENV{GITHUB_RUN_NUMBER} % 65536")
endif()
message(STATUS "Spellbook version ${SPELLBOOK_VERSION} (file ${PROJECT_VERSION}.${SPELLBOOK_FILE_BUILD})")

find_package(unofficial-sqlite3 CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_subdirectory(src/core)
add_subdirectory(src/storage)
add_subdirectory(src/app)

option(SPELLBOOK_BUILD_TESTS "Build the unit tests" ON)
if(SPELLBOOK_BUILD_TESTS)
    enable_testing()
    find_package(Catch2 3 CONFIG REQUIRED)
    add_subdirectory(tests)
endif()

spellbook_assert_warnings_complete()
