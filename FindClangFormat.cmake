#.rst:
# FindClangFormat
# ---------------
#
# FindModule for LLVM clang-format script.
#
# IMPORTED Targets
# ^^^^^^^^^^^^^^^^
#
# ``ClangFormat::clang-format``
#  Defined if the system has the clang-format script.
#
# Result Variables
# ^^^^^^^^^^^^^^^^
#
# This module sets the following variables:
#
# ``ClangFormat_FOUND``
#  True, if the system has clang-format.
# ``ClangFormat_EXECUTABLE``
#  Path to the clang-format script.
#


find_program(ClangFormat_EXECUTABLE
    DOC "Path to the clang-format executable."
    NAMES clang-format clang-format-3.7 clang-format-3.6 clang-format-3.5 clang-format 3.4
)

if(ClangFormat_EXECUTABLE)
    add_executable(ClangFormat::clang-format IMPORTED)
    set_target_properties(ClangFormat::clang-format PROPERTIES
        IMPORTED_LOCATION "${ClangFormat_EXECUTABLE}"
    )

    execute_process(COMMAND ${ClangFormat_EXECUTABLE} --version
        OUTPUT_VARIABLE _cformat_version
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_cformat_version MATCHES ".*clang-format version ([0-9]+.[0-9]+.[0-9]+)")
        set(ClangFormat_VERSION_STRING "${CMAKE_MATCH_1}")
    endif()
    unset(_cformat_version)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ClangFormat
    FOUND_VAR ClangFormat_FOUND
    VERSION_VAR ClangFormat_VERSION_STRING
    REQUIRED_VARS ClangFormat_EXECUTABLE
)

if(TARGET ClangFormat::clang-format AND NOT COMMAND add_clang_format)
    function(add_clang_format _target)
        include(CMakeParseArguments)
        cmake_parse_arguments(_arg "" "STYLE;TARGET" "DEPENDS;SOURCES;TARGETS" ${ARGN})
        set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/${_target}.dir")

        set(_src ${_arg_SOURCES})
        foreach(_target IN LISTS _arg_TARGET _arg_TARGETS)
            get_target_property(_files ${_target} SOURCES)
            if(_files)
                list(APPEND _src ${_files})
            endif()
        endforeach()

        set(_inputs)
        foreach(_file IN LISTS _src)
            get_filename_component(_abs "${_file}" REALPATH)
            list(APPEND _inputs "${_abs}")
        endforeach()
        list(REMOVE_DUPLICATES _inputs)

        set(_stamps)
        foreach(_file IN LISTS _inputs)
            string(SHA1 _hash "${_file}")
            set(_stamp "${_target_dir}/${_hash}.stamp")
            list(APPEND _stamps "${_stamp}")
            file(RELATIVE_PATH _name "${PROJECT_SOURCE_DIR}" "${_file}")
            add_custom_command(
                OUTPUT "${_stamp}"
                DEPENDS "${_file}" ${_arg_DEPENDS}
                COMMAND
                    $<TARGET_PROPERTY:${_target},CLANGFORMAT_EXECUTABLE>
                    $<$<BOOL:$<TARGET_PROPERTY:${_target},CLANGFORMAT_INLINE>>:-i>
                    $<$<BOOL:$<TARGET_PROPERTY:${_target},CLANGFORMAT_STYLE>>:-style=$<TARGET_PROPERTY:${_target},CLANGFORMAT_STYLE>>
                    "${_file}"
                COMMAND ${CMAKE_COMMAND} -E touch "${_stamp}"
                COMMENT "clang-format ${_name}"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            )
        endforeach()

        add_custom_target("${_target}"
            DEPENDS ${_stamps}
            SOURCES ${_src}
        )
        set_target_properties("${_target}" PROPERTIES
            CLANGFORMAT_EXECUTABLE "${ClangFormat_EXECUTABLE}"
            CLANGFORMAT_INLINE "1"
            CLANGFORMAT_STYLE "${_arg_STYLE}"
        )
    endfunction()
endif()

if(TARGET ClangFormat::clang-format AND NOT COMMAND add_clang_format_check)
    function(add_clang_format_check _target)
        include(CMakeParseArguments)
        cmake_parse_arguments(_arg "" "STYLE;TARGET" "DEPENDS;SOURCES;TARGETS" ${ARGN})
        set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/${_target}.dir")

        file(WRITE "${_target_dir}/ClangFormatCheck.cmake"
            "set(_format_cmd\n"
            "    \${CLANGFORMAT_EXECUTABLE}\n"
            ")\n"
            "if(CLANGFORMAT_STYLE)\n"
            "    list(APPEND _format_cmd \"-style=\${CLANGFORMAT_STYLE}\")\n"
            "endif()\n"
            "\n"
            "execute_process(\n"
            "    COMMAND \${_format_cmd} \${INPUT}\n"
            "    WORKING_DIRECTORY \"\${WORKING_DIRECTORY}\"\n"
            "    RESULT_VARIABLE _ec\n"
            "    OUTPUT_VARIABLE _formated\n"
            "    ERROR_VARIABLE _format_error\n"
            ")\n"
            "\n"
            "file(READ \"\${INPUT}\" _orig)\n"
            "\n"
            "if(NOT _ec EQUAL 0)\n"
            "    message(FATAL_ERROR \"clang-format of `\${INPUT}' failed (\${_ec}): \${_format_error}\")\n"
            "elseif(NOT _orig STREQUAL _formated)\n"
            "    message(FATAL_ERROR \"Input `\${INPUT}' does not follow format style.\")\n"
            "endif()\n"
        )

        set(_src ${_arg_SOURCES})
        foreach(_target IN LISTS _arg_TARGET _arg_TARGETS)
            get_target_property(_files ${_target} SOURCES)
            if(_files)
                list(APPEND _src ${_files})
            endif()
        endforeach()

        set(_inputs)
        foreach(_file IN LISTS _src)
            get_filename_component(_abs "${_file}" REALPATH)
            list(APPEND _inputs "${_abs}")
        endforeach()
        list(REMOVE_DUPLICATES _inputs)

        set(_stamps)
        foreach(_file IN LISTS _inputs)
            string(SHA1 _hash "${_file}")
            set(_stamp "${_target_dir}/${_hash}.stamp")
            list(APPEND _stamps "${_stamp}")
            file(RELATIVE_PATH _name "${PROJECT_SOURCE_DIR}" "${_file}")
            add_custom_command(
                OUTPUT "${_stamp}"
                DEPENDS "${_file}" ${_arg_DEPENDS}
                COMMAND ${CMAKE_COMMAND}
                    -DCLANGFORMAT_EXECUTABLE=$<TARGET_PROPERTY:${_target},CLANGFORMAT_EXECUTABLE>
                    -DCLANGFORMAT_STYLE=$<TARGET_PROPERTY:${_target},CLANGFORMAT_STYLE>
                    "-DINPUT=${_file}"
                    "-DWORKING_DIRECTORY=${CMAKE_CURRENT_SOURCE_DIR}"
                    -P "${_target_dir}/ClangFormatCheck.cmake"
                COMMENT "clang-format-check ${_file}"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            )
        endforeach()

        add_custom_target("${_target}"
            DEPENDS ${_stamps}
        )
        set_target_properties("${_target}" PROPERTIES
            CLANGFORMAT_EXECUTABLE "${ClangFormat_EXECUTABLE}"
            CLANGFORMAT_STYLE "${_arg_STYLE}"
        )
    endfunction()
endif()
