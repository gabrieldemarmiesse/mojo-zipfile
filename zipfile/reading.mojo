"""This module implement reading a zip file in Mojo. It follows the Python api, but will have less features.
Notably, we wont implement any storage option other than ZIP_STORED
"""
from os import PathLike
from builtin.file import FileHandle
from .read_write_values import read_zip_value
from .utils import _lists_are_equal
from .metadata import (
    LocalFileHeader,
    CentralDirectoryFileHeader,
    EndOfCentralDirectoryRecord,
    ZIP_STORED,
    GeneralPurposeBitFlag,
)
import os
from .crc_32 import CRC32

def is_zipfile[FileNameType: PathLike](filename: FileNameType) -> Bool:
    with open(filename, "rb") as fp:
        # For now we only check the first 4 bytes, it should be good enough
        # to check if the file is a zip file
        header = fp.read_bytes(4)
        if _lists_are_equal(header, LocalFileHeader.SIGNATURE):
            return True
        else:
            return False


@value
struct ZipInfo:
    var filename: String
    var _start_of_header: UInt64
    var _uncompressed_size: UInt64
    var _compression_method: UInt16
    var _crc32: Optional[UInt32]

    def __init__(out self, header: CentralDirectoryFileHeader):
        self.filename = String(bytes=header.filename)
        self._start_of_header = UInt64(header.relative_offset_of_local_header)
        self._uncompressed_size = UInt64(header.uncompressed_size)
        self._compression_method = header.compression_method
        self._crc32 = header.crc32

    fn is_dir(self) -> Bool:
        return self.filename.endswith("/")


struct ZipFileReader[origin: Origin[mut=True]]:
    var file: Pointer[FileHandle, origin]
    var uncompressed_size: UInt64
    var start: UInt64
    var expected_crc32: UInt32
    var crc32: CRC32

    fn __init__(
        out self, file: Pointer[FileHandle, origin], uncompressed_size: UInt64, expected_crc32: UInt32
    ) raises:
        self.file = file
        self.uncompressed_size = uncompressed_size
        self.start = file[].seek(0, os.SEEK_CUR)
        self.expected_crc32 = expected_crc32
        self.crc32 = CRC32()

    fn _remaining_size(self) raises -> Int:
        end = self.start + self.uncompressed_size

        return Int(end - self.file[].seek(0, os.SEEK_CUR))

    fn read(mut self, owned size: Int = -1) raises -> List[UInt8]:
        if size == -1:
            size = self._remaining_size()
        else:
            size = min(size, self._remaining_size())

        bytes = self.file[].read_bytes(size)
        self.crc32.write(bytes)
        if self._remaining_size() == 0:
            # We are at the end of the file
            computed_crc32 = self.crc32.get_final_crc()
            if computed_crc32 != self.expected_crc32:
                raise Error("CRC32 mismatch, expected: " + String(self.expected_crc32) + ", got: " + String(computed_crc32))
        return bytes


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
        self.central_directory_files_headers = List[CentralDirectoryFileHeader]()
        if mode == "r":
            self.file_size = self.file.seek(0, os.SEEK_END)

            # Let's assume that the file does not contains any comment.
            # Later on we can do the signature search.
            self.end_of_central_directory_start = self.file.seek(
                self.file_size - 22
            )
            self.end_of_central_directory = (
                EndOfCentralDirectoryRecord(self.file)
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
        self.central_directory_files_headers = existing.central_directory_files_headers^

    fn __enter__(ref self) -> ref [__origin_of(self)] ZipFile:
        return self

    fn __exit__(mut self) raises:
        self.close()

    fn close(mut self) raises:
        if self.mode == "w":
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk = len(self.central_directory_files_headers)
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory = len(self.central_directory_files_headers)
            self.end_of_central_directory.offset_of_starting_disk_number = UInt32(self.file.seek(0, os.SEEK_CUR))
            
            for header in self.central_directory_files_headers:
                _ = header[].write_to_file(self.file)

            self.end_of_central_directory.size_of_the_central_directory = UInt32(
                UInt32(self.file.seek(0, os.SEEK_CUR)) - self.end_of_central_directory.offset_of_starting_disk_number
            )

            _ = self.end_of_central_directory.write_to_file(self.file)
        self.file.close()

    fn open(
        mut self, name: ZipInfo, mode: String
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        if mode != "r":
            raise Error("Only read mode is the only mode supported")
        if name._compression_method != ZIP_STORED:
            raise Error("Only ZIP_STORED compression method is supported")
        # We need to seek to the start of the header
        _ = self.file.seek(name._start_of_header)
        _ = LocalFileHeader(self.file)

        return ZipFileReader(Pointer(to=self.file), name._uncompressed_size, name._crc32.value())

    fn open(
        mut self, name: String, mode: String
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        return self.open(self.getinfo(name), mode)

    fn writestr(mut self, arcname: String, data: String) raises:
        # Some streaming would be nice here
        bytes = data.as_bytes()

        local_file_header = LocalFileHeader(
            version_needed_to_extract=20,
            general_purpose_bit_flag=GeneralPurposeBitFlag(strings_are_utf8=True),
            compression_method=ZIP_STORED,
            last_mod_file_time=0,
            last_mod_file_date=0,
            crc32=CRC32.get_crc_32(bytes),
            compressed_size=len(bytes),
            uncompressed_size=len(bytes),
            filename=List[UInt8](arcname.as_bytes()),
            extra_field=List[UInt8](),
        )
        _ = local_file_header.write_to_file(self.file)
        self.central_directory_files_headers.append(CentralDirectoryFileHeader(local_file_header))
        
        self.file.write_bytes(bytes)

        # Add info somewhere so we can put it in the central directory later

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
            UInt64(
                self.end_of_central_directory.offset_of_starting_disk_number
            )
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
