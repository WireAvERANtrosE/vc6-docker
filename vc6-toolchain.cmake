# Visual C++ 6.0 through Wine CMake toolchain file
# This toolchain file configures CMake to use our Python proxy scripts
# as the compiler and linker, which then forward commands to VC6 through Wine.

# Specify the platform
set(CMAKE_SYSTEM_NAME Windows)

# Define the paths to our proxy scripts
set(TOOLS_DIR "${CMAKE_CURRENT_LIST_DIR}/tools")
set(CL_PROXY "${TOOLS_DIR}/cl.py")
set(LINK_PROXY "${TOOLS_DIR}/link.py")
set(MIDL_PROXY "${TOOLS_DIR}/midl.py")

# Configure the C and C++ compilers
set(CMAKE_C_COMPILER "${CL_PROXY}")
set(CMAKE_CXX_COMPILER "${CL_PROXY}")

# Configure the linker
set(CMAKE_LINKER "${LINK_PROXY}")

# VC6 specific compiler flags
set(CMAKE_C_FLAGS_INIT "/nologo /W3 /GX /O2 /D \"WIN32\" /D \"NDEBUG\" /D \"_CONSOLE\"")
set(CMAKE_CXX_FLAGS_INIT "/nologo /W3 /GX /O2 /D \"WIN32\" /D \"NDEBUG\" /D \"_CONSOLE\"")
set(CMAKE_C_FLAGS_DEBUG_INIT "/nologo /W3 /Gm /GX /ZI /Od /D \"WIN32\" /D \"_DEBUG\" /D \"_CONSOLE\" /FR")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "/nologo /W3 /Gm /GX /ZI /Od /D \"WIN32\" /D \"_DEBUG\" /D \"_CONSOLE\" /FR")

# Configure the linker flags
set(CMAKE_EXE_LINKER_FLAGS_INIT "/nologo /machine:I386 /subsystem:console")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "/nologo /machine:I386 /subsystem:windows /dll")

# Ensure our proxy scripts are used for static libraries
set(CMAKE_AR "${LINK_PROXY}")
set(CMAKE_C_COMPILER_AR "${LINK_PROXY}")
set(CMAKE_CXX_COMPILER_AR "${LINK_PROXY}")

# Make sure we don't look for Unix binaries
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Add MIDL compiler command
set(CMAKE_MIDL_COMPILER "${MIDL_PROXY}")

# Define a function to add IDL files to a target
function(target_idl_files TARGET)
    foreach(IDL_FILE ${ARGN})
        get_filename_component(IDL_NAME ${IDL_FILE} NAME_WE)
        set(H_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${IDL_NAME}.h")
        set(C_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${IDL_NAME}_i.c")
        
        add_custom_command(
            OUTPUT ${H_OUTPUT} ${C_OUTPUT}
            COMMAND ${CMAKE_MIDL_COMPILER} /h ${H_OUTPUT} /iid ${C_OUTPUT} ${IDL_FILE}
            DEPENDS ${IDL_FILE}
            COMMENT "Compiling IDL file ${IDL_FILE}"
        )
        
        target_sources(${TARGET} PRIVATE ${H_OUTPUT} ${C_OUTPUT})
        target_include_directories(${TARGET} PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
    endforeach()
endfunction()