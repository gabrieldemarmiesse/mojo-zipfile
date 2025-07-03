from os import PathLike
from builtin.file import FileHandle
import os
from .utils import _lists_are_equal
from .metadata import (
    LocalFileHeader,
    CentralDirectoryFileHeader,
    EndOfCentralDirectoryRecord,
    ZIP_STORED,
    ZIP_DEFLATED,
    GeneralPurposeBitFlag,
)
from .read_write_values import write_zip_value
from .zipfile_reader import ZipFileReader
from .zipfile_writer import ZipFileWriter
from .zipinfo import ZipInfo
import zlib


def is_zipfile[FileNameType: PathLike](filename: FileNameType) -> Bool:
    with open(filename, "r") as fp:
        # For now we only check the first 4 bytes, it should be good enough
        # to check if the file is a zip file
        header = fp.read_bytes(4)
        if _lists_are_equal(header, LocalFileHeader.SIGNATURE):
            return True
        else:
            return False


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
            num_entries = len(self.central_directory_files_headers)
            if num_entries > 0xFFFF:
                raise Error(
                    "Number of entries exceeds 65535 limit - ZIP64 format not"
                    " supported yet"
                )
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk = UInt16(
                num_entries
            )
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory = UInt16(
                num_entries
            )
            current_pos = self.file.seek(0, os.SEEK_CUR)
            if current_pos > 0xFFFFFFFF:
                raise Error(
                    "Central directory offset exceeds 4GB limit - ZIP64 format"
                    " not supported yet"
                )
            self.end_of_central_directory.offset_of_starting_disk_number = (
                UInt64(current_pos)
            )

            for header in self.central_directory_files_headers:
                _ = header.write_to_file(self.file)

            current_pos = self.file.seek(0, os.SEEK_CUR)
            central_dir_size = (
                UInt64(current_pos)
                - self.end_of_central_directory.offset_of_starting_disk_number
            )
            if central_dir_size > 0xFFFFFFFF:
                raise Error(
                    "Central directory size exceeds 4GB limit - ZIP64 format"
                    " not supported yet"
                )
            self.end_of_central_directory.size_of_the_central_directory = (
                central_dir_size
            )

            _ = self.end_of_central_directory.write_to_file(self.file)
        self.file.close()

    fn open_to_read(
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

    fn open_to_read(
        mut self, name: String, mode: String
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        return self.open_to_read(self.getinfo(name), mode)

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
        file_reader = self.open_to_read(name, "r")
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
