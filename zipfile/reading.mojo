"""This module implement reading a zip file in Mojo. It follows the Python api, but will have less features.
Notably, we wont implement any storage option other than ZIP_STORED
"""
from os import PathLike
from builtin.file import FileHandle
from .read_values import read_zip_value
from .utils import _lists_are_equal
from .metadata import LocalFileHeader, CentralDirectoryFileHeader, EndOfCentralDirectoryRecord
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

    def __init__(out self, header: CentralDirectoryFileHeader):
        self.filename = String(bytes=header.filename)

    fn is_dir(self) -> Bool:
        return self.filename.endswith("/")

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

    fn infolist(self) raises -> List[ZipInfo]:
        start = self.file.seek(UInt64(self.end_of_central_directory.offset_of_starting_disk_number))

        result = List[ZipInfo]()
        while start < self.end_of_central_directory_start:
            header = CentralDirectoryFileHeader(self.file)
            result.append(ZipInfo(header))
            start = self.file.seek(0, os.SEEK_CUR)
        return result

        
        

