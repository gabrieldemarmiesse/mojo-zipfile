from testing import assert_raises, assert_equal
import os
from zipfile import ZipFile
from python import Python
from zipfile._src.metadata import (
    LocalFileHeader,
    CentralDirectoryFileHeader,
    EndOfCentralDirectoryRecord,
    GeneralPurposeBitFlag,
    ZIP_STORED,
)
from zipfile._src.read_write_values import write_zip_value
from builtin.file import FileHandle


def test_zip64_file_size_limit_local_header():
    """Test that LocalFileHeader detects ZIP64 file size limits when reading."""

    # Create a temporary file with a LocalFileHeader that has ZIP64 file size markers
    test_file = "/tmp/test_zip64_size.zip"

    with open(test_file, "w") as fp:
        # Write LocalFileHeader signature
        write_zip_value(fp, LocalFileHeader.SIGNATURE)
        write_zip_value(fp, UInt16(20))  # version_needed_to_extract
        write_zip_value(fp, UInt16(0))  # general_purpose_bit_flag
        write_zip_value(fp, UInt16(0))  # compression (ZIP_STORED)
        write_zip_value(fp, UInt16(0))  # last_mod_file_time
        write_zip_value(fp, UInt16(0))  # last_mod_file_date
        write_zip_value(fp, UInt32(0))  # crc32
        write_zip_value(
            fp, UInt32(0xFFFFFFFF)
        )  # compressed_size (ZIP64 marker)
        write_zip_value(
            fp, UInt32(0xFFFFFFFF)
        )  # uncompressed_size (ZIP64 marker)
        write_zip_value(fp, UInt16(0))  # filename_length
        write_zip_value(fp, UInt16(0))  # extra_field_length

    # Try to read the header - should raise error for invalid ZIP64 file
    with open(test_file, "r") as fp:
        with assert_raises(
            contains="ZIP64 markers present but no ZIP64 extra field found"
        ):
            _ = LocalFileHeader(fp)

    # Clean up
    _ = os.remove(test_file)


def test_zip64_file_offset_limit_central_directory():
    """Test that CentralDirectoryFileHeader detects ZIP64 offset limits when reading.
    """

    test_file = "/tmp/test_zip64_offset.zip"

    with open(test_file, "w") as fp:
        # Write CentralDirectoryFileHeader signature
        write_zip_value(fp, CentralDirectoryFileHeader.SIGNATURE)
        write_zip_value(fp, UInt16(20))  # version_made_by
        write_zip_value(fp, UInt16(20))  # version_needed_to_extract
        write_zip_value(fp, UInt16(0))  # general_purpose_bit_flag
        write_zip_value(fp, UInt16(0))  # compression
        write_zip_value(fp, UInt16(0))  # last_mod_file_time
        write_zip_value(fp, UInt16(0))  # last_mod_file_date
        write_zip_value(fp, UInt32(0))  # crc32
        write_zip_value(fp, UInt32(100))  # compressed_size
        write_zip_value(fp, UInt32(100))  # uncompressed_size
        write_zip_value(fp, UInt16(0))  # filename_length
        write_zip_value(fp, UInt16(0))  # extra_field_length
        write_zip_value(fp, UInt16(0))  # file_comment_length
        write_zip_value(fp, UInt16(0))  # disk_number_start
        write_zip_value(fp, UInt16(0))  # internal_file_attributes
        write_zip_value(fp, UInt32(0))  # external_file_attributes
        write_zip_value(
            fp, UInt32(0xFFFFFFFF)
        )  # relative_offset (ZIP64 marker)

    # Try to read the header - should raise error for invalid ZIP64 file
    with open(test_file, "r") as fp:
        with assert_raises(
            contains="ZIP64 markers present but no ZIP64 extra field found"
        ):
            _ = CentralDirectoryFileHeader(fp)

    # Clean up
    _ = os.remove(test_file)


