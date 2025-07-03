import zipfile

def create_hello_world_zip(path: str):
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("hello.txt", "hello world!")


def create_complicated_zip(path: str):
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("hello.txt", "hello world!")
        zf.writestr("foo/bar.txt", "foo bar")
        zf.writestr("foo/baz.txt", "foo baz")
        zf.writestr("qux.txt", "qux")


def check_empty_zip(path: str):
    assert zipfile.is_zipfile(path)
    with zipfile.ZipFile(path, "r") as zf:
        assert len(zf.namelist()) == 0


def create_empty_zip(path: str):
    with zipfile.ZipFile(path, "w") as zf:
        pass


def verify_hello_world_zip(path: str):
    assert zipfile.is_zipfile(path)
    with zipfile.ZipFile(path, "r") as zf:
        assert len(zf.namelist()) == 1
        assert zf.read("hello.txt") == b"hello world!"


def create_hello_world_zip_with_deflate(path: str):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("hello.txt", "hello world!", compress_type=zipfile.ZIP_DEFLATED)


def create_zip64_large_file(path: str):
    """Create a ZIP64 file with a large file that exceeds 4GB limit."""
    # Create a file that's 4GB + 100 bytes to force ZIP64
    large_size = 4 * 1024 * 1024 * 1024 + 100
    
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=True) as zf:
        # Create a large file by writing chunks
        with zf.open("large_file.txt", "w", force_zip64=True) as f:
            chunk_size = 1024 * 1024  # 1MB chunks
            chunk_data = b"A" * chunk_size
            bytes_written = 0
            
            while bytes_written < large_size:
                remaining = large_size - bytes_written
                if remaining < chunk_size:
                    f.write(b"A" * remaining)
                else:
                    f.write(chunk_data)
                bytes_written += min(chunk_size, remaining)


def create_zip64_moderate_file(path: str):
    """Create a ZIP64 file with a moderate-sized file for testing."""
    # Create a 10MB file to test ZIP64 without huge file sizes
    content_size = 10 * 1024 * 1024  # 10MB
    
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=True) as zf:
        # Create repeating pattern
        pattern = b"ZIP64 test data pattern - " * 100  # About 2.5KB pattern
        full_content = pattern * (content_size // len(pattern))
        remaining = content_size % len(pattern)
        if remaining > 0:
            full_content += pattern[:remaining]
        
        zf.writestr("test_file.txt", full_content, compress_type=zipfile.ZIP_DEFLATED)


def create_zip64_many_files(path: str):
    """Create a ZIP64 file with many files (over 65535 entries)."""
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as zf:
        # Create 70000 small files to exceed 16-bit limit
        for i in range(70000):
            filename = f"file_{i:05d}.txt"
            content = f"Content of file {i}"
            zf.writestr(filename, content)


def create_zip64_moderate_many_files(path: str):
    """Create a ZIP64 file with moderate number of files for testing."""
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as zf:
        # Create 1000 files for testing
        for i in range(1000):
            filename = f"file_{i:03d}.txt"
            content = f"This is the content of file number {i}. " * 5
            zf.writestr(filename, content)


def create_zip64_large_central_directory(path: str):
    """Create a ZIP64 file with a central directory that exceeds 4GB."""
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as zf:
        # Create many files with long names to make central directory large
        for i in range(100000):
            # Very long filename to make central directory entries large
            filename = f"very_long_filename_{'x' * 200}_{i:05d}.txt"
            content = f"File {i}"
            zf.writestr(filename, content)
