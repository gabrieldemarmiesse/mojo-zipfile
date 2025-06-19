"""Basic functionality tests for zipfile module."""

import zipfile
from testing import assert_equal, assert_true, assert_raises
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
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    file_path = "/tmp/test8.zip"
    tests_helper.create_complicated_zip(file_path)

    open_zip_mojo = zipfile.ZipFile(file_path, "r")

    assert_equal(open_zip_mojo.end_of_central_directory.number_of_this_disk, 0)
    assert_equal(
        open_zip_mojo.end_of_central_directory.number_of_the_disk_with_the_start_of_the_central_directory,
        0,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk,
        4,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.total_number_of_entries_in_the_central_directory,
        4,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.size_of_the_central_directory,
        222,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.offset_of_starting_disk_number,
        187,
    )
    assert_equal(
        len(open_zip_mojo.end_of_central_directory.zip_file_comment), 0
    )
    infolist = open_zip_mojo.infolist()

    assert_equal(len(infolist), 4)
    assert_equal(infolist[0].filename, "hello.txt")
    assert_equal(infolist[1].filename, "foo/bar.txt")
    assert_equal(infolist[2].filename, "foo/baz.txt")
    assert_equal(infolist[3].filename, "qux.txt")
    # check crc computation
    for zipinfo in infolist:
        file_like = open_zip_mojo.open(zipinfo, "r")
        content = file_like.read()

    open_zip_mojo.close()


def test_read_content():
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    file_path = "/tmp/dodo24.zip"
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


def test_read_method():
    # Test the read() method which should work like Python's zipfile.read()
    test_data = "Hello, this is test data for the read() method!"
    file_path = "/tmp/test_read_method.zip"

    # Create a zip file with some test data, both stored and deflated
    zip_write = zipfile.ZipFile(file_path, "w")
    zip_write.writestr("test1.txt", test_data)  # ZIP_STORED
    zip_write.writestr(
        "test2.txt", "Different content", zipfile.ZIP_DEFLATED, compresslevel=6
    )  # ZIP_DEFLATED
    zip_write.close()

    # Test reading the files using the read() method
    zip_read = zipfile.ZipFile(file_path, "r")

    # Read first file (stored)
    content1 = zip_read.read("test1.txt")
    assert_equal(String(bytes=content1), test_data)

    # Read second file (deflated)
    content2 = zip_read.read("test2.txt")
    assert_equal(String(bytes=content2), "Different content")

    # Read first file again to test if multiple reads work
    content1_again = zip_read.read("test1.txt")
    assert_equal(String(bytes=content1_again), test_data)

    # Test error case for non-existent file
    with assert_raises(contains="File nonexistent.txt not found in zip file"):
        _ = zip_read.read("nonexistent.txt")

    zip_read.close()

    # Verify compatibility with Python's zipfile
    Python.add_to_path("./tests")
    py_zipfile = Python.import_module("zipfile")
    py_zip = py_zipfile.ZipFile(file_path, "r")
    py_content1 = py_zip.read("test1.txt")
    py_content2 = py_zip.read("test2.txt")
    py_zip.close()

    # Compare results with Python
    assert_equal(String(py_content1.decode("utf-8")), test_data)
    assert_equal(String(py_content2.decode("utf-8")), "Different content")
