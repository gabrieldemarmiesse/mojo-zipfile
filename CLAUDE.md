# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Mojo implementation of a ZIP file library that follows the Python zipfile API but with reduced feature set. The library focuses on ZIP_STORED and ZIP_DEFLATED compression methods and implements basic reading and writing functionality.

## Development Commands

### Running Tests
```bash
pixi run test
```

**Note**: The `pixi run test` command runs the complete test suite (all test functions across 8 test files). When this command succeeds, it means all functionality is working correctly. There is no need to run individual test files separately unless debugging a specific issue.

Run an individual test function with:
```bash
pixi run mojo test -I ./src "tests/test_zip64_limits.mojo::test_zip64_number_of_entries_limit()"
```

## Architecture

### Core Components

- **src/zipfile/__init__.mojo**: Main entry point exposing `is_zipfile()`, `ZipFile`, and `ZipInfo` classes, plus compression constants
- **src/zipfile/_src/zipfile.mojo**: Core ZIP file reading/writing logic with `ZipFile` struct
- **src/zipfile/_src/zipfile_reader.mojo**: `ZipFileReader` struct for streaming file reads
- **src/zipfile/_src/zipfile_writer.mojo**: `ZipFileWriter` struct for streaming file writes
- **src/zipfile/_src/zipinfo.mojo**: `ZipInfo` struct for file metadata
- **src/zipfile/_src/metadata.mojo**: ZIP file format structures (LocalFileHeader, CentralDirectoryFileHeader, etc.)
- **src/zipfile/_src/read_write_values.mojo**: Binary data serialization utilities
- **src/zipfile/_src/utils.mojo**: Utility functions like list comparison
- **src/zipfile/_src/utils_testing.mojo**: Testing utilities for Python interoperability

### Key Design Patterns

1. **Python API Compatibility**: Mirrors Python's zipfile module interface (`ZipFile`, `open_to_read()`, `open_to_write()`, `writestr()`, etc.)
2. **Streaming Support**: `ZipFileReader` and `ZipFileWriter` provide progressive read/write capabilities
3. **Memory Safety**: Uses Mojo's ownership system with proper resource cleanup via `__del__` and context managers
4. **External Dependencies**: Uses mojo-zlib package for compression/decompression and checksum calculations
5. **ZIP64 Support**: Full ZIP64 support with `allowZip64` parameter for large files and archives

### Compression Support

- **ZIP_STORED** (0): Uncompressed - fully implemented for read/write
- **ZIP_DEFLATED** (8): Deflate compression - fully implemented for read/write with compression level control, uses system libz.so
- Other compression methods are not supported

### Compression Level API

Following Python's zipfile API (version 3.7+), the library supports compression levels:

- **Compression Level Range**: 0-9 for ZIP_DEFLATED (0=no compression, 9=best compression)
- **Default Level**: -1 (Z_DEFAULT_COMPRESSION, equivalent to level 6)
- **Constants Available**: `Z_NO_COMPRESSION`, `Z_BEST_SPEED`, `Z_DEFAULT_COMPRESSION`, `Z_BEST_COMPRESSION`

**API Examples:**
```mojo
# Using compression level in writestr
zip_file.writestr("file.txt", data, zipfile.ZIP_DEFLATED, compresslevel=zlib.Z_BEST_COMPRESSION)

# Using compression level in open_to_write  
writer = zip_file.open_to_write("file.txt", "w", zipfile.ZIP_DEFLATED, compresslevel=9)
```

### Testing Strategy

Tests use Python's zipfile module to create reference ZIP files and verify compatibility. The `tests_helper.py` provides utilities for creating test ZIP files with different compression methods.

### Streaming Compression/Decompression API

Following Python's zlib API, the library provides streaming compression and decompression objects:

**Decompression Object API:**
```mojo
var decomp = zlib.decompressobj(wbits=15)  # Create decompression object
var chunk1 = decomp.decompress(compressed_data_part1)  # Decompress incrementally
var chunk2 = decomp.decompress(compressed_data_part2)  # Continue decompression
var final = decomp.flush()  # Get any remaining data
var copy = decomp.copy()  # Create a copy of the decompressor
```

**Compression Object API:**
```mojo
var comp = zlib.compressobj(level=6, wbits=15)  # Create compression object
var chunk1 = comp.compress(data_part1)  # Compress incrementally  
var chunk2 = comp.compress(data_part2)  # Continue compression
var final = comp.flush()  # Finalize and get remaining compressed data
var copy = comp.copy()  # Create a copy of the compressor
```

## Public API Implementation Status

The library provides a subset of Python's zipfile API. See `src/zipfile/__init__.mojo` for the complete status tracking.

### Fully Implemented Features

