# spellbook_core: the domain model and services. Standard C++ only: no Windows
# headers, no UI, no storage. Everything here is unit-testable without a GUI.

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/include/spellbook/core/build_info.hpp.in"
    "${CMAKE_CURRENT_BINARY_DIR}/generated/spellbook/core/build_info.hpp"
    @ONLY)

add_library(spellbook_core STATIC
    src/text.cpp
    src/version.cpp)
add_library(spellbook::core ALIAS spellbook_core)

target_include_directories(spellbook_core
    PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_BINARY_DIR}/generated")
target_compile_features(spellbook_core PUBLIC cxx_std_20)
spellbook_set_warnings(spellbook_core)
# The layering rule (no Windows headers, no storage or app includes) is checked
# by scripts/check-layering.py, which scripts/check-all.ps1 and CI run.
