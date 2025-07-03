from testing import assert_equal
import os
from zipfile import ZipFile
from python import Python


def test_write_zip64_moderate_file():
    """Test writing a ZIP64 file with moderate-sized content."""
    file_path = "/tmp/zip64_write_moderate_test.zip"

    # Create ZIP64 file using Mojo zipfile with allowZip64=True
    zip_file = ZipFile(file_path, "w", allow_zip64=True)

    # Create 10MB of test data
    pattern = "ZIP64 test data pattern - " * 100  # About 2.5KB pattern
    content_size = 10 * 1024 * 1024  # 10MB
    pattern_bytes = pattern.as_bytes()

    # Build full content by repeating pattern
    full_content = List[UInt8]()
    bytes_added = 0

    while bytes_added < content_size:
        remaining = content_size - bytes_added
        if remaining >= len(pattern_bytes):
            for i in range(len(pattern_bytes)):
                full_content.append(pattern_bytes[i])
            bytes_added += len(pattern_bytes)
        else:
            # Add partial pattern for remaining bytes
            for i in range(remaining):
                full_content.append(pattern_bytes[i])
            bytes_added += remaining

    # Write the large file using String constructor
    full_content_str = String(bytes=full_content)
    zip_file.writestr("test_file.txt", full_content_str)
    zip_file.close()

    # Validate with Python
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    is_valid = tests_helper.validate_zip64_moderate_file(file_path)

    if not is_valid:
        raise Error("Python validation failed for ZIP64 moderate file")

    # Also validate with general ZIP64 check
    validation_info = tests_helper.validate_zip64_file_general(file_path)
    if not validation_info["is_valid"]:
        raise Error("General ZIP64 validation failed")

    # Clean up
    _ = os.remove(file_path)


def test_write_zip64_many_files():
    """Test writing a ZIP64 file with many entries."""
    file_path = "/tmp/zip64_write_many_files_test.zip"

    # Create ZIP64 file with many entries using Mojo zipfile with allowZip64=True
    zip_file = ZipFile(file_path, "w", allow_zip64=True)

    # Create 1000 files for testing
    num_files = 1000
    for i in range(num_files):
        filename = (
            "file_" + ("000" + String(i))[-3:] + ".txt"
        )  # file_000.txt format
        content = "This is the content of file number " + String(i) + ". " * 5
        zip_file.writestr(filename, content)

    zip_file.close()

    # Validate with Python
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    is_valid = tests_helper.validate_zip64_many_files(file_path, num_files)

    if not is_valid:
        raise Error("Python validation failed for ZIP64 many files")

    # Also validate with general ZIP64 check
    validation_info = tests_helper.validate_zip64_file_general(file_path)
    if not validation_info["is_valid"]:
        raise Error("General ZIP64 validation failed")

    # Clean up
    _ = os.remove(file_path)


def test_write_zip64_streaming():
    """Test writing a ZIP64 file using streaming writer."""
    file_path = "/tmp/zip64_write_streaming_test.zip"

    # Create ZIP64 file using streaming writes with allowZip64=True
    zip_file = ZipFile(file_path, "w", allow_zip64=True)

    # Open a file for streaming write with force_zip64=True
    file_writer = zip_file.open_to_write(
        "large_streamed_file.txt", "w", force_zip64=True
    )

    # Write data in chunks
    pattern = "Streaming ZIP64 data chunk - "
    chunk_count = 1000  # Write 1000 chunks
    total_bytes_written = 0

    for i in range(chunk_count):
        chunk_data = (
            pattern + String(i) + " " * 100
        )  # Add padding to make it larger
        chunk_bytes = chunk_data.as_bytes()
        file_writer.write(chunk_bytes)
        total_bytes_written += len(chunk_data)

    file_writer.close()
    zip_file.close()

    # Validate with Python by reading back
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    validation_info = tests_helper.validate_zip64_file_general(file_path)

    if not validation_info["is_valid"]:
        raise Error("General ZIP64 validation failed for streaming test")

    # Verify the file was created and has expected size
    if validation_info["file_count"] != 1:
        raise Error(
            "Expected 1 file, got " + String(validation_info["file_count"])
        )

    # Read back with Python to verify content
    py_zipfile = Python.import_module("zipfile")
    zf = py_zipfile.ZipFile(file_path, "r")
    content = zf.read("large_streamed_file.txt")
    content_str = String(content.decode("utf-8"))
    zf.close()

    # Verify content starts correctly
    if not content_str.startswith("Streaming ZIP64 data chunk - 0"):
        raise Error("Streaming content doesn't start correctly")

    # Verify content contains expected chunks
    if "Streaming ZIP64 data chunk - 500" not in content_str:
        raise Error("Streaming content missing middle chunk")

    if "Streaming ZIP64 data chunk - 999" not in content_str:
        raise Error("Streaming content missing final chunk")

    # Clean up
    _ = os.remove(file_path)
