from testing import assert_true, assert_equal, assert_raises
from python import Python
from zipfile import ZipFile, ZipInfo, ZIP_STORED
from pathlib import Path
import tempfile
import os


fn test_extract_basic_file() raises:
    """Test extracting a basic file from a ZIP archive."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_extract.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create a zip file with a simple text file
    var zip_file = ZipFile(zip_path, "w")
    zip_file.writestr("hello.txt", "Hello, World!")
    zip_file.close()

    # Extract the file
    var zip_file2 = ZipFile(zip_path, "r")
    var extracted_path = zip_file2.extract("hello.txt", String(extract_dir))
    zip_file2.close()

    # Verify the file was extracted correctly
    var expected_path = extract_dir / "hello.txt"
    assert_equal(extracted_path, String(expected_path))
    assert_true(Path(extracted_path).exists())

    # Verify the content
    var content = Path(extracted_path).read_text()
    assert_equal(content, "Hello, World!")

    # Clean up
    os.remove(extracted_path)
    os.rmdir(extract_dir)
    os.remove(zip_path)
    os.rmdir(temp_dir)


fn test_extract_directory() raises:
    """Test extracting a directory from a ZIP archive."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_extract_dir.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create a zip file with a directory
    var zip_file = ZipFile(zip_path, "w")
    zip_file.mkdir("test_folder")
    zip_file.close()

    # Extract the directory
    var zip_file2 = ZipFile(zip_path, "r")
    var extracted_path = zip_file2.extract(
        "test_folder/", String(extract_dir)
    )
    zip_file2.close()

    # Verify the directory was extracted correctly
    var expected_path = extract_dir / "test_folder/"
    assert_equal(extracted_path, String(expected_path))
    assert_true(Path(extracted_path).is_dir())

    # Clean up
    os.rmdir(extracted_path)
    os.rmdir(extract_dir)
    os.remove(zip_path)
    os.rmdir(temp_dir)


fn test_extract_nonexistent_file() raises:
    """Test extracting a non-existent file raises error."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_nonexistent.zip"

    # Create an empty zip file
    var zip_file = ZipFile(zip_path, "w")
    zip_file.close()

    # Try to extract a non-existent file
    var zip_file2 = ZipFile(zip_path, "r")
    with assert_raises(contains="not found in zip file"):
        _ = zip_file2.extract("nonexistent.txt")
    zip_file2.close()

    # Clean up
    os.remove(zip_path)
    os.rmdir(temp_dir)


fn test_extract_from_write_mode() raises:
    """Test that extract raises error when archive is in write mode."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_write_mode.zip"

    # Open archive in write mode and try to extract
    var zip_file = ZipFile(zip_path, "w")
    with assert_raises(contains="extract() requires mode 'r'"):
        _ = zip_file.extract("any_file.txt")
    zip_file.close()

    # Clean up
    os.remove(zip_path)
    os.rmdir(temp_dir)


fn test_extract_nested_file() raises:
    """Test extracting a file from a nested directory structure."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_nested.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create a zip file with nested directory structure
    var zip_file = ZipFile(zip_path, "w")
    zip_file.mkdir("parent/")
    zip_file.mkdir("parent/child/")
    zip_file.writestr("parent/child/nested.txt", "Nested file content!")
    zip_file.close()

    # Extract the nested file
    var zip_file2 = ZipFile(zip_path, "r")
    var extracted_path = zip_file2.extract(
        "parent/child/nested.txt", String(extract_dir)
    )
    zip_file2.close()

    # Verify the file was extracted with proper directory structure
    var expected_path = extract_dir / "parent/child/nested.txt"
    assert_equal(extracted_path, String(expected_path))
    assert_true(Path(extracted_path).exists())

    # Verify the content
    var content = Path(extracted_path).read_text()
    assert_equal(content, "Nested file content!")

    # Verify parent directories were created
    assert_true((extract_dir / "parent").is_dir())
    assert_true((extract_dir / "parent/child").is_dir())

    # Clean up
    os.remove(extracted_path)
    os.rmdir((extract_dir / "parent/child"))
    os.rmdir((extract_dir / "parent"))
    os.rmdir(extract_dir)
    os.remove(zip_path)
    os.rmdir(temp_dir)


fn test_extract_with_zipinfo() raises:
    """Test extracting using ZipInfo object instead of string."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_zipinfo.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create a zip file with a simple text file
    var zip_file = ZipFile(zip_path, "w")
    zip_file.writestr("zipinfo_test.txt", "ZipInfo extraction test!")
    zip_file.close()

    # Get ZipInfo and extract using it
    var zip_file2 = ZipFile(zip_path, "r")
    var info = zip_file2.getinfo("zipinfo_test.txt")
    var extracted_path = zip_file2.extract(info, String(extract_dir))
    zip_file2.close()

    # Verify the file was extracted correctly
    var expected_path = extract_dir / "zipinfo_test.txt"
    assert_equal(extracted_path, String(expected_path))
    assert_true(Path(extracted_path).exists())

    # Verify the content
    var content = Path(extracted_path).read_text()
    assert_equal(content, "ZipInfo extraction test!")

    # Clean up
    os.remove(extracted_path)
    os.rmdir(extract_dir)
    os.remove(zip_path)
    os.rmdir(temp_dir)


fn main() raises:
    test_extract_basic_file()
    test_extract_directory()
    test_extract_nonexistent_file()
    test_extract_from_write_mode()
    test_extract_nested_file()
    test_extract_with_zipinfo()
