from testing import assert_true, assert_equal, assert_raises
from python import Python
from zipfile import ZipFile, ZipInfo, ZIP_STORED
from pathlib import Path
import tempfile
import os


fn test_mkdir_basic_directory() raises:
    """Test creating a basic directory with mkdir using string."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_mkdir.zip"

    # Create a directory in the zip file
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.mkdir("test_dir")
    zip_file.close()

    # Verify the directory was created correctly
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    var namelist = zip_file2.namelist()
    assert_equal(len(namelist), 1)
    assert_equal(namelist[0], "test_dir/")

    # Verify it's recognized as a directory
    var info = zip_file2.getinfo("test_dir/")
    assert_true(info.is_dir())
    zip_file2.close()

    # Clean up
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_mkdir_with_zipinfo() raises:
    """Test creating a directory with mkdir using ZipInfo object."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_mkdir_zipinfo.zip"

    # Create a ZipInfo object for a directory
    var zinfo = ZipInfo._create_directory("custom_dir/", 0o755)

    # Create a directory using the ZipInfo object
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.mkdir(zinfo)
    zip_file.close()

    # Verify the directory was created correctly
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    var namelist = zip_file2.namelist()
    assert_equal(len(namelist), 1)
    assert_equal(namelist[0], "custom_dir/")

    # Verify it's recognized as a directory
    var info = zip_file2.getinfo("custom_dir/")
    assert_true(info.is_dir())
    zip_file2.close()

    # Clean up
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_mkdir_readonly_archive() raises:
    """Test that mkdir raises error on read-only archive."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_readonly.zip"

    # Create an empty zip file first
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.close()

    # Open in read mode and try to mkdir
    var zip_file_read = ZipFile(zip_path.__str__(), "r")
    with assert_raises(contains="mkdir() requires mode 'w'"):
        zip_file_read.mkdir("test_dir")
    zip_file_read.close()

    # Clean up
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_mkdir_multiple_directories() raises:
    """Test creating multiple directories in the same archive."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_multiple.zip"

    # Create multiple directories
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.mkdir("dir1")
    zip_file.mkdir("dir2/")
    zip_file.mkdir("dir3")
    zip_file.close()

    # Verify all directories were created
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    var namelist = zip_file2.namelist()
    assert_equal(len(namelist), 3)

    # All should end with '/'
    assert_true("dir1/" in namelist)
    assert_true("dir2/" in namelist)
    assert_true("dir3/" in namelist)

    # Verify all are recognized as directories
    assert_true(zip_file2.getinfo("dir1/").is_dir())
    assert_true(zip_file2.getinfo("dir2/").is_dir())
    assert_true(zip_file2.getinfo("dir3/").is_dir())
    zip_file2.close()

    # Clean up
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn test_mkdir_nested_directories() raises:
    """Test creating nested directory structures."""
    var temp_dir = tempfile.mkdtemp()
    var zip_path = Path(temp_dir) / "test_nested.zip"

    # Create nested directories
    var zip_file = ZipFile(zip_path.__str__(), "w")
    zip_file.mkdir("parent/")
    zip_file.mkdir("parent/child/")
    zip_file.mkdir("parent/child/grandchild/")
    zip_file.close()

    # Verify all directories were created
    var zip_file2 = ZipFile(zip_path.__str__(), "r")
    var namelist = zip_file2.namelist()
    assert_equal(len(namelist), 3)

    # Check all directories exist
    assert_true("parent/" in namelist)
    assert_true("parent/child/" in namelist)
    assert_true("parent/child/grandchild/" in namelist)

    # Verify all are recognized as directories
    assert_true(zip_file2.getinfo("parent/").is_dir())
    assert_true(zip_file2.getinfo("parent/child/").is_dir())
    assert_true(zip_file2.getinfo("parent/child/grandchild/").is_dir())
    zip_file2.close()

    # Clean up
    os.remove(zip_path.__str__())
    os.rmdir(temp_dir)


fn main() raises:
    test_mkdir_basic_directory()
    test_mkdir_with_zipinfo()
    test_mkdir_readonly_archive()
    test_mkdir_multiple_directories()
    test_mkdir_nested_directories()
