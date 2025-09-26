#!/usr/bin/env python3
"""
buildinfo.py

Prints Python interpreter and system information in JSON format.
Zero external deps beyond the Python standard library.
"""

import json
import os
import platform
import sys
import sysconfig
import datetime

def get_compiler_info():
    """Get information about the Python compiler and interpreter."""
    info = {
        "version_string": platform.python_version(),
        "implementation": platform.python_implementation(),
        "compiler": platform.python_compiler(),
        "build_date": platform.python_build()[1],
        "build_no": platform.python_build()[0],
        "api_version": sys.api_version,
        "py_version": sys.version_info.major * 100 + sys.version_info.minor * 10 + sys.version_info.micro,
    }
    
    # Check for optimization flags in environment variables
    if 'PYTHONOPTIMIZE' in os.environ:
        info["optimize_any"] = True
        info["optimize_level"] = int(os.environ.get('PYTHONOPTIMIZE', '0'))
    else:
        info["optimize_any"] = False
        info["optimize_level"] = 0
    
    # Check if running with -O or -OO flag
    if sys.flags.optimize > 0:
        info["optimize_any"] = True
        info["optimize_level"] = sys.flags.optimize
    
    # Fast math is not directly applicable to Python, but we'll include it for compatibility
    info["fast_math"] = False
    
    return info

def get_build_info():
    """Get information about the build environment."""
    return {
        "date": datetime.datetime.now().strftime("%b %d %Y"),
        "time": datetime.datetime.now().strftime("%H:%M:%S"),
        "base_file": __file__,
        "executable": sys.executable,
        "prefix": sys.prefix,
        "exec_prefix": sys.exec_prefix,
    }

def get_target_info():
    """Get information about the target system."""
    arch = platform.machine() or "unknown"
    if arch == "x86_64" or arch == "AMD64":
        arch = "x86_64"
    
    os_name = platform.system().lower() or "unknown"
    if os_name == "darwin":
        os_name = "darwin"
    elif os_name == "linux":
        os_name = "linux"
    elif os_name == "windows" or os_name == "microsoft":
        os_name = "windows"
    
    return {
        "arch": arch,
        "os": os_name,
        "endianness": sys.byteorder,
        "pointer_bits": 64 if sys.maxsize > 2**32 else 32,
    }

def get_libc_info():
    """Get information about the libc."""
    libc_info = {"kind": "unknown"}
    
    # Try to detect glibc
    try:
        import ctypes
        try:
            process_namespace = ctypes.CDLL(None)
            gnu_get_libc_version = process_namespace.gnu_get_libc_version
            gnu_get_libc_version.restype = ctypes.c_char_p
            version = gnu_get_libc_version().decode('utf-8')
            libc_info = {
                "kind": "glibc",
                "glibc_version": version
            }
        except (AttributeError, OSError):
            # Not glibc or can't determine
            pass
    except ImportError:
        pass
    
    # Check for macOS
    if platform.system() == "Darwin":
        libc_info = {"kind": "Apple libc"}
    
    return libc_info

def main():
    """Main function to generate and print the JSON output."""
    info = {
        "compiler": get_compiler_info(),
        "build": get_build_info(),
        "target": get_target_info(),
        "libc": get_libc_info(),
    }
    
    print(json.dumps(info, indent=2))

if __name__ == "__main__":
    main()