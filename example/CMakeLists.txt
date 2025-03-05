cmake_minimum_required(VERSION 3.12)
project(VC6_Example)

# Include directory
include_directories(include)

# Create the main executable
add_executable(vc6_example
    src/hello.cpp
    src/main.cpp
)

# Add the IDL files to our target
target_idl_files(vc6_example
    ${CMAKE_CURRENT_SOURCE_DIR}/src/calculator.idl
)

# Create a script to run the executable through wine
if(NOT WIN32)
    add_custom_command(
        TARGET vc6_example
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "#!/bin/sh" > ${CMAKE_CURRENT_BINARY_DIR}/run.sh
        COMMAND ${CMAKE_COMMAND} -E echo "wine ${CMAKE_CURRENT_BINARY_DIR}/vc6_example.exe \$@" >> ${CMAKE_CURRENT_BINARY_DIR}/run.sh
        COMMAND chmod +x ${CMAKE_CURRENT_BINARY_DIR}/run.sh
        COMMENT "Creating run script"
    )
endif()