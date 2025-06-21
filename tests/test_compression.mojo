"""Compression functionality tests for zipfile module."""

import zipfile
from testing import assert_equal, assert_true, assert_raises
from python import Python
from pathlib import Path
from zipfile import zlib


def test_read_simple_hello_world_deflate():
    file_path = "/tmp/hello7276.zip"
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.create_hello_world_zip_with_deflate(file_path)

    open_zip_mojo = zipfile.ZipFile(file_path, "r")
    assert_equal(len(open_zip_mojo.infolist()), 1)
    hello_file = open_zip_mojo.open("hello.txt", "r")
    content = hello_file.read()
    assert_equal(String(bytes=content), "hello world!")


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
    hello_file = open_zip_mojo_read.open("hello.txt", "r")
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
    hello_file = open_zip_mojo_read.open("hello.txt", "r")
    content = hello_file.read()
    assert_equal(String(bytes=content), "hello world!")
    open_zip_mojo_read.close()


def test_deflate_compression_ratio():
    # Test that deflate actually compresses repetitive data
    large_data = "A" * 1000  # 1000 'A' characters should compress well

    # Write with ZIP_STORED (no compression)
    stored_file = "/tmp/large_stored.zip"
    zip_stored = zipfile.ZipFile(stored_file, "w")
    zip_stored.writestr("large.txt", large_data, zipfile.ZIP_STORED)
    zip_stored.close()

    # Write with ZIP_DEFLATED (compression)
    deflated_file = "/tmp/large_deflated.zip"
    zip_deflated = zipfile.ZipFile(deflated_file, "w")
    zip_deflated.writestr("large.txt", large_data, zipfile.ZIP_DEFLATED)
    zip_deflated.close()

    # Read file sizes
    from pathlib import Path

    stored_size = len(Path(stored_file).read_bytes())
    deflated_size = len(Path(deflated_file).read_bytes())

    # Deflated should be significantly smaller for repetitive data
    assert_true(
        deflated_size < stored_size,
        "Deflated file should be smaller than stored file",
    )

    # Verify content is the same when reading back
    zip_read = zipfile.ZipFile(deflated_file, "r")
    file_reader = zip_read.open("large.txt", "r")
    content = file_reader.read()
    assert_equal(String(bytes=content), large_data)
    zip_read.close()


def test_compression_levels():
    # Test different compression levels with repetitive data
    test_data = "Hello World! " * 200  # Repetitive data that compresses well

    # Test various compression levels
    compression_levels = List[Int32](1, 6, 9)  # Fast, default, best
    file_sizes = List[Int]()

    for i in range(len(compression_levels)):
        level = compression_levels[i]
        file_path = "/tmp/test_level_" + String(level) + ".zip"

        # Create zip with specific compression level
        zip_file = zipfile.ZipFile(file_path, "w")
        zip_file.writestr(
            "test.txt", test_data, zipfile.ZIP_DEFLATED, compresslevel=level
        )
        zip_file.close()

        # Verify content can be read back correctly
        zip_read = zipfile.ZipFile(file_path, "r")
        file_reader = zip_read.open("test.txt", "r")
        content = file_reader.read()
        assert_equal(String(bytes=content), test_data)
        zip_read.close()

        # Store file size for comparison
        from pathlib import Path

        file_size = len(Path(file_path).read_bytes())
        file_sizes.append(file_size)

    # Level 9 (best compression) should produce smallest or equal size compared to level 1
    # Note: For small data, differences might be minimal
    assert_true(
        file_sizes[2] <= file_sizes[0],
        "Level 9 should compress at least as well as level 1",
    )


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
    file_reader1 = zip_read1.open("progressive.txt", "r")
    content1 = file_reader1.read()
    assert_equal(String(bytes=content1), expected_content)
    zip_read1.close()

    zip_read9 = zipfile.ZipFile(file_path_level9, "r")
    file_reader9 = zip_read9.open("progressive.txt", "r")
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
        file_reader = zip_read.open("test.txt", "r")
        content = file_reader.read()
        assert_equal(String(bytes=content), test_data)
        zip_read.close()
