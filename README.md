# mojo-zipfile 🗂️🔥

A [Mojo](https://github.com/modularml/mojo) implementation of Python's `zipfile` module, enabling ZIP file manipulation with Python-compatible APIs.

## Installation

Install via [Pixi](https://pixi.sh/latest/):

```bash
pixi add mojo-zipfile
```

## Useful links

- [Python zipfile documentation](https://docs.python.org/3/library/zipfile.html)
- [ZIP file format specification](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)
- [mojo-zlib dependency](https://github.com/gabrieldemarmiesse/mojo-zlib)

## Features

mojo-zipfile provides a Mojo-native implementation for reading and writing ZIP archives with:

- **Python-compatible API** - Drop-in replacement for common Python zipfile operations
- **Compression support** - ZIP_STORED (uncompressed) and ZIP_DEFLATED (zlib compression)
- **Streaming operations** - Memory-efficient reading and writing of large files
- **ZIP64 support** - Handle archives larger than 4GB
- **CRC32 verification** - Automatic integrity checking during read operations

Currently implemented features:
- Reading ZIP archives (`ZipFile` with mode='r')
- Writing ZIP archives (`ZipFile` with mode='w', 'a', 'x')
- Extracting individual files (`extract()`, `extractall()`)
- Adding files from memory (`writestr()`)
- Listing archive contents (`namelist()`, `infolist()`)
- File metadata access (`getinfo()`, `ZipInfo`)

## Development

Setting up the development environment:

```bash
# Clone the repository
git clone https://github.com/gabrieldemarmiesse/mojo-zipfile
cd mojo-zipfile

# Install pixi
curl -fsSL https://pixi.sh/install.sh | bash

# Install dependencies
pixi install

# Run tests
pixi run test

# Format code
pixi run format
```

## Quick start

```mojo
from zipfile import ZipFile, ZIP_DEFLATED, ZIP_STORED

fn main() raises:
    # Create a new ZIP file
    with ZipFile("example.zip", "w") as zip_file:
        # Add a file with deflate compression
        zip_file.writestr("hello.txt", "Hello, World!", ZIP_DEFLATED)
        
        # Add a file without compression
        zip_file.writestr("data.bin", "Binary data here", ZIP_STORED)
    
    # Read from a ZIP file
    with ZipFile("example.zip", "r") as zip_file:
        # List all files
        for name in zip_file.namelist():
            print(name)
        
        # Read a specific file
        content = zip_file.read("hello.txt")
        print(String(content))
```

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `is_zipfile(filename)` | Check if a file is a valid ZIP archive |

### ZipFile Class

| Method | Description |
|--------|-------------|
| `ZipFile(file, mode='r', compression=ZIP_STORED, allowZip64=True, compresslevel=None)` | Open a ZIP file |
| `close()` | Close the ZIP file |
| `getinfo(name)` | Get ZipInfo object for a file in the archive |
| `infolist()` | Return a list of ZipInfo objects for all files |
| `namelist()` | Return a list of filenames in the archive |
| `open_to_read(name, mode='r')` | Open a file for reading (returns ZipFileReader) |
| `open_to_write(name, mode='w', compress_type=None, compresslevel=None, force_zip64=False)` | Open a file for writing (returns ZipFileWriter) |
| `read(name)` | Read the entire file contents |
| `writestr(zinfo_or_arcname, data, compress_type=None, compresslevel=None)` | Write data to archive |
| `extract(member, path=None)` | Extract a member to the file system |
| `extractall(path=None, members=None)` | Extract all members to the file system |
| `mkdir(zinfo_or_directory, mode=511)` | Create a directory in the archive |

### ZipInfo Class

| Method/Property | Description |
|-----------------|-------------|
| `ZipInfo(filename)` | Create file metadata object |
| `is_dir()` | Check if entry is a directory |
| `filename` | Name of the file in the archive |

### ZipFileReader Class

| Method | Description |
|--------|-------------|
| `read(size=-1)` | Read up to size bytes |
| `close()` | Close the reader |

### ZipFileWriter Class

| Method | Description |
|--------|-------------|
| `write(data)` | Write data to the archive |
| `close()` | Close the writer and finalize the entry |

### Compression Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `ZIP_STORED` | 0 | No compression |
| `ZIP_DEFLATED` | 8 | Deflate compression |

## Function Details

### `is_zipfile(filename)`

Test whether a file is a valid ZIP archive.

```mojo
from zipfile import is_zipfile

fn main() raises:
    if is_zipfile("myfile.zip"):
        print("It's a ZIP file!")
    else:
        print("Not a ZIP file")
```

### `ZipFile` Constructor

Open a ZIP file for reading, writing, or appending.

**Parameters:**
- `file`: Path to the ZIP file
- `mode`: 'r' (read), 'w' (write), 'a' (append), or 'x' (exclusive create)
- `compression`: Default compression method (ZIP_STORED or ZIP_DEFLATED)
- `allowZip64`: Enable ZIP64 extensions for large files (default: True)
- `compresslevel`: Compression level for ZIP_DEFLATED (0-9, or -1 for default)

### `ZipFile.writestr()`

Write a string or bytes to the archive.

**Parameters:**
- `zinfo_or_arcname`: Archive name (String) or ZipInfo object
- `data`: Data to write (String or List[UInt8])
- `compress_type`: Override default compression for this file
- `compresslevel`: Override default compression level

```mojo
# Write with specific compression
zip_file.writestr("compressed.txt", "Compress me!", ZIP_DEFLATED, compresslevel=9)
```

### `ZipFile.open_to_read()` / `ZipFile.open_to_write()`

Open a file within the archive for streaming operations.

```mojo
# Streaming read
with zip_file.open_to_read("largefile.bin") as reader:
    while True:
        chunk = reader.read(4096)
        if len(chunk) == 0:
            break
        # Process chunk

# Streaming write
with zip_file.open_to_write("output.txt", "w", ZIP_DEFLATED) as writer:
    writer.write("Line 1\n".as_bytes())
    writer.write("Line 2\n".as_bytes())
```

## Code Examples

### Creating a ZIP Archive

```mojo
from zipfile import ZipFile, ZIP_DEFLATED
import os

fn create_archive() raises:
    with ZipFile("archive.zip", "w", ZIP_DEFLATED) as zf:
        # Add a text file
        zf.writestr("readme.txt", "This is my archive")
        
        # Add a binary file
        data = List[UInt8](0x89, 0x50, 0x4E, 0x47)  # PNG header
        zf.writestr("image.png", data)
        
        # Add a directory
        zf.mkdir("folder/")
        
        # Add file to directory
        zf.writestr("folder/data.txt", "Data in folder")
```

### Reading ZIP Contents

```mojo
from zipfile import ZipFile

fn read_archive() raises:
    with ZipFile("archive.zip", "r") as zf:
        # List all files
        print("Files in archive:")
        for info in zf.infolist():
            print(f"  {info.filename} ({'directory' if info.is_dir() else 'file'})")
        
        # Read specific file
        if "readme.txt" in zf.namelist():
            content = zf.read("readme.txt")
            print("Readme contents:", String(content))
```

### Extracting Files

```mojo
from zipfile import ZipFile
import os

fn extract_files() raises:
    with ZipFile("archive.zip", "r") as zf:
        # Extract one file
        zf.extract("readme.txt", path="output/")
        
        # Extract all files
        zf.extractall(path="extracted/")
        
        # Extract specific files
        files_to_extract = ["readme.txt", "folder/data.txt"]
        zf.extractall(path="selected/", members=files_to_extract)
```

### Working with Compression Levels

```mojo
from zipfile import ZipFile, ZIP_DEFLATED
import zlib

fn compression_example() raises:
    # Create archives with different compression levels
    test_data = "Hello World! " * 1000
    
    # No compression
    with ZipFile("no_compress.zip", "w", ZIP_STORED) as zf:
        zf.writestr("data.txt", test_data)
    
    # Default compression
    with ZipFile("default.zip", "w", ZIP_DEFLATED) as zf:
        zf.writestr("data.txt", test_data)
    
    # Maximum compression
    with ZipFile("max_compress.zip", "w", ZIP_DEFLATED, compresslevel=zlib.Z_BEST_COMPRESSION) as zf:
        zf.writestr("data.txt", test_data)
```

### Streaming Large Files

```mojo
from zipfile import ZipFile, ZIP_DEFLATED

fn stream_large_file() raises:
    # Write large file in chunks
    with ZipFile("large.zip", "w") as zf:
        with zf.open_to_write("bigfile.dat", "w", ZIP_DEFLATED) as writer:
            for i in range(1000):
                chunk = ("x" * 1024).as_bytes()  # 1KB chunks
                writer.write(chunk)
    
    # Read large file in chunks
    with ZipFile("large.zip", "r") as zf:
        with zf.open_to_read("bigfile.dat") as reader:
            total_size = 0
            while True:
                chunk = reader.read(4096)
                if len(chunk) == 0:
                    break
                total_size += len(chunk)
            print("Total bytes read:", total_size)
```

### ZIP64 Support

```mojo
from zipfile import ZipFile, ZIP_DEFLATED

fn create_large_archive() raises:
    # ZIP64 is enabled by default for large files
    with ZipFile("large.zip", "w", allowZip64=True) as zf:
        # Add a file larger than 4GB (simulated)
        with zf.open_to_write("huge.bin", "w", ZIP_STORED) as writer:
            chunk = List[UInt8](capacity=1024*1024)  # 1MB
            for _ in range(chunk.capacity):
                chunk.append(0)
            
            # Write 5GB of data
            for _ in range(5 * 1024):
                writer.write(chunk)
```

## Performance

mojo-zipfile leverages Mojo's performance capabilities while maintaining compatibility with Python's zipfile API. The library uses:

- **Native Mojo types** for optimal memory layout
- **Streaming operations** to handle large files efficiently
- **Direct zlib integration** via mojo-zlib for fast compression/decompression
- **Minimal allocations** through careful buffer management

For compression operations, performance is largely determined by the underlying zlib implementation.

## License

MIT License - see [LICENSE](LICENSE) file for details.