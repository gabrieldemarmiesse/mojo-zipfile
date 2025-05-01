"""This module implement reading a zip file in Mojo. It follows the Python api, but will have less features.
Notably, we wont implement any storage option other than ZIP_STORED
"""
from os import PathLike
from builtin.file import FileHandle
from .read_values import read_zip_value
from .utils import _lists_are_equal
from .metadata import LocalFileHeader, CentralDirectoryFileHeader, EndOfCentralDirectoryRecord, ZIP_STORED
import os

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

    def __init__(out self, header: CentralDirectoryFileHeader):
        self.filename = String(bytes=header.filename)
        self._start_of_header = UInt64(header.relative_offset_of_local_header)
        self._uncompressed_size = UInt64(header.uncompressed_size)
        self._compression_method = header.compression_method

    fn is_dir(self) -> Bool:
        return self.filename.endswith("/")

struct ZipFileReader[origin: Origin[mut=True]]:
    var file: Pointer[FileHandle, origin]
    var uncompressed_size: UInt64
    var start: UInt64

    fn __init__(out self, file: Pointer[FileHandle, origin], uncompressed_size: UInt64) raises:
        self.file = file
        self.uncompressed_size = uncompressed_size
        self.start = file[].seek(0, os.SEEK_CUR)

    fn _remaining_size(self) raises -> Int:
        end = self.start + self.uncompressed_size

        return Int(end - self.file[].seek(0, os.SEEK_CUR))

    fn read(mut self, owned size: Int = -1) raises -> List[UInt8]:
        if size == -1:
            size = self._remaining_size()
        else:
            size = min(size, self._remaining_size())

        return self.file[].read_bytes(size)


# Negactive offsets are broken in Mojo for seek
struct ZipFile:
    var file: FileHandle
    var mode: String
    var end_of_central_directory_start: UInt64
    var file_size: UInt64
    var end_of_central_directory: EndOfCentralDirectoryRecord

    fn __init__[FileNameType: PathLike](out self, filename: FileNameType, mode: String) raises:
        self.file = open(filename, mode)
        if mode != "r":
            raise Error("Only read mode is the only mode supported")
        self.mode = mode
        self.file_size = self.file.seek(0, os.SEEK_END)

        # Let's assume that the file does not contains any comment.
        # Later on we can do the signature search.
        self.end_of_central_directory_start = self.file.seek(self.file_size-22)
        self.end_of_central_directory = EndOfCentralDirectoryRecord(self.file)

    fn __moveinit__(out self, owned existing: Self):
        self.file = existing.file^
        self.mode = existing.mode
        self.end_of_central_directory_start = existing.end_of_central_directory_start
        self.end_of_central_directory = existing.end_of_central_directory^
        self.file_size = existing.file_size

    fn __enter__(ref self) -> ref [__origin_of(self)] ZipFile:
        return self

    fn __exit__(mut self) raises:
        self.close()

    fn close(mut self) raises:
        self.file.close()

    fn open(mut self, name: ZipInfo, mode: String) raises -> ZipFileReader[__origin_of(self.file)]:
        if mode != "r":
            raise Error("Only read mode is the only mode supported")
        if name._compression_method != ZIP_STORED:
            raise Error("Only ZIP_STORED compression method is supported")
        # We need to seek to the start of the header
        _ = self.file.seek(name._start_of_header)
        _ = LocalFileHeader(self.file)

        return ZipFileReader(Pointer(to=self.file), name._uncompressed_size)

    fn open(mut self, name: String, mode: String) raises -> ZipFileReader[__origin_of(self.file)]:
        return self.open(self.getinfo(name), mode)
    
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
        _ = self.file.seek(UInt64(self.end_of_central_directory.offset_of_starting_disk_number))

    fn _read_next_central_directory_file_header(mut self) raises -> Optional[CentralDirectoryFileHeader]:
        if self.file.seek(0, os.SEEK_CUR) >= self.end_of_central_directory_start:
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
