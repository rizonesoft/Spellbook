# The warning policy, in one file. Pattern copied from Resolute's
# cmake/ResoluteWarnings.cmake: applied per target, by name, to OUR targets
# only, plus a configure-time audit that fails when a target we own missed it.
#
# Why per target: vcpkg headers are not ours to fix. Their include directories
# arrive as SYSTEM includes, and /external:W0 silences them, so /W4 /WX governs
# only the code in src/ and tests/.

if(DEFINED SPELLBOOK_WARNINGS_POLICY_APPLIED)
    return()
endif()
set(SPELLBOOK_WARNINGS_POLICY_APPLIED TRUE)

option(SPELLBOOK_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)

function(spellbook_set_warnings target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "spellbook_set_warnings: no such target '${target}'")
    endif()

    # /W4 is the level; /permissive- and the Zc switches make MSVC follow the
    # standard; /utf-8 makes every source and execution character set UTF-8.
    set(_flags /W4 /permissive- /utf-8 /Zc:__cplusplus /Zc:preprocessor /external:anglebrackets /external:W0)
    if(SPELLBOOK_WARNINGS_AS_ERRORS)
        list(APPEND _flags /WX)
    endif()
    target_compile_options(${target} PRIVATE ${_flags})
    # Unicode at the Win32 boundary: every W API, never the A ones.
    target_compile_definitions(${target} PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
    set_property(TARGET ${target} PROPERTY SPELLBOOK_WARNINGS_APPLIED TRUE)
endfunction()

function(_spellbook_collect_targets dir out_var)
    get_property(_subs DIRECTORY "${dir}" PROPERTY SUBDIRECTORIES)
    get_property(_here DIRECTORY "${dir}" PROPERTY BUILDSYSTEM_TARGETS)
    set(_acc ${_here})
    foreach(_sub IN LISTS _subs)
        _spellbook_collect_targets("${_sub}" _sub_targets)
        list(APPEND _acc ${_sub_targets})
    endforeach()
    set(${out_var} "${_acc}" PARENT_SCOPE)
endfunction()

# A target added without spellbook_set_warnings() fails the configure by name.
function(spellbook_assert_warnings_complete)
    _spellbook_collect_targets("${CMAKE_CURRENT_SOURCE_DIR}" _targets)
    set(_missing "")
    foreach(_t IN LISTS _targets)
        get_target_property(_type ${_t} TYPE)
        if(_type MATCHES "^(EXECUTABLE|STATIC_LIBRARY|SHARED_LIBRARY|MODULE_LIBRARY|OBJECT_LIBRARY)$")
            get_target_property(_applied ${_t} SPELLBOOK_WARNINGS_APPLIED)
            if(NOT _applied)
                list(APPEND _missing ${_t})
            endif()
        endif()
    endforeach()
    if(_missing)
        list(JOIN _missing ", " _names)
        message(FATAL_ERROR
            "spellbook_set_warnings() was never called for: ${_names}\n"
            "Every target this project owns answers to the warning policy. "
            "See cmake/SpellbookWarnings.cmake.")
    endif()
endfunction()
