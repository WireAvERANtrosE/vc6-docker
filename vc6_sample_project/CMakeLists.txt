cmake_minimum_required(VERSION 3.10)

# Tell CMake to not try to detect a compiler
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_CXX_COMPILER_WORKS 1)
set(CMAKE_SUPPRESS_DEVELOPER_WARNINGS 1)

# Prevent CMake from testing compilers
set(CMAKE_C_COMPILER "/bin/echo")
set(CMAKE_CXX_COMPILER "/bin/echo")

# Initialize the project
project(VC6SampleProject LANGUAGES NONE)

# Custom directories
set(IDL_OUTPUT_DIR "${CMAKE_BINARY_DIR}/idl_output/sample")
set(OBJ_DIR "${CMAKE_BINARY_DIR}/obj")

# Create directories
file(MAKE_DIRECTORY ${IDL_OUTPUT_DIR})
file(MAKE_DIRECTORY ${OBJ_DIR})

# Make sure python script is executable
execute_process(COMMAND chmod +x "${CMAKE_SOURCE_DIR}/tools/winetools.py")

# Custom target for IDL compilation
add_custom_target(sample_idl ALL
    COMMAND python3 "${CMAKE_SOURCE_DIR}/tools/winetools.py" idl
        "${CMAKE_SOURCE_DIR}/src/sample.idl"
        "${IDL_OUTPUT_DIR}/sample.h"
        "${IDL_OUTPUT_DIR}/sample_i.c"
        "${IDL_OUTPUT_DIR}/sample.tlb"
    COMMENT "Compiling sample.idl with MIDL"
    VERBATIM
)

# Define source files
set(SOURCES
    "${CMAKE_SOURCE_DIR}/src/main.cpp"
    "${CMAKE_SOURCE_DIR}/src/sample.cpp"
    "${IDL_OUTPUT_DIR}/sample_i.c"
)

# Create custom targets for source compilation
set(OBJECTS "")
foreach(SOURCE ${SOURCES})
    get_filename_component(SOURCE_NAME ${SOURCE} NAME_WE)
    set(OBJ_FILE "${OBJ_DIR}/${SOURCE_NAME}.obj")
    list(APPEND OBJECTS ${OBJ_FILE})
    
    add_custom_target(compile_${SOURCE_NAME} ALL
        DEPENDS sample_idl
        COMMAND python3 "${CMAKE_SOURCE_DIR}/tools/winetools.py" compile
            "${SOURCE}"
            "${OBJ_FILE}"
        COMMENT "Compiling ${SOURCE}"
        VERBATIM
    )
endforeach()

# Linking target
add_custom_target(vc6_sample ALL
    DEPENDS ${OBJECTS}
    COMMAND python3 "${CMAKE_SOURCE_DIR}/tools/winetools.py" link
        "${CMAKE_BINARY_DIR}/vc6_sample.exe"
        ${OBJECTS}
    COMMENT "Linking vc6_sample.exe"
    VERBATIM
)

# Create run script
add_custom_command(
    TARGET vc6_sample POST_BUILD
    COMMAND echo "#!/bin/bash" > "${CMAKE_BINARY_DIR}/run.sh"
    COMMAND echo "wine \"${CMAKE_BINARY_DIR}/vc6_sample.exe\"" >> "${CMAKE_BINARY_DIR}/run.sh"
    COMMAND chmod +x "${CMAKE_BINARY_DIR}/run.sh"
    COMMENT "Creating run script"
    VERBATIM
)