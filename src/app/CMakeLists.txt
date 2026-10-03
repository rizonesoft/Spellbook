# Spellbook.exe: the Win32 shell. Thin by rule: windows, messages, and resources
# here; logic in core; data through storage.

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/res/version.rc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/generated/version.rc"
    @ONLY)

add_executable(spellbook_app WIN32
    main.cpp
    app_paths.cpp
    logging.cpp
    main_window.cpp
    res/spellbook.rc
    "${CMAKE_CURRENT_BINARY_DIR}/generated/version.rc")

set_target_properties(spellbook_app PROPERTIES OUTPUT_NAME Spellbook)
target_include_directories(spellbook_app PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(spellbook_app PRIVATE
    spellbook::core
    spellbook::storage
    spdlog::spdlog
    comctl32 dwmapi shell32 ole32 uxtheme)

# The app manifest (Common Controls v6, Per-Monitor-V2 DPI, UTF-8 code page) is
# embedded through spellbook.rc, so the linker must not generate its own.
target_link_options(spellbook_app PRIVATE /MANIFEST:NO)
set_property(SOURCE res/spellbook.rc APPEND PROPERTY OBJECT_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/res/spellbook.manifest"
    "${PROJECT_SOURCE_DIR}/assets/spellbook.ico")
target_include_directories(spellbook_app PRIVATE "${PROJECT_SOURCE_DIR}/assets")
spellbook_set_warnings(spellbook_app)