- **Core Classes**: `ZipFile`, `ZipInfo`, `is_zipfile()` function
- **Compression Constants**: `ZIP_STORED`, `ZIP_DEFLATED`
- **ZipFile Methods**: `close()`, `getinfo()`, `infolist()`, `namelist()`, `open_to_read()`, `open_to_write()`, `read()`, `writestr()`
- **ZipInfo Methods**: `is_dir()`, `filename` property
- **ZIP64 Support**: Full ZIP64 support with `allowZip64` parameter
- **Compression Levels**: Full support for compression levels 0-9 with ZIP_DEFLATED

### Not Yet Implemented Features

- **ZipFile Methods**: `extract()`, `extractall()`, `printdir()`, `setpassword()`, `testzip()`, `write()`, `mkdir()`
- **ZipFile Properties**: `filename`, `debug`, `comment`
- **ZipInfo Properties**: `date_time`, `compress_type`, `comment`, `extra`, `CRC`, `compress_size`, `file_size`, etc.
- **ZipInfo Methods**: `from_file()` constructor
- **Path API**: Complete `Path` class functionality
- **PyZipFile**: Specialized ZIP file class for Python files
- **Additional Compression**: `ZIP_BZIP2`, `ZIP_LZMA`

## Important Implementation Notes

- Negative file seek offsets are broken in Mojo, affecting some ZIP format operations
- The library assumes no ZIP file comments for simplicity (can be extended later)
- CRC-32 verification is mandatory and automatically performed during read operations
- File writing uses progressive approach with automatic CRC/size backfilling
- Streaming compression/decompression objects match Python's zlib API for compatibility
- ZIP64 support is fully implemented with proper fallback for regular ZIP files
- All compression/decompression and checksum operations use the mojo-zlib package

## Additional information about Mojo
Since the Mojo language is pretty new, the Mojo repository can be found in `modular/` with a memory file at @modular/CLAUDE.md . The files in the `modular/` directory should never be updated and are only here as a reference to understand how the Mojo language works. Whenever in doubt, search the code in this directory.

Do not use print statements in the tests. They won't be seen if the tests are passing correctly.
You can only use them to debug code. But they must be removed when debugging is done.

The reference implementation in python can be found in `tests/tests_helper.py`.
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
from zipfile.utils_testing import to_py_bytes, assert_lists_are_equal, to_mojo_bytes

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
    py_result_list = to_mojo_bytes(py_result)
    
    # Compare results
    assert_lists_are_equal(mojo_result, py_result_list)
```

Use `to_py_bytes()` utility function from `zipfile.utils_testing` to convert Mojo bytes to Python bytes objects.

## Additional Utility Functions in `utils_testing.mojo`

**Data Conversion:**
- `to_py_bytes(data: Span[Byte]) -> PythonObject` - Convert Mojo bytes to Python bytes
- `to_mojo_bytes(some_data: PythonObject) -> List[Byte]` - Convert Python bytes to Mojo bytes  
- `to_mojo_string(some_data: PythonObject) -> String` - Convert Python bytes to Mojo String

**Testing Utilities:**
- `assert_lists_are_equal(list1: List[Byte], list2: List[Byte], message: String)` - Compare two byte lists with detailed error messages
- `test_mojo_vs_python_decompress(test_data: Span[Byte], wbits: Int = 15, bufsize: Int = 16384, message: String)` - Helper to test Mojo vs Python decompress compatibility

**Usage Example:**
```mojo
# Simple comparison
var result1 = function1(data)
var result2 = function2(data) 
assert_lists_are_equal(result1, result2, "Functions should produce same result")

# Python compatibility test
test_mojo_vs_python_decompress(
    test_data.as_bytes(),
    wbits=31,
    message="gzip format should match Python"
)
```

## Testing Error Conditions

For testing error conditions and exceptions, use Mojo's `assert_raises` as a context manager:

```mojo
from testing import assert_raises

# Test that a function raises an error
def test_invalid_input():
    var invalid_data = List[UInt8](1, 2, 3, 4, 5)
    
    with assert_raises():
        _ = zlib.decompress(invalid_data)

# Test that an error contains specific text
def test_specific_error():
    with assert_raises(contains="File not found"):
        _ = zip_file.read("nonexistent.txt")
```

**Important**: Use `assert_raises()` as a context manager with `with` statement, not as a function call with lambda. The context manager pattern is the correct and idiomatic way to test exceptions in Mojo.

The documentation for the zlib module can be found at https://raw.githubusercontent.com/gabrieldemarmiesse/mojo-zlib/refs/heads/main/README.md . Don't hesistate to look it up.

Spec for zipfiles: https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT, use it too when in doubt.

