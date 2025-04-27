"""This module implement reading a zip file in Mojo. It follows the Python api, but will have less features.
Notably, we wont implement any storage option other than ZIP_STORED
"""
from os import PathLike
from builtin.file import FileHandle
from .read_values import read_zip_value
from .utils import _lists_are_equal
from .metadata import LocalFileHeader


def is_zipfile[FileNameType: PathLike](filename: FileNameType) -> Bool:
    with open(filename, "rb") as fp:
        # For now we only check the first 4 bytes, it should be good enough
        # to check if the file is a zip file
        header = fp.read_bytes(4)
        if _lists_are_equal(header, LocalFileHeader.SIGNATURE):
            return True
        else:
            return False


struct ZipFile:
    var file: FileHandle
    var mode: String

    fn __init__[FileNameType: PathLike](out self, filename: FileNameType, mode: String) raises:
        self.file = open(filename, mode)
        if mode != "r":
            raise Error("Only read mode is the only mode supported")
        self.mode = mode

    fn __moveinit__(out self, owned existing: Self):
        self.file = existing.file^
        self.mode = existing.mode
        
    fn __enter__(owned self) -> ZipFile:
        return self^

    fn __exit__(mut self) raises:
        self.file.close()

    

        

        
        

