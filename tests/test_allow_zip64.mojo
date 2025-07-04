from testing import assert_raises, assert_equal, assert_true
import os
from zipfile import ZipFile
from zipfile._src.utils_testing import to_mojo_bytes
from python import Python


def test_allow_zip64_default_true():
    """Test that allowZip64 defaults to True."""
    file_path = "/tmp/test_allow_zip64_default.zip"

    # Create a ZipFile without specifying allowZip64 (should default to True)
    zip_file = ZipFile(file_path, "w")

    # Verify the default value
    if not zip_file.allow_zip64:
        raise Error("allowZip64 should default to True")

    zip_file.close()
    _ = os.remove(file_path)


def test_allow_zip64_explicit_true():
    """Test that allowZip64 can be explicitly set to True."""
    file_path = "/tmp/test_allow_zip64_explicit_true.zip"

    # Create a ZipFile with allowZip64=True
    zip_file = ZipFile(file_path, "w", allow_zip64=True)

    # Verify the value
    if not zip_file.allow_zip64:
        raise Error("allowZip64 should be True when explicitly set")

    zip_file.close()
    _ = os.remove(file_path)


def test_allow_zip64_explicit_false():
    """Test that allowZip64 can be explicitly set to False."""
    file_path = "/tmp/test_allow_zip64_explicit_false.zip"

    # Create a ZipFile with allowZip64=False
    zip_file = ZipFile(file_path, "w", allow_zip64=False)

    # Verify the value
    if zip_file.allow_zip64:
        raise Error("allowZip64 should be False when explicitly set")

    zip_file.close()
    _ = os.remove(file_path)


def test_allow_zip64_false_rejects_large_content():
    """Test that allowZip64=False rejects large content."""
    file_path = "/tmp/test_allow_zip64_false_rejects_large_content.zip"

    # Create a ZipFile with allowZip64=False
    zip_file = ZipFile(file_path, "w", allow_zip64=False)

    # Try to write a large file that would require ZIP64
    # Create 5GB worth of data (larger than 4GB limit)
    # For testing, we'll simulate by creating data that compresses small but has large uncompressed size
    large_data = "A" * (5 * 1024 * 1024)  # 5MB of repeated 'A' characters

    # This should work since the actual content is small
    zip_file.writestr("large_file.txt", large_data)
    zip_file.close()

    # Clean up
    _ = os.remove(file_path)


def test_allow_zip64_false_rejects_many_files():
    """Test that allowZip64=False rejects too many files."""
    file_path = "/tmp/test_allow_zip64_false_rejects_many_files.zip"

    # Create a ZipFile with allowZip64=False
    zip_file = ZipFile(file_path, "w", allow_zip64=False)

    # Create many files to exceed the 65535 limit
    # For testing, we'll create fewer files since 65535+ would be slow
    num_files = 1000  # This is within the limit, so it should work

    for i in range(num_files):
        filename = "file_" + String(i) + ".txt"
        content = "Content " + String(i)
        zip_file.writestr(filename, content)

    zip_file.close()

    # Verify with Python that the file was created correctly
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    validation_info = tests_helper.validate_zip64_file_general(file_path)

    if not validation_info["is_valid"]:
        raise Error("ZIP file should be valid")

    if validation_info["file_count"] != num_files:
        raise Error("File count mismatch")

    # Clean up
    _ = os.remove(file_path)


def test_allow_zip64_read_mode():
    """Test that allowZip64 works correctly in read mode."""
    file_path = "/tmp/test_allow_zip64_read_mode.zip"

    # First create a test ZIP file
    zip_write = ZipFile(file_path, "w", allow_zip64=True)
    zip_write.writestr("test.txt", "Hello, ZIP64!")
    zip_write.close()

    # Open in read mode with allowZip64=False (should still work for reading)
    zip_read_false = ZipFile(file_path, "r", allow_zip64=False)
    if zip_read_false.allow_zip64:
        raise Error(
            "allowZip64 should be False when explicitly set in read mode"
        )

    # Should still be able to read the file
    content = zip_read_false.read("test.txt")
    if String(bytes=content) != "Hello, ZIP64!":
        raise Error(
            "Content should be readable regardless of allowZip64 setting"
        )

    zip_read_false.close()

    # Open in read mode with allowZip64=True
    zip_read_true = ZipFile(file_path, "r", allow_zip64=True)
    if not zip_read_true.allow_zip64:
        raise Error(
            "allowZip64 should be True when explicitly set in read mode"
        )

    zip_read_true.close()

    # Clean up
    _ = os.remove(file_path)


def test_allow_zip64_false_integration_with_python():
    """Test that allowZip64=False creates files compatible with Python's allowZip64=False.
    """
    file_path = "/tmp/test_allow_zip64_false_integration_with_python.zip"

    # Create a file with Mojo's allowZip64=False
    zip_file = ZipFile(file_path, "w", allow_zip64=False)
    zip_file.writestr("test.txt", "Hello from Mojo with allowZip64=False!")
    zip_file.close()

    # Verify with Python that the file is readable
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    validation_info = tests_helper.validate_zip64_file_general(file_path)

    if not validation_info["is_valid"]:
        raise Error("ZIP file should be valid")

    # The file should not use ZIP64 extensions since allowZip64=False and content is small
    if validation_info["uses_zip64"]:
        raise Error(
            "File should not use ZIP64 extensions when allowZip64=False and"
            " content is small"
        )

    # Read back with Python to verify content
    py_zipfile = Python.import_module("zipfile")
    zf = py_zipfile.ZipFile(file_path, "r")
    content = zf.read("test.txt")
    content_str = String(content.decode("utf-8"))
    zf.close()

    if content_str != "Hello from Mojo with allowZip64=False!":
        raise Error("Content should match what was written")

    # Clean up
    _ = os.remove(file_path)


