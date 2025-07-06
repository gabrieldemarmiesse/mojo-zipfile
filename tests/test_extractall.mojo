from testing import assert_true, assert_equal, assert_raises
from python import Python
from zipfile import ZipFile, ZipInfo, ZIP_STORED
from pathlib import Path
import tempfile
import os


fn test_extractall_to_custom_path() raises:
    """Test extracting all files to a custom directory."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_extractall.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create a zip file with multiple files
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.writestr("file1.txt", "Content of file 1")
    zip_file.writestr("file2.txt", "Content of file 2")
    zip_file.mkdir("folder/")
    zip_file.writestr("folder/file3.txt", "Content of file 3")
    zip_file.close()

    # Extract all files
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    zip_file2.extractall(extract_dir.__str__())
    zip_file2.close()

    # Verify all files were extracted
    assert_true((extract_dir / "file1.txt").exists())
    assert_true((extract_dir / "file2.txt").exists())
    assert_true((extract_dir / "folder/").is_dir())
    assert_true((extract_dir / "folder/file3.txt").exists())

    # Verify content
    assert_equal((extract_dir / "file1.txt").read_text(), "Content of file 1")
    assert_equal((extract_dir / "file2.txt").read_text(), "Content of file 2")
    assert_equal(
        (extract_dir / "folder/file3.txt").read_text(), "Content of file 3"
    )

    # Clean up
    os.remove((extract_dir / "file1.txt").__str__())
    os.remove((extract_dir / "file2.txt").__str__())
    os.remove((extract_dir / "folder/file3.txt").__str__())
    os.rmdir((extract_dir / "folder/").__str__())
    os.rmdir(extract_dir.__str__())
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_extractall_with_members_list() raises:
    """Test extracting only specific members using string list."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_members.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create a zip file with multiple files
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.writestr("file1.txt", "Content of file 1")
    zip_file.writestr("file2.txt", "Content of file 2")
    zip_file.writestr("file3.txt", "Content of file 3")
    zip_file.close()

    # Extract only specific files
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    var members_to_extract = List[String]()
    members_to_extract.append("file1.txt")
    members_to_extract.append("file3.txt")
    zip_file2.extractall(extract_dir.__str__(), members_to_extract)
    zip_file2.close()

    # Verify only specified files were extracted
    assert_true((extract_dir / "file1.txt").exists())
    assert_true(
        not (extract_dir / "file2.txt").exists()
    )  # Should not be extracted
    assert_true((extract_dir / "file3.txt").exists())

    # Verify content
    assert_equal((extract_dir / "file1.txt").read_text(), "Content of file 1")
    assert_equal((extract_dir / "file3.txt").read_text(), "Content of file 3")

    # Clean up
    os.remove((extract_dir / "file1.txt").__str__())
    os.remove((extract_dir / "file3.txt").__str__())
    os.rmdir(extract_dir.__str__())
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_extractall_empty_archive() raises:
    """Test extractall on an empty archive."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_empty.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create an empty zip file
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.close()

    # Extract from empty archive (should not fail)
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    zip_file2.extractall(extract_dir.__str__())
    zip_file2.close()

    # Extract directory should be created but empty
    assert_true(extract_dir.is_dir())

    # Clean up
    os.rmdir(extract_dir.__str__())
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_extractall_write_mode() raises:
    """Test that extractall raises error when archive is in write mode."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_write_mode.zip"

    # Open archive in write mode and try to extractall
    var zip_file = ZipFile(zip_path.__str__(), "w")
    with assert_raises(contains="extractall() requires mode 'r'"):
        zip_file.extractall()
    zip_file.close()

    # Clean up
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_extractall_with_zipinfo_objects() raises:
    """Test extracting specific members using ZipInfo objects."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_zipinfo_members.zip"
    var extract_dir = Path(temp_dir) / "extract"

    # Create a zip file with multiple files
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.writestr("file1.txt", "Content of file 1")
    zip_file.writestr("file2.txt", "Content of file 2")
    zip_file.mkdir("folder/")
    zip_file.writestr("folder/file3.txt", "Content of file 3")
    zip_file.close()

    # Get specific ZipInfo objects and extract them
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    var members_to_extract = List[ZipInfo]()
    members_to_extract.append(zip_file2.getinfo("file1.txt"))
    members_to_extract.append(zip_file2.getinfo("folder/"))
    members_to_extract.append(zip_file2.getinfo("folder/file3.txt"))
    zip_file2.extractall(extract_dir.__str__(), members_to_extract)
    zip_file2.close()

    # Verify only specified files were extracted
    assert_true((extract_dir / "file1.txt").exists())
    assert_true(
        not (extract_dir / "file2.txt").exists()
    )  # Should not be extracted
    assert_true((extract_dir / "folder/").is_dir())
    assert_true((extract_dir / "folder/file3.txt").exists())

    # Verify content
    assert_equal((extract_dir / "file1.txt").read_text(), "Content of file 1")
    assert_equal(
        (extract_dir / "folder/file3.txt").read_text(), "Content of file 3"
    )

    # Clean up
    os.remove((extract_dir / "file1.txt").__str__())
    os.remove((extract_dir / "folder/file3.txt").__str__())
    os.rmdir((extract_dir / "folder/").__str__())
    os.rmdir(extract_dir.__str__())
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn main() raises:
    test_extractall_to_custom_path()
    test_extractall_with_members_list()
    test_extractall_empty_archive()
    test_extractall_write_mode()
    test_extractall_with_zipinfo_objects()
