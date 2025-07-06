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


def test_deflate_compression_ratio():
    # Test that deflate actually compresses repetitive data
    large_data = "A" * 1000  # 1000 'A' characters should compress well

    # Write with ZIP_STORED (no compression)
    stored_file = "/tmp/large_stored.zip"
    zip_stored = zipfile.ZipFile(stored_file, "w", zipfile.ZIP_STORED)
    zip_stored.writestr("large.txt", large_data)
    zip_stored.close()

    # Write with ZIP_DEFLATED (compression)
    deflated_file = "/tmp/large_deflated.zip"
    zip_deflated = zipfile.ZipFile(deflated_file, "w", zipfile.ZIP_DEFLATED)
    zip_deflated.writestr("large.txt", large_data)
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
    file_reader = zip_read.open_to_read("large.txt", "r")
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
        zip_file = zipfile.ZipFile(
            file_path, "w", zipfile.ZIP_DEFLATED, compresslevel=level
        )
        zip_file.writestr("test.txt", test_data)
        zip_file.close()

        # Verify content can be read back correctly
        zip_read = zipfile.ZipFile(file_path, "r")
        file_reader = zip_read.open_to_read("test.txt", "r")
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


def test_read_content():
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    file_path = "/tmp/dodo24.zip"
    tests_helper.create_hello_world_zip(file_path)

    open_zip_mojo = zipfile.ZipFile(file_path, "r")
    assert_equal(len(open_zip_mojo.infolist()), 1)
    hello_file = open_zip_mojo.open_to_read("hello.txt", "r")
    content = hello_file.read()
    assert_equal(String(bytes=content), "hello world!")

    hello_file = open_zip_mojo.open_to_read("hello.txt", "r")
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
    zip_write = zipfile.ZipFile(file_path, "w")  # Default is ZIP_STORED
    zip_write.writestr("test1.txt", test_data)  # ZIP_STORED
    zip_write.close()

    # Create second file with ZIP_DEFLATED
    zip_write2 = zipfile.ZipFile(
        file_path, "w", zipfile.ZIP_DEFLATED, compresslevel=Int32(6)
    )
    zip_write2.writestr("test1.txt", test_data)  # Keep same content for test
    zip_write2.writestr("test2.txt", "Different content")
    zip_write2.close()

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


def test_namelist():
    # Test the namelist() method which should work like Python's zipfile.namelist()
    test_data = "Test content for namelist test"
    file_path = "/tmp/test_namelist.zip"

    # Create a zip file with multiple files
    zip_write = zipfile.ZipFile(file_path, "w")
    zip_write.writestr("file1.txt", test_data)
    zip_write.writestr("folder/file2.txt", "Content for file2")
    zip_write.writestr("folder/subfolder/file3.txt", "Content for file3")
    zip_write.writestr("another.txt", "Another file content")
    zip_write.close()

    # Test namelist() method
    zip_read = zipfile.ZipFile(file_path, "r")
    names = zip_read.namelist()

    # Check that we got all expected filenames
    expected_names = [
        "file1.txt",
        "folder/file2.txt",
        "folder/subfolder/file3.txt",
        "another.txt",
    ]

    assert_equal(
        len(names), len(expected_names), "Number of files should match"
    )

    # Check that all expected names are present
    for i in range(len(expected_names)):
        found = False
        for j in range(len(names)):
            if names[j] == expected_names[i]:
                found = True
                break
        assert_true(
            found,
            "Expected filename " + expected_names[i] + " not found in namelist",
        )

    zip_read.close()

    # Verify compatibility with Python's zipfile
    Python.add_to_path("./tests")
    py_zipfile = Python.import_module("zipfile")
    py_zip = py_zipfile.ZipFile(file_path, "r")
    py_names = py_zip.namelist()
    py_zip.close()

    # Compare results with Python
    assert_equal(
        len(names),
        len(py_names),
        "Number of files should match Python's implementation",
    )

    # Check that all Python names are present in our implementation
    for i in range(len(py_names)):
        py_name = String(py_names[i])
        found = False
        for j in range(len(names)):
            if names[j] == py_name:
                found = True
                break
        assert_true(
            found, "Python filename " + py_name + " not found in our namelist"
        )
