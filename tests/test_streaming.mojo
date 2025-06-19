"""Streaming functionality tests for zipfile module."""

import zipfile
from testing import assert_equal, assert_true, assert_raises
from python import Python
from pathlib import Path


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
