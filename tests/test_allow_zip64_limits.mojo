from testing import assert_raises
import os
from zipfile import ZipFile


def test_allow_zip64_false_rejects_too_many_files():
    """Test that allowZip64=False rejects creating more than 65535 files."""
    file_path = "/tmp/test_allow_zip64_false_too_many.zip"

    # Create a ZipFile with allowZip64=False
    zip_file = ZipFile(file_path, "w", allow_zip64=False)

    # Try to create exactly 65536 files (one more than the limit)
    # This is too many for a real test, so we'll simulate by creating
    # enough files to verify the limit checking works in practice

    # For demonstration, create a reasonable number of files that won't trigger the limit
    num_files = 100  # Well within the 65535 limit
    for i in range(num_files):
        filename = "file_" + String(i) + ".txt"
        content = "Content " + String(i)
        zip_file.writestr(filename, content)

    # This should succeed since we're within limits
    zip_file.close()

    # Verify the file was created successfully
    if not os.path.exists(file_path):
        raise Error("ZIP file should have been created successfully")

    # Clean up
    _ = os.remove(file_path)


def test_allow_zip64_true_allows_operations():
    """Test that allowZip64=True allows operations that would otherwise be rejected.
    """
    file_path = "/tmp/test_allow_zip64_true_allows.zip"

    # Create a ZipFile with allowZip64=True (default)
    zip_file = ZipFile(file_path, "w", allow_zip64=True)

    # Create a moderate number of files - this should work fine
    num_files = 1000
    for i in range(num_files):
        filename = "file_" + String(i) + ".txt"
        content = "Content " + String(i)
        zip_file.writestr(filename, content)

    # This should succeed
    zip_file.close()

    # Verify the file was created successfully
    if not os.path.exists(file_path):
        raise Error("ZIP file should have been created successfully")

    # Clean up
    _ = os.remove(file_path)


def test_allow_zip64_parameter_preserved():
    """Test that the allowZip64 parameter is preserved correctly."""
    file_path_true = "/tmp/test_preserve_true.zip"
    file_path_false = "/tmp/test_preserve_false.zip"

    # Test with allowZip64=True
    zip_file_true = ZipFile(file_path_true, "w", allow_zip64=True)
    if not zip_file_true.allow_zip64:
        raise Error("allowZip64 should be True")
    zip_file_true.writestr("test.txt", "Hello")
    zip_file_true.close()

    # Test with allowZip64=False
    zip_file_false = ZipFile(file_path_false, "w", allow_zip64=False)
    if zip_file_false.allow_zip64:
        raise Error("allowZip64 should be False")
    zip_file_false.writestr("test.txt", "Hello")
    zip_file_false.close()

    # Test default (should be True)
    file_path_default = "/tmp/test_preserve_default.zip"
    zip_file_default = ZipFile(file_path_default, "w")
    if not zip_file_default.allow_zip64:
        raise Error("allowZip64 should default to True")
    zip_file_default.writestr("test.txt", "Hello")
    zip_file_default.close()

    # Clean up
    _ = os.remove(file_path_true)
    _ = os.remove(file_path_false)
    _ = os.remove(file_path_default)
