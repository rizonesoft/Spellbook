# The version comes from git tags, never from a typed string (the Isotone rule:
# "No version string is typed into a project file"). A tag is v<SemVer>.
#
#   on the tag v0.2.0                -> 0.2.0
#   3 commits after v0.2.0           -> 0.2.1-alpha.3   (next patch, prerelease)
#   no tag yet                       -> 0.0.0-alpha.<commit count>
#   no git (a source archive)        -> 0.0.0-local
#
# The four-part Win32 file version is Major.Minor.Patch.<CI run number or 0>.
# The value is read at configure time: reconfigure (or build -Clean) after tagging.

function(spellbook_resolve_version out_semver out_major out_minor out_patch)
    set(_semver "0.0.0-local")
    find_package(Git QUIET)
    if(GIT_FOUND AND EXISTS "${CMAKE_SOURCE_DIR}/.git")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" describe --tags --match "v[0-9]*" --long --abbrev=7
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE _describe OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET RESULT_VARIABLE _rc)
        if(_rc EQUAL 0 AND _describe MATCHES "^v([0-9]+)\\.([0-9]+)\\.([0-9]+)(-[0-9A-Za-z.]+)?-([0-9]+)-g[0-9a-f]+$")
            set(_ma ${CMAKE_MATCH_1})
            set(_mi ${CMAKE_MATCH_2})
            set(_pa ${CMAKE_MATCH_3})
            set(_pre "${CMAKE_MATCH_4}")
            set(_height ${CMAKE_MATCH_5})
            if(_height EQUAL 0)
                set(_semver "${_ma}.${_mi}.${_pa}${_pre}")
            else()
                math(EXPR _next "${_pa} + 1")
                set(_semver "${_ma}.${_mi}.${_next}-alpha.${_height}")
                set(_pa ${_next})
            endif()
        else()
            execute_process(
                COMMAND "${GIT_EXECUTABLE}" rev-list --count HEAD
                WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
                OUTPUT_VARIABLE _count OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET RESULT_VARIABLE _rc2)
            if(NOT _rc2 EQUAL 0 OR _count STREQUAL "")
                set(_count 0)
            endif()
            set(_semver "0.0.0-alpha.${_count}")
        endif()
    endif()
    if(NOT DEFINED _ma)
        set(_ma 0)
        set(_mi 0)
        set(_pa 0)
    endif()
    set(${out_semver} "${_semver}" PARENT_SCOPE)
    set(${out_major} ${_ma} PARENT_SCOPE)
    set(${out_minor} ${_mi} PARENT_SCOPE)
    set(${out_patch} ${_pa} PARENT_SCOPE)
endfunction()
