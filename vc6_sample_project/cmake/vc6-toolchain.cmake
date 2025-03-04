# VC6 Toolchain File for CMake
# This file configures CMake to use Visual C++ 6.0 through Wine

# System information
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_VERSION 6.0)
set(CMAKE_SYSTEM_PROCESSOR X86)

# Disable compiler tests
set(CMAKE_C_COMPILER_WORKS TRUE CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_WORKS TRUE CACHE INTERNAL "")
set(CMAKE_C_ABI_COMPILED TRUE CACHE INTERNAL "")
set(CMAKE_CXX_ABI_COMPILED TRUE CACHE INTERNAL "")

# Create wrapper script that just runs the compilation directly
file(WRITE "${CMAKE_BINARY_DIR}/compile.sh" "#!/bin/bash
# Get source and output filenames
SOURCE=\"\$1\"
OUTPUT=\"\$2\"

# Get Windows-style paths
SOURCE_WIN=\$(winepath -w \"\$SOURCE\")
OUTPUT_WIN=\$(winepath -w \"\$OUTPUT\")

# Remove quotes from the Windows paths (they'll be added back in the command)
SOURCE_WIN=\${SOURCE_WIN//\\\"/}
OUTPUT_WIN=\${OUTPUT_WIN//\\\"/}

# Set Windows include path
INCLUDE_PATH=\"Z:\\\\project\\\\include\"
IDL_PATH=\"Z:\\\\project\\\\build\\\\idl_output\\\\sample\"

# Run the compiler
echo \"Compiling \$SOURCE to \$OUTPUT\"
wine cmd /c \"Z:\\\\opt\\\\vc\\\\setup.bat && Z:\\\\opt\\\\vc\\\\BIN\\\\CL.EXE /nologo /MD /W3 /GX /O2 /DNDEBUG /I \$INCLUDE_PATH /I \$IDL_PATH /c \$SOURCE_WIN /Fo\$OUTPUT_WIN\"
")
execute_process(COMMAND chmod +x "${CMAKE_BINARY_DIR}/compile.sh")

# Create a simple direct link script
file(WRITE "${CMAKE_BINARY_DIR}/link.sh" "#!/bin/bash
# Get output filename
TARGET=\"\$1\"
shift

# Process object files
OBJECTS=\"\"
for OBJ in \"\$@\"; do
    # Convert to Windows path
    OBJ_WIN=\$(winepath -w \"\$OBJ\")
    
    # Strip any quotes
    OBJ_WIN=\${OBJ_WIN//\\\"/}
    
    # Add to object list
    OBJECTS=\"\$OBJECTS \$OBJ_WIN\"
done

# Get Windows-style output path
TARGET_WIN=\$(winepath -w \"\$TARGET\")
TARGET_WIN=\${TARGET_WIN//\\\"/}

# Run the linker
echo \"Linking \$TARGET\"
wine cmd /c \"Z:\\\\opt\\\\vc\\\\setup.bat && Z:\\\\opt\\\\vc\\\\BIN\\\\LINK.EXE /nologo /OUT:\$TARGET_WIN \$OBJECTS kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib\"
")
execute_process(COMMAND chmod +x "${CMAKE_BINARY_DIR}/link.sh")

# Set up compiler variables
set(CMAKE_C_COMPILER "${CMAKE_BINARY_DIR}/compile.sh" CACHE FILEPATH "C compiler" FORCE)
set(CMAKE_CXX_COMPILER "${CMAKE_BINARY_DIR}/compile.sh" CACHE FILEPATH "C++ compiler" FORCE)

# Set compile and link rules
set(CMAKE_C_COMPILE_OBJECT "<CMAKE_C_COMPILER> <SOURCE> <OBJECT>")
set(CMAKE_CXX_COMPILE_OBJECT "<CMAKE_CXX_COMPILER> <SOURCE> <OBJECT>")
set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_BINARY_DIR}/link.sh <TARGET> <OBJECTS>")
set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_BINARY_DIR}/link.sh <TARGET> <OBJECTS>")

# Function to process IDL files
function(process_idl_files target)
    # Create the MIDL wrapper script
    file(WRITE "${CMAKE_BINARY_DIR}/midl.sh" "#!/bin/bash
# Get file paths
IDL=\"\$1\"
H_FILE=\"\$2\"
C_FILE=\"\$3\"
TLB_FILE=\"\$4\"

# Create output directories
mkdir -p \$(dirname \"\$H_FILE\")
mkdir -p \$(dirname \"\$C_FILE\")
mkdir -p \$(dirname \"\$TLB_FILE\")

# Convert to Windows paths
IDL_WIN=\$(winepath -w \"\$IDL\")
H_WIN=\$(winepath -w \"\$H_FILE\")
C_WIN=\$(winepath -w \"\$C_FILE\")
TLB_WIN=\$(winepath -w \"\$TLB_FILE\")

# Strip quotes
IDL_WIN=\${IDL_WIN//\\\"/}
H_WIN=\${H_WIN//\\\"/}
C_WIN=\${C_WIN//\\\"/}
TLB_WIN=\${TLB_WIN//\\\"/}

# Run MIDL
echo \"Processing IDL file \$IDL\"
wine cmd /c \"Z:\\\\opt\\\\vc\\\\setup.bat && Z:\\\\opt\\\\vc\\\\BIN\\\\MIDL.EXE /nologo /h \$H_WIN /iid \$C_WIN /tlb \$TLB_WIN \$IDL_WIN\"
")
    execute_process(COMMAND chmod +x "${CMAKE_BINARY_DIR}/midl.sh")

    # Process each IDL file
    foreach(idl ${ARGN})
        # Get file info
        get_filename_component(idl_name ${idl} NAME_WE)
        get_filename_component(idl_abs ${idl} ABSOLUTE)
        
        # Set output files
        set(output_dir "${CMAKE_BINARY_DIR}/idl_output/${idl_name}")
        file(MAKE_DIRECTORY ${output_dir})
        
        set(h_file "${output_dir}/${idl_name}.h")
        set(c_file "${output_dir}/${idl_name}_i.c")
        set(tlb_file "${output_dir}/${idl_name}.tlb")
        
        # Add custom command to compile IDL
        add_custom_command(
            OUTPUT ${h_file} ${c_file} ${tlb_file}
            COMMAND ${CMAKE_BINARY_DIR}/midl.sh ${idl_abs} ${h_file} ${c_file} ${tlb_file}
            DEPENDS ${idl}
            COMMENT "Compiling IDL file ${idl}"
            VERBATIM
        )
        
        # Add to target
        target_sources(${target} PRIVATE ${c_file})
        target_include_directories(${target} PRIVATE ${output_dir})
    endforeach()
endfunction()