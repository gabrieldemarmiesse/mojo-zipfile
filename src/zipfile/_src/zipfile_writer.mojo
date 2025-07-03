from os import abort
from builtin.file import FileHandle
import os
from .metadata import (
    LocalFileHeader,
    CentralDirectoryFileHeader,
    GeneralPurposeBitFlag,
    ZIP_STORED,
    ZIP_DEFLATED,
)
from .read_write_values import write_zip_value
import zlib


struct ZipFileWriter[origin: Origin[mut=True]]:
    var zipfile: Pointer[ZipFile, origin]
    var local_file_header: LocalFileHeader
    var current_crc32: UInt32
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
        self.current_crc32 = 0  # Initialize CRC32 to 0
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
        self.current_crc32 = zlib.crc32(data, self.current_crc32)
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
            # Compress the accumulated data using raw deflate format for ZIP files
            compressed_data = zlib.compress(
                self._uncompressed_buffer,
                level=Int(self._compresslevel),
                wbits=-15,
            )
            self.zipfile[].file.write_bytes(compressed_data)
            self.compressed_size = UInt64(len(compressed_data))

        # We need to write the crc32 and the compressed size
        self.local_file_header.crc32 = self.current_crc32
        if (
            self.compressed_size > 0xFFFFFFFF
            or self.uncompressed_size > 0xFFFFFFFF
        ):
            raise Error(
                "File size exceeds 4GB limit - ZIP64 format not supported yet"
            )
        self.local_file_header.compressed_size = self.compressed_size
        self.local_file_header.uncompressed_size = self.uncompressed_size

        old_position = self.zipfile[].file.seek(0, os.SEEK_CUR)
        _ = self.zipfile[].file.seek(self.crc32_position)
        write_zip_value(self.zipfile[].file, self.local_file_header.crc32)
        write_zip_value(
            self.zipfile[].file, UInt32(self.local_file_header.compressed_size)
        )
        write_zip_value(
            self.zipfile[].file,
            UInt32(self.local_file_header.uncompressed_size),
        )
        _ = self.zipfile[].file.seek(old_position)
        # Create central directory entry with correct header offset
        if self._header_offset > 0xFFFFFFFF:
            raise Error(
                "File offset exceeds 4GB limit - ZIP64 format not supported yet"
            )
        self.zipfile[].central_directory_files_headers.append(
            CentralDirectoryFileHeader(
                self.local_file_header, self._header_offset
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
