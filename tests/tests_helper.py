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
    
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as zf:
        # Create a large file by writing chunks
        chunk_size = 1024 * 1024 * 100  # 100MB chunks
        chunk_data = b"A" * chunk_size
        with zf.open("large_file.txt", "w", force_zip64=True) as f:
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


def validate_zip64_moderate_file(path: str) -> bool:
    """Validate a ZIP64 file with moderate-sized content using Python."""
    try:
        with zipfile.ZipFile(path, "r") as zf:
            # Check that it's a valid ZIP file
            if not zipfile.is_zipfile(path):
                return False
            
            # Check number of files
            names = zf.namelist()
            if len(names) != 1 or names[0] != "test_file.txt":
                return False
            
            # Read and verify content
            content = zf.read("test_file.txt")
            if len(content) != 10 * 1024 * 1024:  # 10MB
                return False
            
            # Verify pattern
            content_str = content.decode('utf-8')
            if not content_str.startswith("ZIP64 test data pattern - "):
                return False
            
            if content_str.count("ZIP64 test data pattern - ") < 100:
                return False
            
            return True
    except Exception:
        return False


def validate_zip64_many_files(path: str, expected_count: int) -> bool:
    """Validate a ZIP64 file with many entries using Python."""
    try:
        with zipfile.ZipFile(path, "r") as zf:
            # Check that it's a valid ZIP file
            if not zipfile.is_zipfile(path):
                return False
            
            # Check number of files
            names = zf.namelist()
            if len(names) != expected_count:
                return False
            
            # Verify file naming pattern
            for i in range(min(10, expected_count)):  # Check first 10 files
                expected_name = f"file_{i:03d}.txt"
                if expected_name not in names:
                    return False
                
                # Verify content of a few files
                content = zf.read(expected_name)
                content_str = content.decode('utf-8')
                expected_start = f"This is the content of file number {i}. "
                if not content_str.startswith(expected_start):
                    return False
            
            return True
    except Exception:
        return False


def validate_zip64_file_general(path: str) -> dict:
    """General validation of ZIP64 file properties using Python."""
    try:
        with zipfile.ZipFile(path, "r") as zf:
            info = {
                "is_valid": zipfile.is_zipfile(path),
                "file_count": len(zf.namelist()),
                "filenames": zf.namelist()[:5],  # First 5 filenames
                "total_size": sum(info.file_size for info in zf.infolist()),
                "compressed_size": sum(info.compress_size for info in zf.infolist()),
            }
            
            # Check if any file info indicates ZIP64
            for file_info in zf.infolist():
                if (file_info.file_size >= 0xFFFFFFFF or 
                    file_info.compress_size >= 0xFFFFFFFF or
                    file_info.header_offset >= 0xFFFFFFFF):
                    info["uses_zip64"] = True
                    break
            else:
                info["uses_zip64"] = False
            
            return info
    except Exception as e:
        return {"is_valid": False, "error": str(e)}
