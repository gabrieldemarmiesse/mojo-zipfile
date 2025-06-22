import zipfile
from testing import assert_equal, assert_true, assert_raises
from python import Python
from pathlib import Path


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


def test_write_simple_hello_world_deflate():
    file_path = "/tmp/hello_deflate_mojo.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    open_zip_mojo.writestr("hello.txt", "hello world!", zipfile.ZIP_DEFLATED)
    open_zip_mojo.close()

    # Verify using Python zipfile
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.verify_hello_world_zip(file_path)

    # Also verify we can read it back with Mojo
    open_zip_mojo_read = zipfile.ZipFile(file_path, "r")
    assert_equal(len(open_zip_mojo_read.infolist()), 1)
    hello_file = open_zip_mojo_read.open_to_read("hello.txt", "r")
    content = hello_file.read()
    assert_equal(String(bytes=content), "hello world!")
    open_zip_mojo_read.close()


def test_write_simple_hello_world_deflate_progressive():
    file_path = "/tmp/hello_deflate_progressive_mojo.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    zip_entry = open_zip_mojo.open_to_write(
        "hello.txt", "w", zipfile.ZIP_DEFLATED
    )
    zip_entry.write(String("hello").as_bytes())
    zip_entry.write(String(" wo").as_bytes())
    zip_entry.write(String("rld!").as_bytes())
    zip_entry.close()
    open_zip_mojo.close()

    # Verify using Python zipfile
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.verify_hello_world_zip(file_path)

    # Also verify we can read it back with Mojo
    open_zip_mojo_read = zipfile.ZipFile(file_path, "r")
    assert_equal(len(open_zip_mojo_read.infolist()), 1)
    hello_file = open_zip_mojo_read.open_to_read("hello.txt", "r")
    content = hello_file.read()
    assert_equal(String(bytes=content), "hello world!")
    open_zip_mojo_read.close()


def test_compression_level_progressive_write():
    # Test compression levels with progressive writing
    test_data_parts = List[String]("Part1_", "Part2_", "Part3_")

    file_path_level1 = "/tmp/progressive_level1.zip"
    file_path_level9 = "/tmp/progressive_level9.zip"

    # Create with level 1 (fast compression)
    zip_file1 = zipfile.ZipFile(file_path_level1, "w")
    zip_entry1 = zip_file1.open_to_write(
        "progressive.txt", "w", zipfile.ZIP_DEFLATED, compresslevel=1
    )
    for i in range(len(test_data_parts)):
        zip_entry1.write(
            (test_data_parts[i] * 50).as_bytes()
        )  # Make it repetitive
    zip_entry1.close()
    zip_file1.close()

    # Create with level 9 (best compression)
    zip_file9 = zipfile.ZipFile(file_path_level9, "w")
    zip_entry9 = zip_file9.open_to_write(
        "progressive.txt", "w", zipfile.ZIP_DEFLATED, compresslevel=9
    )
    for i in range(len(test_data_parts)):
        zip_entry9.write((test_data_parts[i] * 50).as_bytes())
    zip_entry9.close()
    zip_file9.close()

    # Verify both can be read correctly
    expected_content = (
        (test_data_parts[0] * 50)
        + (test_data_parts[1] * 50)
        + (test_data_parts[2] * 50)
    )

    zip_read1 = zipfile.ZipFile(file_path_level1, "r")
    file_reader1 = zip_read1.open_to_read("progressive.txt", "r")
    content1 = file_reader1.read()
    assert_equal(String(bytes=content1), expected_content)
    zip_read1.close()

    zip_read9 = zipfile.ZipFile(file_path_level9, "r")
    file_reader9 = zip_read9.open_to_read("progressive.txt", "r")
    content9 = file_reader9.read()
    assert_equal(String(bytes=content9), expected_content)
    zip_read9.close()

    # Check that Python can also read our files
    Python.add_to_path("./tests")
    py_zipfile = Python.import_module("zipfile")

    # Verify with Python's zipfile
    py_zip1 = py_zipfile.ZipFile(file_path_level1, "r")
    py_content1 = py_zip1.read("progressive.txt")
    py_zip1.close()
    assert_equal(String(py_content1.decode("utf-8")), expected_content)

    py_zip9 = py_zipfile.ZipFile(file_path_level9, "r")
    py_content9 = py_zip9.read("progressive.txt")
    py_zip9.close()
    assert_equal(String(py_content9.decode("utf-8")), expected_content)


def test_compression_level_constants():
    # Test using the exported compression level constants
    test_data = "Constant test data! " * 100

    # Test with Z_BEST_SPEED
    file_path_speed = "/tmp/test_best_speed.zip"
    zip_speed = zipfile.ZipFile(file_path_speed, "w")
    zip_speed.writestr(
        "test.txt",
        test_data,
        zipfile.ZIP_DEFLATED,
        compresslevel=zlib.Z_BEST_SPEED,
    )
    zip_speed.close()

    # Test with Z_BEST_COMPRESSION
    file_path_compression = "/tmp/test_best_compression.zip"
    zip_compression = zipfile.ZipFile(file_path_compression, "w")
    zip_compression.writestr(
        "test.txt",
        test_data,
        zipfile.ZIP_DEFLATED,
        compresslevel=zlib.Z_BEST_COMPRESSION,
    )
    zip_compression.close()

    # Test with Z_DEFAULT_COMPRESSION
    file_path_default = "/tmp/test_default_compression.zip"
    zip_default = zipfile.ZipFile(file_path_default, "w")
    zip_default.writestr(
        "test.txt",
        test_data,
        zipfile.ZIP_DEFLATED,
        compresslevel=zlib.Z_DEFAULT_COMPRESSION,
    )
    zip_default.close()

    # Verify all files can be read correctly
    for file_path in [
        file_path_speed,
        file_path_compression,
        file_path_default,
    ]:
        zip_read = zipfile.ZipFile(file_path, "r")
        file_reader = zip_read.open_to_read("test.txt", "r")
        content = file_reader.read()
        assert_equal(String(bytes=content), test_data)
        zip_read.close()
