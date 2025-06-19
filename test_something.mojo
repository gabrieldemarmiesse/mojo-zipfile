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
    Python.add_to_path("./")
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
        compresslevel=zipfile.Z_BEST_SPEED,
    )
    zip_speed.close()

    # Test with Z_BEST_COMPRESSION
    file_path_compression = "/tmp/test_best_compression.zip"
    zip_compression = zipfile.ZipFile(file_path_compression, "w")
    zip_compression.writestr(
        "test.txt",
        test_data,
        zipfile.ZIP_DEFLATED,
        compresslevel=zipfile.Z_BEST_COMPRESSION,
    )
    zip_compression.close()

    # Test with Z_DEFAULT_COMPRESSION
    file_path_default = "/tmp/test_default_compression.zip"
    zip_default = zipfile.ZipFile(file_path_default, "w")
    zip_default.writestr(
        "test.txt",
        test_data,
        zipfile.ZIP_DEFLATED,
        compresslevel=zipfile.Z_DEFAULT_COMPRESSION,
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
    Python.add_to_path("./")
    py_zipfile = Python.import_module("zipfile")
    py_zip = py_zipfile.ZipFile(file_path, "r")
    py_content1 = py_zip.read("test1.txt")
    py_content2 = py_zip.read("test2.txt")
    py_zip.close()

    # Compare results with Python
    assert_equal(String(py_content1.decode("utf-8")), test_data)
    assert_equal(String(py_content2.decode("utf-8")), "Different content")


def test_streaming_large_file_small_chunks():
    """Test reading a large compressed file in small chunks to verify buffer refill logic.
    """
    # Create large repetitive data that compresses well
    # Use 200KB of data to ensure it exceeds both input and output buffer sizes
    chunk_pattern = (
        "This is a test pattern that repeats many times. " * 50
    )  # ~2.4KB per chunk
    total_chunks = 85  # About 200KB total
    large_data = chunk_pattern * total_chunks

    file_path = "/tmp/large_streaming_test.zip"

    # Create a zip file with large deflated content
    zip_write = zipfile.ZipFile(file_path, "w")
    zip_write.writestr(
        "large.txt", large_data, zipfile.ZIP_DEFLATED, compresslevel=6
    )
    zip_write.close()

    # Test reading in very small chunks (much smaller than buffer sizes)
    zip_read = zipfile.ZipFile(file_path, "r")
    file_reader = zip_read.open("large.txt", "r")

    # Read in 1KB chunks to force multiple buffer refills
    chunk_size = 1024
    reconstructed_data = List[UInt8]()
    bytes_read = 0

    while True:
        chunk = file_reader.read(chunk_size)
        if len(chunk) == 0:
            break

        reconstructed_data += chunk

        bytes_read += len(chunk)

        # Verify we're making progress and not stuck in infinite loop
        assert_true(
            bytes_read <= len(large_data) + chunk_size,
            "Read more data than expected",
        )

    # Verify complete data integrity - check size first
    assert_equal(len(reconstructed_data), len(large_data))

    # Then verify content byte-by-byte to avoid huge error messages
    large_data_bytes = large_data.as_bytes()
    for i in range(len(reconstructed_data)):
        if reconstructed_data[i] != large_data_bytes[i]:
            assert_true(False, "Data mismatch at byte " + String(i))

    zip_read.close()


def test_streaming_large_file_large_chunks():
    """Test reading a large compressed file in large chunks (bigger than buffers).
    """
    # Create large data - about 300KB
    base_pattern = (
        "Large chunk test data with some variety in content to test"
        " compression. "
        * 100
    )  # ~7KB
    large_data = base_pattern * 45  # About 300KB

    file_path = "/tmp/large_chunk_test.zip"

    # Create zip with large content
    zip_write = zipfile.ZipFile(file_path, "w")
    zip_write.writestr(
        "huge.txt", large_data, zipfile.ZIP_DEFLATED, compresslevel=9
    )
    zip_write.close()

    # Test reading in chunks larger than internal buffers (> 64KB)
    zip_read = zipfile.ZipFile(file_path, "r")
    file_reader = zip_read.open("huge.txt", "r")

    # Read in 100KB chunks - larger than the 64KB output buffer
    chunk_size = 100 * 1024  # 100KB
    reconstructed_data = List[UInt8]()

    while True:
        chunk = file_reader.read(chunk_size)
        if len(chunk) == 0:
            break
        reconstructed_data += chunk

        # Ensure we're not reading infinitely
        assert_true(
            len(reconstructed_data) <= len(large_data) + chunk_size,
            "Read exceeded expected size",
        )

    # Verify complete data integrity - check size first
    assert_equal(len(reconstructed_data), len(large_data))

    # Then verify content byte-by-byte to avoid huge error messages
    large_data_bytes = large_data.as_bytes()
    for i in range(len(reconstructed_data)):
        if reconstructed_data[i] != large_data_bytes[i]:
            assert_true(False, "Data mismatch at byte " + String(i))

    zip_read.close()


def test_streaming_entire_large_file():
    """Test reading an entire large compressed file at once."""
    # Create very large data - about 500KB
    pattern1 = (
        "Pattern type A with some unique content for testing compression"
        " ratios. "
    )
    pattern2 = (
        "Pattern type B with different content to create variety in the data"
        " stream. "
    )
    pattern3 = (
        "Pattern type C with yet another different content pattern for good"
        " measure. "
    )

    # Mix patterns to create realistic data
    large_data = String("")
    for i in range(2000):  # About 500KB total
        if i % 3 == 0:
            large_data += pattern1
        elif i % 3 == 1:
            large_data += pattern2
        else:
            large_data += pattern3

    file_path = "/tmp/entire_large_test.zip"

    # Create zip with very large content
    zip_write = zipfile.ZipFile(file_path, "w")
    zip_write.writestr(
        "massive.txt", large_data, zipfile.ZIP_DEFLATED, compresslevel=6
    )
    zip_write.close()

    # Test reading entire file at once (size=-1)
    zip_read = zipfile.ZipFile(file_path, "r")
    file_reader = zip_read.open("massive.txt", "r")

    # Read entire file in one call
    all_data = file_reader.read(-1)

    # Verify complete data integrity - check size first
    assert_equal(len(all_data), len(large_data))

    # Then verify content byte-by-byte to avoid huge error messages
    large_data_bytes = large_data.as_bytes()
    for i in range(len(all_data)):
        if all_data[i] != large_data_bytes[i]:
            assert_true(False, "Data mismatch at byte " + String(i))

    # Try reading again - should return empty
    more_data = file_reader.read()
    assert_equal(len(more_data), 0)

    zip_read.close()


def test_mixed_read_patterns_large_file():
    """Test mixing different read patterns on the same large file."""
    # Create large data with clear patterns for easy verification
    segment = "SEGMENT_DATA_" * 100  # About 1.2KB per segment
    large_data = String("")
    for i in range(200):  # About 240KB total
        # Create segment number with leading zeros
        large_data += "SEGMENT_" + String(i) + "_" + segment

    file_path = "/tmp/mixed_pattern_test.zip"

    # Create zip file
    zip_write = zipfile.ZipFile(file_path, "w")
    zip_write.writestr(
        "mixed.txt", large_data, zipfile.ZIP_DEFLATED, compresslevel=6
    )
    zip_write.close()

    # Test mixed reading patterns
    zip_read = zipfile.ZipFile(file_path, "r")
    file_reader = zip_read.open("mixed.txt", "r")

    reconstructed_data = List[UInt8]()

    # Read small chunk first
    reconstructed_data += file_reader.read(500)

    # Read medium chunk
    reconstructed_data += file_reader.read(5000)

    # Read large chunk
    reconstructed_data += file_reader.read(50000)

    # Read very small chunks
    for _ in range(10):
        reconstructed_data += file_reader.read(100)

    # Read rest of file
    rest = file_reader.read(-1)
    reconstructed_data += rest

    # Verify complete data integrity - check size first
    assert_equal(len(reconstructed_data), len(large_data))

    # Then verify content byte-by-byte to avoid huge error messages
    large_data_bytes = large_data.as_bytes()
    for i in range(len(reconstructed_data)):
        if reconstructed_data[i] != large_data_bytes[i]:
            assert_true(False, "Data mismatch at byte " + String(i))

    zip_read.close()


def test_streaming_multiple_large_files():
    """Test streaming from multiple large files in the same ZIP to verify state isolation.
    """
    # Create different large datasets - smaller to debug more easily
    data1 = "FILE1_CONTENT_" * 100  # About 1.5KB
    data2 = "FILE2_DIFFERENT_DATA_" * 100  # About 2KB
    data3 = "FILE3_UNIQUE_PATTERN_" * 100  # About 2KB

    file_path = "/tmp/multiple_large_test.zip"

    # Create zip with multiple large files
    zip_write = zipfile.ZipFile(file_path, "w")
    zip_write.writestr(
        "file1.txt", data1, zipfile.ZIP_DEFLATED, compresslevel=6
    )
    zip_write.writestr(
        "file2.txt", data2, zipfile.ZIP_DEFLATED, compresslevel=6
    )
    zip_write.writestr(
        "file3.txt", data3, zipfile.ZIP_DEFLATED, compresslevel=6
    )
    zip_write.close()

    # Test reading all files with different patterns
    zip_read = zipfile.ZipFile(file_path, "r")

    # Read each file separately to avoid potential state sharing issues

    # Read file1 in small chunks
    reader1 = zip_read.open("file1.txt", "r")
    reconstructed1 = List[UInt8]()
    while True:
        chunk = reader1.read(512)
        if len(chunk) == 0:
            break
        reconstructed1 += chunk

    # Verify file1 immediately - check size first
    assert_equal(len(reconstructed1), len(data1))
    data1_bytes = data1.as_bytes()
    for i in range(len(reconstructed1)):
        if reconstructed1[i] != data1_bytes[i]:
            assert_true(False, "File1 data mismatch at byte " + String(i))

    # Read file2 all at once
    reader2 = zip_read.open("file2.txt", "r")
    reconstructed2 = reader2.read(-1)

    # Verify file2 - check size first
    assert_equal(len(reconstructed2), len(data2))
    data2_bytes = data2.as_bytes()
    for i in range(len(reconstructed2)):
        if reconstructed2[i] != data2_bytes[i]:
            assert_true(False, "File2 data mismatch at byte " + String(i))

    # Read file3 in medium chunks
    reader3 = zip_read.open("file3.txt", "r")
    reconstructed3 = List[UInt8]()
    while True:
        chunk = reader3.read(1024)
        if len(chunk) == 0:
            break
        reconstructed3 += chunk

    # Verify file3 - check size first
    assert_equal(len(reconstructed3), len(data3))
    data3_bytes = data3.as_bytes()
    for i in range(len(reconstructed3)):
        if reconstructed3[i] != data3_bytes[i]:
            assert_true(False, "File3 data mismatch at byte " + String(i))

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
    test_compression_levels()
    test_compression_level_progressive_write()
    test_compression_level_constants()
    test_read_method()
    test_streaming_large_file_small_chunks()
    test_streaming_large_file_large_chunks()
    test_streaming_entire_large_file()
    test_mixed_read_patterns_large_file()
    test_streaming_multiple_large_files()
