import zipfile
from testing import assert_equal, assert_true
from python import Python


def test_is_zipfile_valid():
    py_zipfile = Python.import_module("zipfile")
    py_tempfile = Python.import_module("tempfile")
    # Create a temporary zip file
    tmp_dir = py_tempfile.TemporaryDirectory()
    tmp_zipfile_path = tmp_dir.name + "/test.zip"
    open_zip = py_zipfile.ZipFile(tmp_zipfile_path, "w")
    open_zip.writestr("test.txt", "This is a test file.")
    open_zip.close()
    # Check if the created file is a zip file
    assert_true(zipfile.is_zipfile(String(tmp_zipfile_path)), "File should be a zip file")
    tmp_dir.cleanup()


def main():
    test_is_zipfile_valid()
    print("All tests passed!")