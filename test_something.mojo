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
    Python.add_to_path("./")
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


def test_write_empty_zip():
    file_path = "/tmp/empty55.zip"
    other = "/tmp/empty882.zip"
    open_zip_mojo = zipfile.ZipFile(file_path, "w")
    open_zip_mojo.close()

    Python.add_to_path("./")
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

    Python.add_to_path("./")
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

    Python.add_to_path("./")
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

    Python.add_to_path("./")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.verify_hello_world_zip(file_path)


def test_read_simple_hello_world_deflate():
    file_path = "/tmp/hello7276.zip"
    Python.add_to_path("./")
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
    Python.add_to_path("./")
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
    Python.add_to_path("./")
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
    print("Stored size:", stored_size)
    print("Deflated size:", deflated_size)
    print("Compression ratio:", Float64(stored_size) / Float64(deflated_size))
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


def main():
    test_is_zipfile_valid()
    test_identical_analysis()
    test_read_content()
    test_write_empty_zip()
    test_write_simple_hello_world()
    test_write_simple_hello_world_progressive_without_close()
    test_read_simple_hello_world_deflate()
    test_write_simple_hello_world_deflate()
    test_write_simple_hello_world_deflate_progressive()
    test_deflate_compression_ratio()
    print("All tests passed!")