def test_zip64_central_directory_size_limit():
    """Test that EndOfCentralDirectoryRecord accepts ZIP64 markers in regular EOCD.
    """

    test_file = "/tmp/test_zip64_cd_size.zip"

    with open(test_file, "w") as fp:
        # Write EndOfCentralDirectoryRecord signature
        write_zip_value(fp, EndOfCentralDirectoryRecord.SIGNATURE)
        write_zip_value(fp, UInt16(0))  # number_of_this_disk
        write_zip_value(fp, UInt16(0))  # number_of_disk_with_start_of_cd
        write_zip_value(fp, UInt16(1))  # total_entries_on_this_disk
        write_zip_value(fp, UInt16(1))  # total_entries_in_cd
        write_zip_value(fp, UInt32(0xFFFFFFFF))  # size_of_cd (ZIP64 marker)
        write_zip_value(fp, UInt32(100))  # offset_of_start_of_cd
        write_zip_value(fp, UInt16(0))  # comment_length

    # Should now succeed - ZIP64 markers in EOCD are accepted
    with open(test_file, "r") as fp:
        eocd = EndOfCentralDirectoryRecord(fp)
        # Verify the ZIP64 marker is preserved
        if eocd.size_of_the_central_directory != 0xFFFFFFFF:
            raise Error("Expected ZIP64 marker to be preserved")

    # Clean up
    _ = os.remove(test_file)


def test_zip64_central_directory_offset_limit():
    """Test that EndOfCentralDirectoryRecord accepts ZIP64 markers in regular EOCD.
    """

    test_file = "/tmp/test_zip64_cd_offset.zip"

    with open(test_file, "w") as fp:
        # Write EndOfCentralDirectoryRecord signature
        write_zip_value(fp, EndOfCentralDirectoryRecord.SIGNATURE)
        write_zip_value(fp, UInt16(0))  # number_of_this_disk
        write_zip_value(fp, UInt16(0))  # number_of_disk_with_start_of_cd
        write_zip_value(fp, UInt16(1))  # total_entries_on_this_disk
        write_zip_value(fp, UInt16(1))  # total_entries_in_cd
        write_zip_value(fp, UInt32(100))  # size_of_cd
        write_zip_value(
            fp, UInt32(0xFFFFFFFF)
        )  # offset_of_start_of_cd (ZIP64 marker)
        write_zip_value(fp, UInt16(0))  # comment_length

    # Should now succeed - ZIP64 markers in EOCD are accepted
    with open(test_file, "r") as fp:
        eocd = EndOfCentralDirectoryRecord(fp)
        # Verify the ZIP64 marker is preserved
        if eocd.offset_of_starting_disk_number != 0xFFFFFFFF:
            raise Error("Expected ZIP64 marker to be preserved")

    # Clean up
    _ = os.remove(test_file)


def test_zip64_number_of_entries_limit():
    """Test that EndOfCentralDirectoryRecord accepts ZIP64 markers in regular EOCD.
    """

    test_file = "/tmp/test_zip64_entries.zip"

    with open(test_file, "w") as fp:
        # Write EndOfCentralDirectoryRecord signature
        write_zip_value(fp, EndOfCentralDirectoryRecord.SIGNATURE)
        write_zip_value(fp, UInt16(0))  # number_of_this_disk
        write_zip_value(fp, UInt16(0))  # number_of_disk_with_start_of_cd
        write_zip_value(
            fp, UInt16(0xFFFF)
        )  # total_entries_on_this_disk (ZIP64 marker)
        write_zip_value(fp, UInt16(1))  # total_entries_in_cd
        write_zip_value(fp, UInt32(100))  # size_of_cd
        write_zip_value(fp, UInt32(100))  # offset_of_start_of_cd
        write_zip_value(fp, UInt16(0))  # comment_length

    # Should now succeed - ZIP64 markers in EOCD are accepted
    with open(test_file, "r") as fp:
        eocd = EndOfCentralDirectoryRecord(fp)
        # Verify the ZIP64 marker is preserved
        if (
            eocd.total_number_of_entries_in_the_central_directory_on_this_disk
            != 0xFFFF
        ):
            raise Error("Expected ZIP64 marker to be preserved")

    # Clean up
    _ = os.remove(test_file)


