"""This module implement reading a zip file in Mojo. It follows the Python api, but will have less features.
Notably, we wont implement any storage option other than ZIP_STORED
"""
from os import PathLike, abort
from builtin.file import FileHandle
from .read_write_values import read_zip_value, write_zip_value
from .utils import _lists_are_equal
from .metadata import (
    LocalFileHeader,
    CentralDirectoryFileHeader,
    EndOfCentralDirectoryRecord,
    ZIP_STORED,
    ZIP_DEFLATED,
    GeneralPurposeBitFlag,
)
import os
from .crc_32 import CRC32
from .zlib import uncompress, compress, StreamingDecompressor
from utils import Variant


def is_zipfile[FileNameType: PathLike](filename: FileNameType) -> Bool:
    with open(filename, "rb") as fp:
        # For now we only check the first 4 bytes, it should be good enough
        # to check if the file is a zip file
        header = fp.read_bytes(4)
        if _lists_are_equal(header, LocalFileHeader.SIGNATURE):
            return True
        else:
            return False


struct ZipInfo(Copyable, Movable):
    var filename: String
    var _start_of_header: UInt64
    var _compressed_size: UInt64
    var _uncompressed_size: UInt64
    var _compression_method: UInt16
    var _crc32: Optional[UInt32]

    def __init__(out self, header: CentralDirectoryFileHeader):
        self.filename = String(bytes=header.filename)
        self._start_of_header = UInt64(header.relative_offset_of_local_header)
        self._compressed_size = UInt64(header.compressed_size)
        self._uncompressed_size = UInt64(header.uncompressed_size)
        self._compression_method = header.compression_method
        self._crc32 = header.crc32

    fn is_dir(self) -> Bool:
        return self.filename.endswith("/")


struct ZipFileReader[origin: Origin[mut=True]]:
    var file: Pointer[FileHandle, origin]
    var compressed_size: UInt64
    var uncompressed_size: UInt64
    var compression_method: UInt16
    var start: UInt64
    var expected_crc32: UInt32
    var crc32: CRC32
    var _inner_buffer: List[UInt8]  # Only used for ZIP_STORED now
    var _streaming_decompressor: StreamingDecompressor  # For ZIP_DEFLATED
    var _decompressor_initialized: Bool  # Track if decompressor is initialized
    var _bytes_read_from_file: UInt64  # Track how much compressed data we've read

    fn __init__(
        out self,
        file: Pointer[FileHandle, origin],
        compressed_size: UInt64,
        uncompressed_size: UInt64,
        compression_method: UInt16,
        expected_crc32: UInt32,
    ) raises:
        self.file = file
        self.compressed_size = compressed_size
        self.uncompressed_size = uncompressed_size
        self.compression_method = compression_method
        self.start = file[].seek(0, os.SEEK_CUR)
        self.expected_crc32 = expected_crc32
        self.crc32 = CRC32()
        self._inner_buffer = List[UInt8]()
        self._streaming_decompressor = StreamingDecompressor()
        self._decompressor_initialized = False
        self._bytes_read_from_file = 0

    fn _is_at_start(self) raises -> Bool:
        return self.file[].seek(0, os.SEEK_CUR) == self.start

    fn _remaining_size(self) raises -> Int:
        end = self.start + self.compressed_size

        return Int(end - self.file[].seek(0, os.SEEK_CUR))

    fn _check_crc32(self) raises:
        computed_crc32 = self.crc32.get_final_crc()
        if computed_crc32 != self.expected_crc32:
            raise Error(
                "CRC32 mismatch, expected: "
                + String(self.expected_crc32)
                + ", got: "
                + String(computed_crc32)
            )

    fn read(mut self, owned size: Int = -1) raises -> List[UInt8]:
        if self.compression_method == ZIP_STORED:
            if size == -1:
                size = self._remaining_size()
            else:
                size = min(size, self._remaining_size())

            bytes = self.file[].read_bytes(size)
            self.crc32.write(bytes)

            if self._remaining_size() == 0:
                # We are at the end of the file
                self._check_crc32()
            return bytes
        elif self.compression_method == ZIP_DEFLATED:
            return self._read_deflated(size)
        else:
            raise Error(
                "Unsupported compression method: "
                + String(self.compression_method)
            )

    fn _read_deflated(mut self, size: Int) raises -> List[UInt8]:
        """Read deflated data using streaming decompression."""
        # Initialize streaming decompressor if needed
        if not self._decompressor_initialized:
            self._streaming_decompressor.initialize()
            self._decompressor_initialized = True

        # Read compressed data in chunks and feed to decompressor
        # Use 32KB chunks to balance I/O and memory usage
        alias CHUNK_SIZE = 32768

        var result = List[UInt8]()
        var bytes_needed = size if size > 0 else -1  # -1 means read all

        while True:
            # Determine how much to request from decompressor
            var chunk_request = 65536  # Default chunk size
            if bytes_needed > 0:
                chunk_request = min(bytes_needed, 65536)

            # First, try to get data from the decompressor
            var decompressed_data = self._streaming_decompressor.read(
                chunk_request
            )

            if len(decompressed_data) > 0:
                # Add to result
                result += decompressed_data

                # Update CRC32 with decompressed data
                self.crc32.write(decompressed_data)

                # Update bytes needed counter
                if bytes_needed > 0:
                    bytes_needed -= len(decompressed_data)
                    if bytes_needed <= 0:
                        # We have enough data
                        return result

                # If reading all data (size <= 0), continue until finished
                if size <= 0:
                    # Check if we've read all data and verify CRC
                    if (
                        self._streaming_decompressor.is_finished()
                        and self._bytes_read_from_file == self.compressed_size
                    ):
                        self._check_crc32()
                        return result
                    # Otherwise continue reading
                else:
                    # For specific size requests, return what we have so far
                    return result

            # If decompressor can't provide data, check if we need more input
            if self._streaming_decompressor.is_finished():
                # All done, return what we have
                if self._bytes_read_from_file == self.compressed_size:
                    self._check_crc32()
                return result

            # Read more compressed data from file if available
            if self._bytes_read_from_file < self.compressed_size:
                var remaining_compressed = (
                    self.compressed_size - self._bytes_read_from_file
                )
                var to_read = min(CHUNK_SIZE, Int(remaining_compressed))

                var compressed_chunk = self.file[].read_bytes(to_read)
                self._bytes_read_from_file += UInt64(len(compressed_chunk))

                # Feed to decompressor
                self._streaming_decompressor.feed_input(compressed_chunk)
            # We've read all compressed data from file, but decompressor may still have data to process
            # This is normal - zlib might need multiple calls to process all the input
            # Continue the loop to let decompressor process remaining input buffer data


