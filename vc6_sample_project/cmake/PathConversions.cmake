# CMake script to handle Wine path conversions
# This is used by the vc6-toolchain.cmake file

# Define a function to convert file paths to Wine format
function(to_wine_paths)
    # Iterate over all non-executable files in the command line
    foreach(file ${ARGV})
        # Skip if it's not a file
        if(NOT EXISTS ${file})
            continue()
        endif()
        
        # Convert to a Windows path
        execute_process(
            COMMAND winepath -w ${file}
            OUTPUT_VARIABLE win_path
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        
        # Replace the path in the arguments
        string(REPLACE ${file} ${win_path} args "${args}")
    endforeach()
    
    # Return the updated arguments
    set(CONVERTED_ARGS ${args} PARENT_SCOPE)
endfunction()