def test_read_zip64_moderate_file():
    """Test reading a ZIP64 file with moderate-sized content."""
    file_path = "/tmp/zip64_moderate_test.zip"

    # Create ZIP64 file using Python
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.create_zip64_moderate_file(file_path)

    # Read with Mojo zipfile
    zip_file = ZipFile(file_path, "r")

    # Verify file list
    info_list = zip_file.infolist()
    assert_equal(len(info_list), 1)

    # Read the file content
    file_reader = zip_file.open("test_file.txt", "r")
    content = file_reader.read()

    # Expected content size is 10MB
    expected_size = 10 * 1024 * 1024
    assert_equal(len(content), expected_size)

    # Verify content pattern (check first and last parts)
    expected_pattern = "ZIP64 test data pattern - "
    content_str = String(bytes=content)

    # Check that content starts with expected pattern
    if not content_str.startswith(expected_pattern):
        raise Error("Content doesn't start with expected pattern")

    # Verify the pattern appears multiple times (it should repeat throughout)
    if content_str.count(expected_pattern) < 100:
        raise Error("Content doesn't contain expected pattern repetitions")

    zip_file.close()

    # Clean up
    _ = os.remove(file_path)


def test_read_zip64_many_files():
    """Test reading a ZIP64 file with many entries."""
    file_path = "/tmp/zip64_many_files_test.zip"

    # Create ZIP64 file with many entries using Python
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.create_zip64_moderate_many_files(file_path)

    # Read with Mojo zipfile
    zip_file = ZipFile(file_path, "r")

    # Verify file list has correct number of entries
    info_list = zip_file.infolist()
    assert_equal(len(info_list), 1000)

    # Test reading a few specific files
    test_files = ["file_000.txt", "file_500.txt", "file_999.txt"]

    for filename in test_files:
        file_reader = zip_file.open(filename, "r")
        content = file_reader.read()
        content_str = String(bytes=content)

        # Extract file number from filename and convert to int then back to string
        file_num_str = filename[5:8]  # Extract "000", "500", "999"
        try:
            file_num_int = atol(file_num_str)
        except:
            raise Error("Could not parse file number from " + filename)

        expected_start = "This is the content of file number " + String(
            file_num_int
        )

        if not content_str.startswith(expected_start^):
            raise Error(
                "Content doesn't match expected pattern for "
                + filename
                + ". Got: "
                + content_str[:50]
            )

        # Verify content is repeated 5 times
        if (
            content_str.count(
                "This is the content of file number " + String(file_num_int)
            )
            != 5
        ):
            raise Error("Content repetition count incorrect for " + filename)

    zip_file.close()

    # Clean up
    _ = os.remove(file_path)


def test_read_zip64_file_streaming():
    """Test streaming read of ZIP64 file content in chunks."""
    file_path = "/tmp/zip64_streaming_test.zip"

    # Create ZIP64 file using Python
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    tests_helper.create_zip64_moderate_file(file_path)

    # Read with Mojo zipfile in streaming mode
    zip_file = ZipFile(file_path, "r")

    # Test streaming read of the large file
    file_reader = zip_file.open("test_file.txt", "r")

    # Read in chunks of 1MB
    chunk_size = 1024 * 1024
    total_bytes_read = 0
    chunks_read = 0

    while True:
        chunk = file_reader.read(chunk_size)
        if len(chunk) == 0:
            break

        total_bytes_read += len(chunk)
        chunks_read += 1

        # Verify chunk content contains expected pattern
        chunk_str = String(bytes=chunk)
        if chunks_read == 1 and not chunk_str.startswith(
            "ZIP64 test data pattern - "
        ):
            raise Error("First chunk doesn't start with expected pattern")

        # All chunks should contain the pattern somewhere
        if "ZIP64 test data pattern - " not in chunk_str:
            raise Error(
                "Chunk "
                + String(chunks_read)
                + " doesn't contain expected pattern"
            )

    # Verify we read the expected total size
    expected_size = 10 * 1024 * 1024  # 10MB
    assert_equal(total_bytes_read, expected_size)

    # Verify we read in multiple chunks (adjust expectation based on compression)
    if chunks_read < 2:
        raise Error(
            "Expected to read in multiple chunks, got " + String(chunks_read)
        )

    zip_file.close()

    # Clean up
    _ = os.remove(file_path)