struct ZipFileWriter[origin: Origin[mut=True]]:
    var zipfile: Pointer[ZipFile, origin]
    var local_file_header: LocalFileHeader
    var crc32: CRC32
    var compressed_size: UInt64
    var uncompressed_size: UInt64
    var crc32_position: UInt64
    var open: Bool
    var _uncompressed_buffer: List[UInt8]  # Buffer for deflate compression
    var _compresslevel: Int32  # Compression level for deflate
    var _header_offset: UInt64  # Position where the local file header was written

    fn __init__(
        out self,
        zipfile: Pointer[ZipFile, origin],
        name: String,
        mode: String,
        compression_method: UInt16,
        compresslevel: Int32 = -1,  # Z_DEFAULT_COMPRESSION
    ) raises:
        self.zipfile = zipfile
        self.local_file_header = LocalFileHeader(
            version_needed_to_extract=20,
            general_purpose_bit_flag=GeneralPurposeBitFlag(
                strings_are_utf8=True
            ),
            compression_method=compression_method,
            last_mod_file_time=0,
            last_mod_file_date=0,
            crc32=0,  # We'll write it when closing
            compressed_size=0,  # We'll write it when closing
            uncompressed_size=0,  # We'll write it when closing
            filename=List[UInt8](name.as_bytes()),
            extra_field=List[UInt8](),
        )
        self.crc32 = CRC32()
        self.compressed_size = 0
        self.uncompressed_size = 0
        self._header_offset = self.zipfile[].file.seek(0, os.SEEK_CUR)
        self.crc32_position = self._header_offset + 14
        _ = self.local_file_header.write_to_file(self.zipfile[].file)
        self.open = True
        self._uncompressed_buffer = List[UInt8]()
        self._compresslevel = compresslevel

    fn write(mut self, data: Span[UInt8]) raises:
        if not self.open:
            raise Error(
                "File is closed. You must have called close() beforehand."
            )

        # Update CRC32 and uncompressed size regardless of compression method
        self.crc32.write(data)
        self.uncompressed_size += UInt64(len(data))

        if self.local_file_header.compression_method == ZIP_STORED:
            # For stored (uncompressed), write directly to file
            self.zipfile[].file.write_bytes(data)
            self.compressed_size += UInt64(len(data))
        elif self.local_file_header.compression_method == ZIP_DEFLATED:
            # For deflate, accumulate data in buffer for compression on close
            for byte in data:
                self._uncompressed_buffer.append(byte)
        else:
            raise Error(
                "Unsupported compression method: "
                + String(self.local_file_header.compression_method)
            )

    fn close(mut self) raises:
        if not self.open:
            raise Error(
                "File is closed. You must have called close() beforehand."
            )

        # Handle compression for deflate method
        if (
            self.local_file_header.compression_method == ZIP_DEFLATED
            and len(self._uncompressed_buffer) > 0
        ):
            # Compress the accumulated data
            compressed_data = compress(
                self._uncompressed_buffer, self._compresslevel, quiet=True
            )
            self.zipfile[].file.write_bytes(compressed_data)
            self.compressed_size = UInt64(len(compressed_data))

        # We need to write the crc32 and the compressed size
        self.local_file_header.crc32 = self.crc32.get_final_crc()
        self.local_file_header.compressed_size = UInt32(self.compressed_size)
        self.local_file_header.uncompressed_size = UInt32(
            self.uncompressed_size
        )

        old_position = self.zipfile[].file.seek(0, os.SEEK_CUR)
        _ = self.zipfile[].file.seek(self.crc32_position)
        write_zip_value(self.zipfile[].file, self.local_file_header.crc32)
        write_zip_value(
            self.zipfile[].file, self.local_file_header.compressed_size
        )
        write_zip_value(
            self.zipfile[].file, self.local_file_header.uncompressed_size
        )
        _ = self.zipfile[].file.seek(old_position)
        # Create central directory entry with correct header offset
        self.zipfile[].central_directory_files_headers.append(
            CentralDirectoryFileHeader(
                self.local_file_header, UInt32(self._header_offset)
            )
        )
        self.open = False

    fn __del__(owned self):
        if self.open:
            try:
                self.close()
            except Error:
                abort(
                    "Failed to close the file properly. You should call close()"
                    " manually if you want to catch the error."
                )