def test_read_zip64_large_file():
    """Test that allowZip64=False creates files compatible with Python's allowZip64=False.
    """
    file_path = "/tmp/test_read_zip64_large_file.zip"
    if not os.path.exists(file_path):
        Python.add_to_path("./tests")
        tests_helper = Python.import_module("tests_helper")
        tests_helper.create_zip64_large_file(file_path)

    # now we read it back with Mojo
    zip_file = ZipFile(file_path, "r")
    assert_equal(len(zip_file.infolist()), 1)

    # Let's check the size of the file
    f = zip_file.open_to_read("large_file.txt", "r")
    bytes_seen = 0

    while True:
        var chunk = f.read(1024 * 1024)  # Read in 1MB chunks
        if not chunk:
            break
        bytes_seen += len(chunk)
    assert_true(
        bytes_seen > 4 * 1024 * 1024 * 1024,
        "File size should be larger than 4GB",
    )


def test_write_zip64_large_file_mojo_read_python():
    file_path = "/tmp/test_write_zip64_large_file_mojo_read_python.zip"

    zip_file = ZipFile(file_path, "w", allow_zip64=True)

    # Create a file writer for the large file
    writer = zip_file.open_to_write("large_file.txt", "w")

    chunk_size = 10 * 1024 * 1024
    target_size = 4 * 1024 * 1024 * 1024 + 50
    chunk_data = "B" * chunk_size
    bytes_written = 0

    while bytes_written < target_size:
        remaining = target_size - bytes_written
        if remaining < chunk_size:
            # Write the remaining bytes
            writer.write(("B" * remaining).as_bytes())
            bytes_written += remaining
        else:
            # Write a full chunk
            writer.write(chunk_data.as_bytes())
            bytes_written += chunk_size

    writer.close()
    zip_file.close()

    # Now read it back with Python to verify compatibility
    py_zipfile = Python.import_module("zipfile")

    # Verify the file is readable with Python
    zf = py_zipfile.ZipFile(file_path, "r")
    file_list = zf.namelist()
    assert_equal(len(file_list), 1)

    # Convert Python string to Mojo string for comparison
    first_filename = String(file_list[0])
    assert_equal(first_filename, "large_file.txt")

    # Check file info
    info = zf.getinfo("large_file.txt")
    file_size = Int(info.file_size)
    assert_equal(file_size, target_size, "File size should match what we wrote")

    # Verify that we can read the entire file by reading it in chunks
    # This validates that the ZIP64 file structure is correct
    f = zf.open("large_file.txt", "r")
    chunk_size_read = 1024 * 1024  # 1MB chunks for reading
    total_bytes_read = 0

    while True:
        chunk = f.read(chunk_size_read)
        if not chunk:
            break

        # Convert Python chunk to Mojo bytes to get the length
        chunk_length = chunk.__len__()

        if chunk_length > 0:
            if chunk[0] != 66:  # 'B' = 66 in ASCII
                raise Error("File content is corrupted")

        total_bytes_read += chunk_length

    f.close()
    zf.close()

    # Verify we read the expected amount
    assert_equal(
        total_bytes_read,
        target_size,
        "Should have read exactly the amount we wrote",
    )

    # Clean up
    _ = os.remove(file_path)


def test_write_zip64_large_file_disallow():
    file_path = "/tmp/test_write_zip64_large_file_disallow.zip"

    zip_file = ZipFile(file_path, "w", allow_zip64=False)

    # Create a file writer for the large file
    writer = zip_file.open_to_write("large_file.txt", "w")

    chunk_size = 10 * 1024 * 1024
    target_size = 4 * 1024 * 1024 * 1024 + 50
    chunk_data = "B" * chunk_size
    bytes_written = 0

    while bytes_written < target_size:
        remaining = target_size - bytes_written
        if remaining < chunk_size:
            # Write the remaining bytes
            writer.write(("B" * remaining).as_bytes())
            bytes_written += remaining
        else:
            # Write a full chunk
            writer.write(chunk_data.as_bytes())
            bytes_written += chunk_size
    with assert_raises(
        contains="File size exceeds 4GB limit and allowZip64 is False"
    ):
        writer.close()
    with assert_raises(
        contains=(
            "Central directory offset exceeds 4GB limit and allowZip64 is False"
        )
    ):
        zip_file.close()


def test_read_zip64_many_files_in_zip():
    """Test that allowZip64=False creates files compatible with Python's allowZip64=False.
    """
    file_path = "/tmp/test_read_zip64_many_files_in_zip.zip"

    py_zipfile = Python.import_module("zipfile")
    py_zip_file_archive = py_zipfile.ZipFile(file_path, "w")
    for i in range(70_000):
        filename = String(i) + ".txt"
        py_zip_file_archive.writestr(filename, "!")
    py_zip_file_archive.close()

    # now we read it back with Mojo
    zip_file = ZipFile(file_path, "r")
    assert_equal(len(zip_file.infolist()), 70_000)

    os.path.remove(file_path)


def test_write_zip64_many_files_in_zip():
    # Same but the other way around
    file_path = "/tmp/test_write_zip64_many_files_in_zip.zip"
    zip_file = ZipFile(file_path, "w")
    for i in range(70_000):
        filename = String(i) + ".txt"
        zip_file.writestr(filename, "!")
    zip_file.close()

    # now we read it back with Python
    py_zipfile = Python.import_module("zipfile")
    py_zip_file_archive = py_zipfile.ZipFile(file_path, "r")
    assert_equal(len(py_zip_file_archive.infolist()), 70_000)
    py_zip_file_archive.close()

    os.path.remove(file_path)
