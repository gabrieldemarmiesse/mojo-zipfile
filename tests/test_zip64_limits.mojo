from testing import assert_raises
import os
from zipfile import ZipFile
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
        write_zip_value(fp, UInt16(0))  # compression_method (ZIP_STORED)
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
        write_zip_value(fp, UInt16(0))  # compression_method
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
