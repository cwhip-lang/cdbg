# Rewrite this repository's Cwhip sources in place.
# The format target passes absolute SOURCE_DIR and BINARY_DIR.
# cwhip-format reads .cwhip-format from the source directory itself.

cmake_minimum_required(VERSION 3.24)

if(NOT DEFINED SOURCE_DIR OR SOURCE_DIR STREQUAL ""
        OR NOT DEFINED BINARY_DIR OR BINARY_DIR STREQUAL "")
    message(FATAL_ERROR "cwhip-format requires SOURCE_DIR and BINARY_DIR")
endif()

find_program(CWHIP_FORMAT_EXECUTABLE NAMES cwhip-format)
if(NOT CWHIP_FORMAT_EXECUTABLE)
    message(FATAL_ERROR "cwhip-format was not found")
endif()

cmake_path(ABSOLUTE_PATH SOURCE_DIR NORMALIZE OUTPUT_VARIABLE cdbg_format_source_dir)
cmake_path(ABSOLUTE_PATH BINARY_DIR NORMALIZE OUTPUT_VARIABLE cdbg_format_binary_dir)
cmake_path(APPEND cdbg_format_source_dir "build"
    OUTPUT_VARIABLE cdbg_format_tree_build)

file(GLOB_RECURSE cdbg_format_sources "${cdbg_format_source_dir}/*.cw")
set(cdbg_format_inputs)
foreach(cdbg_format_source IN LISTS cdbg_format_sources)
    cmake_path(ABSOLUTE_PATH cdbg_format_source NORMALIZE
        OUTPUT_VARIABLE cdbg_format_absolute)
    set(cdbg_format_skip FALSE)
    foreach(cdbg_format_skip_dir IN ITEMS "${cdbg_format_binary_dir}" "${cdbg_format_tree_build}")
        cmake_path(IS_PREFIX cdbg_format_skip_dir "${cdbg_format_absolute}" NORMALIZE
            cdbg_format_in_skip_dir)
        if(cdbg_format_in_skip_dir)
            set(cdbg_format_skip TRUE)
            break()
        endif()
    endforeach()
    if(NOT cdbg_format_skip)
        list(APPEND cdbg_format_inputs "${cdbg_format_absolute}")
    endif()
endforeach()

if(NOT cdbg_format_inputs)
    message(FATAL_ERROR
        "cwhip-format found no Cwhip sources outside the build directory")
endif()

list(SORT cdbg_format_inputs)
execute_process(
    COMMAND "${CWHIP_FORMAT_EXECUTABLE}" -i ${cdbg_format_inputs}
    WORKING_DIRECTORY "${cdbg_format_source_dir}"
    RESULT_VARIABLE cdbg_format_result)
if(NOT cdbg_format_result EQUAL 0)
    message(FATAL_ERROR "cwhip-format failed with status ${cdbg_format_result}")
endif()
