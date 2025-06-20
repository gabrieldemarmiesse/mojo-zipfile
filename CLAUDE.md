# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Mojo implementation of a ZIP file library that follows the Python zipfile API but with reduced feature set. The library focuses on ZIP_STORED and ZIP_DEFLATED compression methods and implements basic reading and writing functionality.

## Development Commands

### Running Tests
```bash
pixi run test
```

## Architecture

### Core Components

- **zipfile/__init__.mojo**: Main entry point exposing `is_zipfile()` and `ZipFile` class
- **zipfile/reading.mojo**: Core ZIP file reading/writing logic with `ZipFile`, `ZipFileReader`, and `ZipFileWriter` structs
- **zipfile/metadata.mojo**: ZIP file format structures (LocalFileHeader, CentralDirectoryFileHeader, etc.)
- **zipfile/compression.mojo**: Deflate decompression using system zlib (currently read-only)
- **zipfile/crc_32.mojo**: CRC-32 implementation for data integrity verification
- **zipfile/read_write_values.mojo**: Binary data serialization utilities
- **zipfile/utils.mojo**: Utility functions like list comparison

### Key Design Patterns

1. **Python API Compatibility**: Mirrors Python's zipfile module interface (`ZipFile`, `open()`, `writestr()`, etc.)
2. **Streaming Support**: `ZipFileReader` and `ZipFileWriter` provide progressive read/write capabilities
3. **Memory Safety**: Uses Mojo's ownership system with proper resource cleanup via `__del__` and context managers
4. **FFI Integration**: Leverages system zlib via foreign function interface for deflate compression

### Compression Support

- **ZIP_STORED** (0): Uncompressed - fully implemented for read/write
- **ZIP_DEFLATED** (8): Deflate compression - fully implemented for read/write with compression level control, uses system libz.so
- Other compression methods are not supported

### Compression Level API

Following Python's zipfile API (version 3.7+), the library supports compression levels:

- **Compression Level Range**: 0-9 for ZIP_DEFLATED (0=no compression, 9=best compression)
- **Default Level**: -1 (Z_DEFAULT_COMPRESSION, equivalent to level 6)
- **Constants Available**: `Z_BEST_SPEED` (1), `Z_DEFAULT_COMPRESSION` (-1), `Z_BEST_COMPRESSION` (9)

**API Examples:**
```mojo
# Using compression level in writestr
zip_file.writestr("file.txt", data, zipfile.ZIP_DEFLATED, compresslevel=zipfile.Z_BEST_COMPRESSION)

# Using compression level in open_to_write  
writer = zip_file.open_to_write("file.txt", "w", zipfile.ZIP_DEFLATED, compresslevel=9)
```

### Testing Strategy

Tests use Python's zipfile module to create reference ZIP files and verify compatibility. The `tests_helper.py` provides utilities for creating test ZIP files with different compression methods.

## Important Implementation Notes

- Negative file seek offsets are broken in Mojo, affecting some ZIP format operations
- The library assumes no ZIP file comments for simplicity (can be extended later)
- CRC-32 verification is mandatory and automatically performed during read operations
- File writing uses progressive approach with automatic CRC/size backfilling

## Additional information about Mojo
Since the Mojo language is pretty new, the Mojo repository can be found in `modular/` with a memory file at @modular/CLAUDE.md . The files in the `modular/` directory should never be updated and are only here as a reference to understand how the Mojo language works. Whenever in doubt, search the code in this directory.

Do not use print statements in the tests. They won't be seen if the tests are passing correctly.

The reference implementation in python can be found in `zipfile/reference.py`.
List is auto-cast to Span when calling a function. So it's not necessary to implement a function for both Span and List. Just implementing it for Span is enough.

In docstrings, sentences to describle a function or an argument should always end with a "."

In Mojo `Byte` is an alias for `UInt8`.

## String to Bytes Conversion

When converting strings to bytes, use the `String.as_bytes()` method instead of manually iterating:

```mojo
# Preferred - clean and efficient
var text = "Hello, World!"
var bytes = text.as_bytes()

# Avoid - manual conversion
var manual_bytes = List[UInt8]()
for i in range(len(text)):
    manual_bytes.append(ord(text[i]))
```

## Python Interoperability in Tests

You can call Python functions directly from Mojo test files to ensure compatibility. Use this pattern for testing against Python's standard library:

```mojo
from python import Python
from zipfile.utils_testing import to_py_bytes

def test_function_python_compatibility():
    """Test that our function matches Python's behavior."""
    # Import Python module
    py_zlib = Python.import_module("zlib")
    
    # Test data
    test_data = "Hello, World!".as_bytes()
    
    # Call Mojo function
    mojo_result = our_function(test_data)
    
    # Call Python function
    py_data_bytes = to_py_bytes(test_data)
    py_result = py_zlib.function_name(py_data_bytes)
    
    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))
    
    # Compare results
    assert_equal(len(mojo_result), len(py_result_list))
    for i in range(len(mojo_result)):
        assert_equal(mojo_result[i], py_result_list[i])
```

Use `to_py_bytes()` utility function from `zipfile.utils_testing` to convert Mojo bytes to Python bytes objects.
