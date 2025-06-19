"""Writing functionality tests for zipfile module."""

import zipfile
from testing import assert_equal, assert_true, assert_raises
from python import Python
from pathlib import Path


def test_write_empty_zip():
    file_path = "/tmp/empty55.zip"
    other = "/tmp/empty882.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    open_zip_mojo.close()

    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.create_empty_zip(other)

    bytes_mojo = Path(file_path).read_bytes()
    bytes_python = Path(other).read_bytes()
    assert_equal(bytes_mojo, bytes_python)


def test_write_simple_hello_world():
    file_path = "/tmp/hello777.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    open_zip_mojo.writestr("hello.txt", "hello world!")
    open_zip_mojo.close()

    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.verify_hello_world_zip(file_path)


def test_write_simple_hello_world_progressive_with_close():
    file_path = "/tmp/hello888.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    zip_entry = open_zip_mojo.open_to_write("hello.txt", "w")
    zip_entry.write(String("hello").as_bytes())
    zip_entry.write(String(" wo").as_bytes())
    zip_entry.write(String("rld!").as_bytes())
    zip_entry.close()
    open_zip_mojo.close()

    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.verify_hello_world_zip(file_path)


def test_write_simple_hello_world_progressive_without_close():
    file_path = "/tmp/hello9999.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    zip_entry = open_zip_mojo.open_to_write("hello.txt", "w")
    zip_entry.write(String("hello").as_bytes())
    zip_entry.write(String(" wo").as_bytes())
    zip_entry.write(String("rld!").as_bytes())
    # We rely on the asap destructor to close the file
    open_zip_mojo.close()

    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.verify_hello_world_zip(file_path)
