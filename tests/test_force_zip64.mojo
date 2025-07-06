from testing import assert_raises
import os
from zipfile import ZipFile
from python import Python


def test_force_zip64_default_false():
    """Test that force_zip64 defaults to False."""
    file_path = "/tmp/test_force_zip64_default.zip"

    # Create a ZipFile and open a file for writing without specifying force_zip64
    zip_file = ZipFile(file_path, "w", allowZip64=True)
    file_writer = zip_file.open_to_write("test.txt", "w")

    # Check the default value
    if file_writer._force_zip64:
        raise Error("force_zip64 should default to False")

    file_writer.write("Hello, World!".as_bytes())
    file_writer.close()
    zip_file.close()
    _ = os.remove(file_path)


def test_force_zip64_explicit_true():
    """Test that force_zip64 can be explicitly set to True."""
    file_path = "/tmp/test_force_zip64_true.zip"

    # Create a ZipFile and open a file for writing with force_zip64=True
    zip_file = ZipFile(file_path, "w", allowZip64=True)
    file_writer = zip_file.open_to_write("test.txt", "w", force_zip64=True)

    # Check the value
    if not file_writer._force_zip64:
        raise Error("force_zip64 should be True when explicitly set")

    file_writer.write("Hello, World!".as_bytes())
    file_writer.close()
    zip_file.close()
    _ = os.remove(file_path)


def test_force_zip64_explicit_false():
    """Test that force_zip64 can be explicitly set to False."""
    file_path = "/tmp/test_force_zip64_false.zip"

    # Create a ZipFile and open a file for writing with force_zip64=False
    zip_file = ZipFile(file_path, "w", allowZip64=True)
    file_writer = zip_file.open_to_write("test.txt", "w", force_zip64=False)

    # Check the value
    if file_writer._force_zip64:
        raise Error("force_zip64 should be False when explicitly set")

    file_writer.write("Hello, World!".as_bytes())
    file_writer.close()
    zip_file.close()
    _ = os.remove(file_path)


def test_force_zip64_true_with_allowZip64_false_fails():
    """Test that force_zip64=True with allowZip64=False raises an error."""
    file_path = "/tmp/test_force_zip64_conflict.zip"

    # Create a ZipFile with allowZip64=False
    zip_file = ZipFile(file_path, "w", allowZip64=False)

    # Try to open a file with force_zip64=True - this should fail when closing
    file_writer = zip_file.open_to_write("test.txt", "w", force_zip64=True)
    file_writer.write("Hello, World!".as_bytes())

    # The error should occur when closing the file writer
    with assert_raises(contains="force_zip64=True but allowZip64 is False"):
        file_writer.close()

    # Clean up
    zip_file.close()
    _ = os.remove(file_path)


def test_force_zip64_with_small_file():
    """Test that force_zip64=True works with small files."""
    file_path = "/tmp/test_force_zip64_small.zip"

    # Create a ZipFile with allowZip64=True
    zip_file = ZipFile(file_path, "w", allowZip64=True)

    # Open a file with force_zip64=True and write small content
    file_writer = zip_file.open_to_write("small.txt", "w", force_zip64=True)
    small_content = "This is a small file that doesn't normally need ZIP64."
    file_writer.write(small_content.as_bytes())
    file_writer.close()
    zip_file.close()

    # Verify the file was created and can be read back
    zip_read = ZipFile(file_path, "r")
    content = zip_read.read("small.txt")
    if String(bytes=content) != small_content:
        raise Error("Content should match what was written")
    zip_read.close()

    # Verify with Python that the file is valid
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    validation_info = tests_helper.validate_zip64_file_general(file_path)

    if not validation_info["is_valid"]:
        raise Error("ZIP file should be valid")

    # Clean up
    _ = os.remove(file_path)


def test_force_zip64_with_compression():
    """Test that force_zip64=True works with different compression methods."""
    file_path = "/tmp/test_force_zip64_compression.zip"

    # Test with ZIP_DEFLATED compression
    from zipfile import ZIP_DEFLATED

    zip_file = ZipFile(file_path, "w", ZIP_DEFLATED, allowZip64=True)

    # Open a file with force_zip64=True and DEFLATED compression
    file_writer = zip_file.open_to_write(
        "compressed.txt", "w", force_zip64=True
    )
    content = "This is compressed data. " * 100  # Make it compressible
    file_writer.write(content.as_bytes())
    file_writer.close()
    zip_file.close()

    # Verify the file was created and can be read back
    zip_read = ZipFile(file_path, "r")
    read_content = zip_read.read("compressed.txt")
    if String(bytes=read_content) != content:
        raise Error("Content should match what was written")
    zip_read.close()

    # Clean up
    _ = os.remove(file_path)
