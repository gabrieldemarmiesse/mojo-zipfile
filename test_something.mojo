import zipfile
from testing import assert_equal, assert_true
from python import Python
from pathlib import Path


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
    assert_true(
        zipfile.is_zipfile(String(tmp_zipfile_path)),
        "File should be a zip file",
    )
    tmp_dir.cleanup()


def test_identical_analysis():
    Python.add_to_path("./")
    tests_helper = Python.import_module("tests_helper")
    file_path = "/tmp/test.zip"
    tests_helper.create_complicated_zip(file_path)

    open_zip_mojo = zipfile.ZipFile(file_path, "r")

    assert_equal(
        open_zip_mojo.end_of_central_directory().number_of_this_disk, 0
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory().number_of_the_disk_with_the_start_of_the_central_directory,
        0,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory().total_number_of_entries_in_the_central_directory_on_this_disk,
        4,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory().total_number_of_entries_in_the_central_directory,
        4,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory().size_of_the_central_directory,
        222,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory().offset_of_starting_disk_number,
        187,
    )
    assert_equal(
        len(open_zip_mojo.end_of_central_directory().zip_file_comment), 0
    )
    infolist = open_zip_mojo.infolist()

    assert_equal(len(infolist), 4)
    assert_equal(infolist[0].filename, "hello.txt")
    assert_equal(infolist[1].filename, "foo/bar.txt")
    assert_equal(infolist[2].filename, "foo/baz.txt")
    assert_equal(infolist[3].filename, "qux.txt")

    open_zip_mojo.close()


def test_read_content():
    Python.add_to_path("./")
    tests_helper = Python.import_module("tests_helper")
    file_path = "/tmp/dodo.zip"
    tests_helper.create_hello_world_zip(file_path)

    open_zip_mojo = zipfile.ZipFile(file_path, "r")
    assert_equal(len(open_zip_mojo.infolist()), 1)
    hello_file = open_zip_mojo.open("hello.txt", "r")
    content = hello_file.read()
    assert_equal(String(bytes=content), "hello world!")

    hello_file = open_zip_mojo.open("hello.txt", "r")
    content = hello_file.read(5)
    assert_equal(String(bytes=content), "hello")
    content = hello_file.read(5)
    assert_equal(String(bytes=content), " worl")
    content = hello_file.read(5)
    assert_equal(String(bytes=content), "d!")
    content = hello_file.read(5)
    assert_equal(String(bytes=content), "")
    open_zip_mojo.close()


def test_write_empty_zip():
    file_path = "/tmp/empty.zip"
    other = "/tmp/empty2.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    open_zip_mojo.close()

    Python.add_to_path("./")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.create_empty_zip(other)

    bytes_mojo = Path(file_path).read_bytes()
    bytes_python = Path(other).read_bytes()
    assert_equal(bytes_mojo, bytes_python)


def main():
    test_is_zipfile_valid()
    test_identical_analysis()
    test_read_content()
    test_write_empty_zip()
    print("All tests passed!")