# Negactive offsets are broken in Mojo for seek
struct ZipFile:
    var file: FileHandle
    var mode: String
    var end_of_central_directory_start: UInt64
    var file_size: UInt64
    var central_directory_files_headers: List[CentralDirectoryFileHeader]
    var end_of_central_directory: EndOfCentralDirectoryRecord

    fn __init__[
        FileNameType: PathLike
    ](out self, filename: FileNameType, mode: String) raises:
        self.file = open(filename, mode)
        if mode not in String("r", "w"):
            raise Error("Only read and write modes are suported")
        self.mode = mode
        self.central_directory_files_headers = List[
            CentralDirectoryFileHeader
        ]()
        if mode == "r":
            self.file_size = self.file.seek(0, os.SEEK_END)

            # Let's assume that the file does not contains any comment.
            # Later on we can do the signature search.
            self.end_of_central_directory_start = self.file.seek(
                self.file_size - 22
            )
            self.end_of_central_directory = EndOfCentralDirectoryRecord(
                self.file
            )
        elif mode == "w":
            self.file_size = 0
            self.end_of_central_directory_start = 0
            self.end_of_central_directory = EndOfCentralDirectoryRecord(
                number_of_this_disk=0,
                number_of_the_disk_with_the_start_of_the_central_directory=0,
                total_number_of_entries_in_the_central_directory_on_this_disk=0,
                total_number_of_entries_in_the_central_directory=0,
                size_of_the_central_directory=0,
                offset_of_starting_disk_number=0,
                zip_file_comment=List[UInt8](),
            )
        else:
            raise Error("Only read and write modes are suported")

    fn __moveinit__(out self, owned existing: Self):
        self.file = existing.file^
        self.mode = existing.mode
        self.end_of_central_directory_start = (
            existing.end_of_central_directory_start
        )
        self.end_of_central_directory = existing.end_of_central_directory^
        self.file_size = existing.file_size
        self.central_directory_files_headers = (
            existing.central_directory_files_headers^
        )

    fn __enter__(ref self) -> ref [__origin_of(self)] ZipFile:
        return self

    fn __exit__(mut self) raises:
        self.close()

    fn close(mut self) raises:
        if self.mode == "w":
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk = len(
                self.central_directory_files_headers
            )
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory = len(
                self.central_directory_files_headers
            )
            self.end_of_central_directory.offset_of_starting_disk_number = (
                UInt32(self.file.seek(0, os.SEEK_CUR))
            )

            for header in self.central_directory_files_headers:
                _ = header.write_to_file(self.file)

            self.end_of_central_directory.size_of_the_central_directory = UInt32(
                UInt32(self.file.seek(0, os.SEEK_CUR))
                - self.end_of_central_directory.offset_of_starting_disk_number
            )

            _ = self.end_of_central_directory.write_to_file(self.file)
        self.file.close()

    fn open(
        mut self, name: ZipInfo, mode: String
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        if mode != "r":
            raise Error("Only read mode is the only mode supported")
        if (
            name._compression_method != ZIP_STORED
            and name._compression_method != ZIP_DEFLATED
        ):
            raise Error(
                "Only ZIP_STORED and ZIP_DEFLATED compression method is"
                " supported"
            )
        # We need to seek to the start of the header
        _ = self.file.seek(name._start_of_header)
        _ = LocalFileHeader(self.file)

        return ZipFileReader(
            Pointer(to=self.file),
            name._compressed_size,
            name._uncompressed_size,
            name._compression_method,
            name._crc32.value(),
        )

    fn open(
        mut self, name: String, mode: String
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        return self.open(self.getinfo(name), mode)

    fn open_to_write(
        mut self,
        name: String,
        mode: String,
        compression_method: UInt16 = ZIP_STORED,
        compresslevel: Int32 = -1,  # Z_DEFAULT_COMPRESSION
    ) raises -> ZipFileWriter[__origin_of(self)]:
        if mode != "w":
            raise Error("Only write mode is the only mode supported")
        if (
            compression_method != ZIP_STORED
            and compression_method != ZIP_DEFLATED
        ):
            raise Error(
                "Only ZIP_STORED and ZIP_DEFLATED compression methods are"
                " supported"
            )
        return ZipFileWriter(
            Pointer(to=self), name, mode, compression_method, compresslevel
        )

    fn writestr(
        mut self,
        arcname: String,
        data: String,
        compression_method: UInt16 = ZIP_STORED,
        compresslevel: Int32 = -1,  # Z_DEFAULT_COMPRESSION
    ) raises:
        # Some streaming would be nice here
        file_handle = self.open_to_write(
            arcname, "w", compression_method, compresslevel
        )
        file_handle.write(data.as_bytes())
        file_handle.close()

    fn read(mut self, name: String) raises -> List[UInt8]:
        """Read and return the bytes of a file in the archive."""
        file_reader = self.open(name, "r")
        return file_reader.read()

    fn getinfo(mut self, name: String) raises -> ZipInfo:
        # We need to seek to the start of the header
        self._start_reading_central_directory_file_headers()
        while True:
            header = self._read_next_central_directory_file_header()
            if header is None:
                break
            if String(bytes=header.value().filename) == name:
                return ZipInfo(header.value())
        raise Error(String("File ") + name + " not found in zip file")

    fn _start_reading_central_directory_file_headers(mut self) raises:
        _ = self.file.seek(
            UInt64(self.end_of_central_directory.offset_of_starting_disk_number)
        )

    fn _read_next_central_directory_file_header(
        mut self,
    ) raises -> Optional[CentralDirectoryFileHeader]:
        if (
            self.file.seek(0, os.SEEK_CUR)
            >= self.end_of_central_directory_start
        ):
            return None
        return CentralDirectoryFileHeader(self.file)

    fn infolist(mut self) raises -> List[ZipInfo]:
        self._start_reading_central_directory_file_headers()

        result = List[ZipInfo]()
        while True:
            header = self._read_next_central_directory_file_header()
            if header is None:
                break
            result.append(ZipInfo(header.value()))
        return result
