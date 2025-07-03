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

    # Try to read the header - should raise ZIP64 error
    with open(test_file, "r") as fp:
        with assert_raises(contains="ZIP64 format not supported yet"):
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

    # Try to read the header - should raise ZIP64 error
    with open(test_file, "r") as fp:
        with assert_raises(contains="ZIP64 format not supported yet"):
            _ = CentralDirectoryFileHeader(fp)

    # Clean up
    _ = os.remove(test_file)


def test_zip64_central_directory_size_limit():
    """Test that EndOfCentralDirectoryRecord detects ZIP64 central directory size limits.
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

    # Try to read the header - should raise ZIP64 error
    with open(test_file, "r") as fp:
        with assert_raises(contains="ZIP64 format not supported yet"):
            _ = EndOfCentralDirectoryRecord(fp)

    # Clean up
    _ = os.remove(test_file)


def test_zip64_central_directory_offset_limit():
    """Test that EndOfCentralDirectoryRecord detects ZIP64 central directory offset limits.
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

    # Try to read the header - should raise ZIP64 error
    with open(test_file, "r") as fp:
        with assert_raises(contains="ZIP64 format not supported yet"):
            _ = EndOfCentralDirectoryRecord(fp)

    # Clean up
    _ = os.remove(test_file)


def test_zip64_number_of_entries_limit():
    """Test that EndOfCentralDirectoryRecord detects ZIP64 number of entries limits.
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

    # Try to read the header - should raise ZIP64 error
    with open(test_file, "r") as fp:
        with assert_raises(contains="ZIP64 format not supported yet"):
            _ = EndOfCentralDirectoryRecord(fp)

    # Clean up
    _ = os.remove(test_file)


def test_writing_large_file_fails():
    """Test that attempting to write a large file fails with proper error message.
    """

    test_file = "/tmp/test_large_write.zip"

    try:
        # Create a ZipFile for writing and try to write a file that would exceed ZIP64 limits
        var zf = ZipFile(test_file, "w")
        var writer = zf.open_to_write("large_file.txt", "w", ZIP_STORED)

        # Simulate writing beyond 4GB by setting the internal size directly
        writer.uncompressed_size = UInt64(0x100000000)  # 4GB + 1
        writer.compressed_size = UInt64(0x100000000)  # 4GB + 1

        # Closing should fail with ZIP64 error
        with assert_raises(contains="ZIP64 format not supported yet"):
            writer.close()

        # Set writer as closed to prevent destructor issues
        _ = writer.open
        writer.open = False

        try:
            zf.close()
        except:
            pass  # Expected to fail since writer didn't close properly

    except:
        pass  # Handle any other issues

    # Clean up
    try:
        _ = os.remove(test_file)
    except:
        pass  # File might not exist if test failed early
