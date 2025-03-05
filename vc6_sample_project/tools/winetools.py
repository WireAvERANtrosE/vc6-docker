#!/usr/bin/env python3
# This script helps with Wine path conversions and executing commands

import os
import sys
import subprocess
import tempfile

def check_wine_available():
    """Check if Wine and winepath are available."""
    try:
        subprocess.run(['which', 'wine'], capture_output=True, check=True)
        subprocess.run(['which', 'winepath'], capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError:
        print("Error: Wine or winepath not found. This script must run inside the Docker container.")
        print("Please use ./docker-build.sh instead of running directly.")
        return False

def unix_to_wine(path):
    """Convert a Unix path to a Wine path."""
    if not path:
        return path
    
    # Check if winepath is available
    if not check_wine_available():
        sys.exit(1)
        
    result = subprocess.run(['winepath', '-w', path], capture_output=True, text=True)
    return result.stdout.strip()

def wine_to_unix(path):
    """Convert a Wine path to Unix path."""
    if not path:
        return path
        
    # Check if winepath is available
    if not check_wine_available():
        sys.exit(1)
        
    result = subprocess.run(['winepath', '-u', path], capture_output=True, text=True)
    return result.stdout.strip()

def run_cmd(cmd, *args):
    """Run a command through Wine with proper setup."""
    # Create a batch file with the commands
    with tempfile.NamedTemporaryFile(suffix='.bat', delete=False) as f:
        batch_file = f.name
        f.write(b"@echo off\r\n")
        f.write(b"call Z:\\opt\\vc\\setup.bat\r\n")
        
        # Construct the command
        full_cmd = cmd
        for arg in args:
            # If the argument is a file path, convert it
            if os.path.exists(arg) or os.path.exists(os.path.dirname(arg)):
                win_path = unix_to_wine(arg)
                # Replace any quotes
                win_path = win_path.replace('"', '')
                full_cmd += " " + win_path
            else:
                full_cmd += " " + arg
        
        f.write(full_cmd.encode('utf-8') + b"\r\n")
    
    # Run the batch file through Wine
    result = subprocess.run(['wine', 'cmd', '/c', batch_file], capture_output=True, text=True)
    
    # Clean up
    os.unlink(batch_file)
    
    # Return result
    return result.returncode, result.stdout, result.stderr

def compile_file(source, output, *flags):
    """Compile a C/C++ file using CL.EXE."""
    # Convert paths to Windows format
    source_win = unix_to_wine(source)
    output_win = unix_to_wine(output)
    
    # Remove any quotes
    source_win = source_win.replace('"', '')
    output_win = output_win.replace('"', '')
    
    # Make sure the output directory exists
    os.makedirs(os.path.dirname(output), exist_ok=True)
    
    # Construct the command
    cmd = "Z:\\opt\\vc\\BIN\\CL.EXE /nologo /MD /W3 /GX /O2 /DNDEBUG"
    
    # Add include directories
    cmd += " /I Z:\\project\\include"
    cmd += " /I Z:\\project\\build\\idl_output\\sample"
    
    # Add other flags
    for flag in flags:
        cmd += " " + flag
    
    # Add source and output
    cmd += f" /c {source_win} /Fo{output_win}"
    
    # Run the command
    print(f"Compiling {source} -> {output}")
    return run_cmd(cmd)

def link_exe(output, *objects):
    """Link object files into an executable."""
    # Convert output path
    output_win = unix_to_wine(output)
    output_win = output_win.replace('"', '')
    
    # Make sure the output directory exists
    os.makedirs(os.path.dirname(output), exist_ok=True)
    
    # Build the command
    cmd = f"Z:\\opt\\vc\\BIN\\LINK.EXE /nologo /OUT:{output_win}"
    
    # Add object files
    for obj in objects:
        # Check if this is actually a list of objects
        if isinstance(obj, list) or isinstance(obj, tuple):
            for nested_obj in obj:
                obj_win = unix_to_wine(nested_obj)
                obj_win = obj_win.replace('"', '')
                cmd += f" {obj_win}"
        else:
            obj_win = unix_to_wine(obj)
            obj_win = obj_win.replace('"', '')
            cmd += f" {obj_win}"
    
    # Add standard libraries
    cmd += " kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib"
    cmd += " advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib"
    cmd += " odbc32.lib odbccp32.lib"
    
    # Run the command
    print(f"Linking {output}")
    return run_cmd(cmd)

def compile_idl(idl_file, h_file, c_file, tlb_file):
    """Compile an IDL file using MIDL.EXE."""
    # Convert paths
    idl_win = unix_to_wine(idl_file).replace('"', '')
    h_win = unix_to_wine(h_file).replace('"', '')
    c_win = unix_to_wine(c_file).replace('"', '')
    tlb_win = unix_to_wine(tlb_file).replace('"', '')
    
    # Create output directories
    os.makedirs(os.path.dirname(h_file), exist_ok=True)
    os.makedirs(os.path.dirname(c_file), exist_ok=True)
    os.makedirs(os.path.dirname(tlb_file), exist_ok=True)
    
    # Build command
    cmd = f"Z:\\opt\\vc\\BIN\\MIDL.EXE /nologo /h {h_win} /iid {c_win} /tlb {tlb_win} {idl_win}"
    
    # Run command
    print(f"Compiling IDL {idl_file}")
    return run_cmd(cmd)

if __name__ == "__main__":
    # Check if we're in the Docker container with Wine available
    if not check_wine_available():
        print("This script must be run inside the Docker container with Wine installed.")
        print("Please use the docker-build.sh script instead.")
        sys.exit(1)
        
    # Simple command-line interface
    if len(sys.argv) < 2:
        print("Usage: winetools.py command [args]")
        sys.exit(1)
    
    command = sys.argv[1]
    args = sys.argv[2:]
    
    if command == "compile":
        if len(args) < 2:
            print("Usage: winetools.py compile source output [flags]")
            sys.exit(1)
        source = args[0]
        output = args[1]
        flags = args[2:]
        ret, stdout, stderr = compile_file(source, output, *flags)
        print(stdout)
        print(stderr, file=sys.stderr)
        sys.exit(ret)
    
    elif command == "link":
        if len(args) < 2:
            print("Usage: winetools.py link output obj1 [obj2 ...]")
            sys.exit(1)
        output = args[0]
        objects = args[1:]
        ret, stdout, stderr = link_exe(output, *objects)
        print(stdout)
        print(stderr, file=sys.stderr)
        sys.exit(ret)
    
    elif command == "idl":
        if len(args) != 4:
            print("Usage: winetools.py idl idl_file h_file c_file tlb_file")
            sys.exit(1)
        idl_file, h_file, c_file, tlb_file = args
        ret, stdout, stderr = compile_idl(idl_file, h_file, c_file, tlb_file)
        print(stdout)
        print(stderr, file=sys.stderr)
        sys.exit(ret)
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)