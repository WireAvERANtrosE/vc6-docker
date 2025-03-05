#!/usr/bin/python3

import os
import sys
import subprocess
import tempfile
import re
import shutil
import platform
from pathlib import Path

# Constants
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

# Check if running on Windows
IS_WINDOWS = platform.system() == "Windows"

def unix_to_wine(path):
    """Convert a Unix path to a Wine-compatible path using winepath if available."""
    if IS_WINDOWS:
        return path
    
    try:
        # Try to use winepath command if available
        process = subprocess.Popen(
            ["winepath", "-w", path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        stdout, stderr = process.communicate()
        
        if process.returncode == 0 and stdout.strip():
            return stdout.strip()
    except (subprocess.SubprocessError, FileNotFoundError):
        # Fallback if winepath isn't available
        pass
    
    # Fallback conversion - simple but less reliable
    if os.path.isabs(path):
        return "Z:" + path
    return path

def wine_to_unix(path):
    """Convert a Wine path to a Unix-compatible path using winepath if available."""
    if IS_WINDOWS:
        return path
    
    try:
        # Try to use winepath command if available
        process = subprocess.Popen(
            ["winepath", "-u", path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        stdout, stderr = process.communicate()
        
        if process.returncode == 0 and stdout.strip():
            return stdout.strip()
    except (subprocess.SubprocessError, FileNotFoundError):
        # Fallback if winepath isn't available
        pass
    
    # Fallback conversion - simple but less reliable
    if re.match(r'^[A-Za-z]:', path):
        # Remove drive letter and convert backslashes
        drive_letter = path[0]
        if drive_letter.lower() == 'z':
            # Z: is mapped to root in Wine
            return path[2:].replace("\\", "/")
        else:
            # Other drives might be mapped differently
            drive_path = path[2:].replace('\\', '/')
            return "/mnt/{0}{1}".format(drive_letter.lower(), drive_path)
    
    # For relative paths, just replace backslashes
    return path.replace("\\", "/")

def run_command_with_wine(cmd, env=None, cwd=None):
    """Run a command with Wine, handling the environment and working directory."""
    if IS_WINDOWS:
        # On Windows, run the command directly
        process = subprocess.Popen(
            cmd, 
            env=env, 
            cwd=cwd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE,
            universal_newlines=True,
            shell=True
        )
    else:
        # On Unix, use Wine
        wine_cmd = ['wine'] + cmd
        process = subprocess.Popen(
            wine_cmd, 
            env=env, 
            cwd=cwd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
    
    stdout, stderr = process.communicate()
    return process.returncode, stdout, stderr

def create_batch_file(commands):
    """Create a temporary batch file with the given commands."""
    fd, path = tempfile.mkstemp(suffix='.bat')
    with os.fdopen(fd, 'w') as f:
        f.write("@echo off\r\n")
        
        # Add setup.bat if not on Windows
        if not IS_WINDOWS:
            setup_path = unix_to_wine(os.path.join(ROOT_DIR, 'setup.bat'))
            f.write("call {0}\r\n".format(setup_path))
            
        for cmd in commands:
            f.write("{0}\r\n".format(cmd))
    
    return path

class ProxyCompiler:
    """Base class for proxy compilers."""
    def __init__(self, env=None):
        self.env = env or os.environ.copy()
    
    def _run_batch(self, commands):
        """Run a batch file with the specified commands."""
        batch_path = create_batch_file(commands)
        
        try:
            if IS_WINDOWS:
                cmd = [batch_path]
            else:
                cmd = ["cmd", "/c", unix_to_wine(batch_path)]
            
            print("-------- Executing batch command --------")
            print(f"Batch file: {batch_path}")
            with open(batch_path, 'r') as f:
                print("Batch contents:")
                for line in f:
                    print(f"  {line.rstrip()}")
            print("----------------------------------------")
            
            returncode, stdout, stderr = run_command_with_wine(cmd, env=self.env)
            
            print("-------- Command output --------")
            # Print output for debugging
            if stdout:
                print(stdout)
            if stderr:
                print(stderr, file=sys.stderr)
            print("-------------------------------")
                
            return returncode
        finally:
            os.unlink(batch_path)

class CLCompiler(ProxyCompiler):
    """Proxy for Microsoft CL compiler."""
    def __init__(self, env=None):
        super().__init__(env)
        self.simplified_compile = False
        self.simplified_src = None
        self.simplified_out = None
        
    def compile(self, args):
        """Compile a file using CL.EXE."""
        # Print the original arguments for debugging
        print("Original args:", args)
        
        # Special fix for first CMake test compile
        simplified_compile = False
        simplified_src = None
        simplified_out = None
        include_dirs = []
        define_macros = []
        
        # Extract include directories and macros from original args
        i = 0
        while i < len(args):
            if i < len(args) - 1:
                # Handle -I (Unix-style include directory)
                if args[i].startswith('-I'):
                    include_dir = args[i][2:]  # Remove the '-I' prefix
                    include_dirs.append(include_dir)
                    i += 1
                # Handle /I (Windows-style include directory)
                elif args[i].startswith('/I'):
                    include_dir = args[i][2:]  # Remove the '/I' prefix
                    include_dirs.append(include_dir)
                    i += 1
                # Handle -I with space
                elif args[i] == '-I' and i + 1 < len(args):
                    include_dirs.append(args[i+1])
                    i += 2
                # Handle /I with space
                elif args[i] == '/I' and i + 1 < len(args):
                    include_dirs.append(args[i+1])
                    i += 2
                # Handle /D macros
                elif args[i] == '/D' and i + 1 < len(args):
                    define_macros.append(args[i+1])
                    i += 2
                # Handle combined /D macros
                elif args[i].startswith('/D'):
                    define_macros.append(args[i][2:])  # Remove the '/D' prefix
                    i += 1
                else:
                    i += 1
            else:
                i += 1
        
        # Check for simple compile scenario (CMake test compile)
        if "-c" in args and any(arg.startswith('/Fo') for arg in args):
            # Get the source file (usually at the end after -c)
            src_idx = args.index("-c") + 1
            if src_idx < len(args) and os.path.exists(args[src_idx]):
                src_file = args[src_idx]
                
                # Get output file
                out_file = None
                for arg in args:
                    if arg.startswith('/Fo'):
                        out_file = arg[3:]
                        break
                
                if src_file and out_file:
                    # Simplify to just what's needed for a basic compile
                    simplified_compile = True
                    simplified_src = src_file
                    simplified_out = out_file
                    print("Will use simplified compile with src:", src_file, "output:", out_file)
        
        # Process the arguments to handle common patterns coming from CMake
        processed_args = []
        src_file = None
        i = 0
        
        while i < len(args):
            arg = args[i]
            
            # Handle special parameter pairs requiring quote fixing
            if arg.startswith('/D') and not arg.startswith('/D"') and i + 1 < len(args) and ' ' in args[i+1]:
                # Make sure /D "WIN32" becomes /D"WIN32" as required by CL
                processed_args.append(f'{arg}"{args[i+1]}"')
                i += 2
                continue
                
            # Handle file output directives that need combining
            elif arg in ['/Fo', '/Fd', '/Fp'] and i + 1 < len(args):
                processed_args.append(arg + args[i+1])
                i += 2
                continue
                
            # Skip -c and remember the source file that follows
            elif arg == '-c' and i + 1 < len(args):
                # Replace with Windows-style /c
                processed_args.append('/c')
                if i + 1 < len(args) and args[i+1].endswith(('.c', '.cpp', '.cxx')):
                    src_file = args[i+1]
                i += 2
                continue
                
            # For all other arguments, pass through unchanged
            else:
                processed_args.append(arg)
                i += 1
        
        # Make sure we have the source file at the end
        if src_file and src_file not in processed_args:
            processed_args.append(src_file)
        
        # Convert paths in processed args to Wine paths
        wine_args = []
        for arg in processed_args:
            # Handle flag arguments with '/' prefix - those stay as is
            if arg.startswith('/'):
                # For directives with embedded paths, extract and convert path part
                if arg.startswith('/Fo') or arg.startswith('/Fd') or arg.startswith('/Fp'):
                    directive = arg[:3]  # /Fo, /Fd, etc.
                    path = arg[3:]
                    if os.path.exists(os.path.dirname(path)):
                        wine_path = unix_to_wine(path)
                        wine_args.append(f'{directive}{wine_path}')
                    else:
                        wine_args.append(arg)
                elif arg.startswith('/I'):
                    # Handle include directive
                    include_path = arg[2:]  # Remove /I
                    if os.path.exists(include_path):
                        wine_path = unix_to_wine(include_path)
                        wine_args.append(f'/I{wine_path}')
                    else:
                        wine_args.append(arg)
                else:
                    wine_args.append(arg)
            # Handle quoted strings carefully
            elif arg.startswith('"') and arg.endswith('"') and os.path.exists(arg[1:-1]):
                wine_path = unix_to_wine(arg[1:-1])
                wine_args.append(f'"{wine_path}"')
            # Handle file paths - those get converted
            elif os.path.exists(arg):
                wine_args.append(unix_to_wine(arg))
            # Everything else stays as is
            else:
                wine_args.append(arg)
        
        # Check if we need to use the simplified compile command
        if simplified_compile:
            # Convert the paths properly
            wine_src_path = unix_to_wine(simplified_src)
            wine_out_path = unix_to_wine(simplified_out)
            
            # Create a simple command with properly converted paths
            wine_args = ['/nologo', '/c']
            
            # Add all include directories
            for include_dir in include_dirs:
                if os.path.exists(include_dir):
                    wine_include = unix_to_wine(include_dir)
                    wine_args.append(f'/I{wine_include}')
            
            # Add all define macros
            for macro in define_macros:
                wine_args.append(f'/D{macro}')
            
            # Add source and output
            wine_args.append(wine_src_path)
            wine_args.append(f'/Fo{wine_out_path}')
            
            print("Using simplified compile with properly converted paths")
            
        # Print the processed arguments for debugging
        print("Processed args:", wine_args)
        
        # Construct CL command
        cl_cmd = "CL.EXE {0}".format(' '.join(wine_args))
        
        # Print the final command for debugging
        print("Executing: " + cl_cmd)
        
        # Run the command
        return self._run_batch([cl_cmd])

class LinkExe(ProxyCompiler):
    """Proxy for Microsoft LINK.EXE."""
    def __init__(self, env=None):
        super().__init__(env)
        
    def link(self, args):
        """Link files using LINK.EXE."""
        # Print the original arguments for debugging
        print("Original link args:", args)
        
        # Extract all relevant parts from the arguments
        out_file = None
        implib_file = None
        pdb_file = None
        response_files = []
        obj_files = []
        lib_files = []
        other_args = []
        
        i = 0
        while i < len(args):
            arg = args[i]
            
            # Handle response files (@file)
            if arg.startswith('@'):
                response_files.append(arg[1:])  # Remove the @ for path conversion
                i += 1
            # Handle combined output file directive
            elif arg.startswith('/out:'):
                out_file = arg[5:]  # Remove '/out:'
                i += 1
            # Handle combined implib directive
            elif arg.startswith('/implib:'):
                implib_file = arg[8:]  # Remove '/implib:'
                i += 1
            # Handle combined pdb directive
            elif arg.startswith('/pdb:'):
                pdb_file = arg[5:]  # Remove '/pdb:'
                i += 1
            # Handle split output file directive
            elif arg == '/out:' and i + 1 < len(args):
                out_file = args[i+1]
                i += 2
            # Handle split implib directive
            elif arg == '/implib:' and i + 1 < len(args):
                implib_file = args[i+1]
                i += 2
            # Handle split pdb directive
            elif arg == '/pdb:' and i + 1 < len(args):
                pdb_file = args[i+1]
                i += 2
            # Handle object files (.obj)
            elif arg.endswith('.obj'):
                obj_files.append(arg)
                i += 1
            # Handle library files (.lib)
            elif arg.endswith('.lib'):
                lib_files.append(arg)
                i += 1
            # Any other options
            else:
                other_args.append(arg)
                i += 1
        
        # Convert all the file paths to Wine paths
        wine_args = []
        
        # Add other options first
        wine_args.extend(other_args)
        
        # Add converted response files
        for resp_file in response_files:
            # Check if the response file exists
            if os.path.exists(resp_file):
                wine_resp = unix_to_wine(resp_file)
                wine_args.append(f'@{wine_resp}')
            else:
                # If it doesn't exist, pass it as is
                wine_args.append(f'@{resp_file}')
        
        # Add converted object files
        for obj_file in obj_files:
            # Check if the object file exists
            if os.path.exists(obj_file):
                wine_obj = unix_to_wine(obj_file)
                wine_args.append(wine_obj)
            else:
                # If it doesn't exist, pass it as is
                wine_args.append(obj_file)
        
        # Add converted library files
        for lib_file in lib_files:
            # Check if the library file exists before converting its path
            if os.path.exists(lib_file):
                wine_lib = unix_to_wine(lib_file)
                wine_args.append(wine_lib)
            else:
                # If the file doesn't exist, assume it's a system library and pass it as-is
                wine_args.append(lib_file)
                print(f"Treating {lib_file} as system library (file not found)")
        
        # Add output file directive
        if out_file:
            # Make sure the directory exists before converting path
            if os.path.dirname(out_file) and os.path.exists(os.path.dirname(out_file)):
                wine_out = unix_to_wine(out_file)
                wine_args.append(f'/out:{wine_out}')
            else:
                # If it's just a filename without directory, use it as is
                wine_args.append(f'/out:{out_file}')
        
        # Add implib directive
        if implib_file:
            # Make sure the directory exists before converting path
            if os.path.dirname(implib_file) and os.path.exists(os.path.dirname(implib_file)):
                wine_implib = unix_to_wine(implib_file)
                wine_args.append(f'/implib:{wine_implib}')
            else:
                # If it's just a filename without directory, use it as is
                wine_args.append(f'/implib:{implib_file}')
                
        # Add pdb directive
        if pdb_file:
            # Make sure the directory exists before converting path
            if os.path.dirname(pdb_file) and os.path.exists(os.path.dirname(pdb_file)):
                wine_pdb = unix_to_wine(pdb_file)
                wine_args.append(f'/pdb:{wine_pdb}')
            else:
                # If it's just a filename without directory, use it as is
                wine_args.append(f'/pdb:{pdb_file}')
        
        # Print the processed arguments for debugging
        print("Processed link args:", wine_args)
        
        # Construct LINK command
        link_cmd = "LINK.EXE {0}".format(' '.join(wine_args))
        
        # Print the final command for debugging
        print("Executing: " + link_cmd)
        
        # Run the command
        return self._run_batch([link_cmd])

class MidlCompiler(ProxyCompiler):
    """Proxy for Microsoft MIDL.EXE."""
    def __init__(self, env=None):
        super().__init__(env)
        
    def compile(self, args):
        """Compile an IDL file using MIDL.EXE."""
        # Print the original arguments for debugging
        print("Original MIDL args:", args)
        
        # Extract all relevant parts from the arguments
        header_file = None
        iid_file = None
        idl_file = None
        other_args = []
        
        i = 0
        while i < len(args):
            arg = args[i]
            
            # Handle /h option (header file)
            if arg in ['/h', '/header'] and i + 1 < len(args):
                header_file = args[i+1]
                i += 2
            # Handle /iid option (interface ID file)
            elif arg == '/iid' and i + 1 < len(args):
                iid_file = args[i+1]
                i += 2
            # Handle other option pairs that take a filename
            elif arg in ['/acf', '/out', '/cstub', '/dlldata', '/proxy', '/sstub', '/tlb'] and i + 1 < len(args):
                # Convert the filename that follows the option
                if os.path.exists(os.path.dirname(args[i+1])):
                    wine_path = unix_to_wine(args[i+1])
                    other_args.append(arg)
                    other_args.append(wine_path)
                else:
                    # If path doesn't exist, pass it as is
                    other_args.append(arg)
                    other_args.append(args[i+1])
                i += 2
            # Last argument is the IDL file (even if it starts with /)
            elif i == len(args) - 1:
                idl_file = arg
                i += 1
            # Any other options
            else:
                other_args.append(arg)
                i += 1
        
        # Convert all the file paths to Wine paths
        wine_args = []
        
        # Add converted option arguments
        if header_file:
            if os.path.exists(os.path.dirname(header_file)):
                wine_header = unix_to_wine(header_file)
                wine_args.append('/h')
                wine_args.append(wine_header)
            else:
                # If path doesn't exist, pass it as is
                wine_args.append('/h')
                wine_args.append(header_file)
            
        if iid_file:
            if os.path.exists(os.path.dirname(iid_file)):
                wine_iid = unix_to_wine(iid_file)
                wine_args.append('/iid')
                wine_args.append(wine_iid)
            else:
                # If path doesn't exist, pass it as is
                wine_args.append('/iid')
                wine_args.append(iid_file)
        
        # Add other options
        wine_args.extend(other_args)
        
        # Add the IDL file at the end
        if idl_file:
            if os.path.exists(idl_file) or os.path.exists(os.path.dirname(idl_file)):
                wine_idl = unix_to_wine(idl_file)
                wine_args.append(wine_idl)
            else:
                # If file doesn't exist (unlikely for IDL file), pass it as is
                wine_args.append(idl_file)
                print(f"Warning: IDL file {idl_file} not found, passing as-is")
        
        # Print the processed arguments for debugging
        print("Processed MIDL args:", wine_args)
        
        # Construct MIDL command
        midl_cmd = "MIDL.EXE {0}".format(' '.join(wine_args))
        
        # Print the final command for debugging
        print("Executing: " + midl_cmd)
        
        # Run the command
        return self._run_batch([midl_cmd])

if __name__ == "__main__":
    # If run directly, print help
    print("VC6 Wine Tools - Python proxy for building with Visual C++ 6.0 through Wine")
    print("Usage: This script is intended to be used as a module, not run directly.")
    print("For compiler scripts, use the cl.py, link.py, or midl.py proxy scripts.")
    sys.exit(0)