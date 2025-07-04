from os import PathLike
from builtin.file import FileHandle
import os
from .utils import _lists_are_equal
from .metadata import (
    LocalFileHeader,
    CentralDirectoryFileHeader,
    EndOfCentralDirectoryRecord,
    Zip64EndOfCentralDirectoryRecord,
    Zip64EndOfCentralDirectoryLocator,
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
    var zip64_end_of_central_directory: Optional[
        Zip64EndOfCentralDirectoryRecord
    ]
    var allow_zip64: Bool

    fn __init__[
        FileNameType: PathLike
    ](
        out self, filename: FileNameType, mode: String, allow_zip64: Bool = True
    ) raises:
        self.file = open(filename, mode)
        if mode not in String("r", "w"):
            raise Error("Only read and write modes are suported")
        self.mode = mode
        self.allow_zip64 = allow_zip64
        self.central_directory_files_headers = List[
            CentralDirectoryFileHeader
        ]()
        self.zip64_end_of_central_directory = None
        if mode == "r":
            self.file_size = self.file.seek(0, os.SEEK_END)
            self.end_of_central_directory_start = 0  # Initialize with default

            # Initialize with default values
            self.end_of_central_directory = EndOfCentralDirectoryRecord(
                number_of_this_disk=0,
                number_of_the_disk_with_the_start_of_the_central_directory=0,
                total_number_of_entries_in_the_central_directory_on_this_disk=0,
                total_number_of_entries_in_the_central_directory=0,
                size_of_the_central_directory=0,
                offset_of_starting_disk_number=0,
                zip_file_comment=List[UInt8](),
            )

            # Look for ZIP64 end of central directory locator first
            self._try_read_zip64_records()

            # If ZIP64 wasn't found, try regular end of central directory
            if not self.zip64_end_of_central_directory:
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
        self.allow_zip64 = existing.allow_zip64
        self.end_of_central_directory_start = (
            existing.end_of_central_directory_start
        )
        self.end_of_central_directory = existing.end_of_central_directory^
        self.file_size = existing.file_size
        self.central_directory_files_headers = (
            existing.central_directory_files_headers^
        )
        self.zip64_end_of_central_directory = (
            existing.zip64_end_of_central_directory^
        )

    fn __enter__(ref self) -> ref [__origin_of(self)] ZipFile:
        return self

    fn __exit__(mut self) raises:
        self.close()

    fn close(mut self) raises:
        if self.mode == "w":
            num_entries = len(self.central_directory_files_headers)
            if num_entries > 0xFFFF:
                if not self.allow_zip64:
                    raise Error(
                        "Number of entries exceeds 65535 limit and allowZip64"
                        " is False"
                    )
                # ZIP64 format will be used automatically when needed
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk = UInt16(
                num_entries
            )
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory = UInt16(
                num_entries
            )
            current_pos = self.file.seek(0, os.SEEK_CUR)
            if current_pos > 0xFFFFFFFF:
                if not self.allow_zip64:
                    raise Error(
                        "Central directory offset exceeds 4GB limit and"
                        " allowZip64 is False"
                    )
                # ZIP64 format will be used automatically when needed
            self.end_of_central_directory.offset_of_starting_disk_number = (
                UInt64(current_pos)
            )

            for header in self.central_directory_files_headers:
                _ = header.write_to_file(self.file, self.allow_zip64)

            current_pos = self.file.seek(0, os.SEEK_CUR)
            central_dir_size = (
                UInt64(current_pos)
                - self.end_of_central_directory.offset_of_starting_disk_number
            )
            if central_dir_size > 0xFFFFFFFF:
                if not self.allow_zip64:
                    raise Error(
                        "Central directory size exceeds 4GB limit and"
                        " allowZip64 is False"
                    )
                # ZIP64 format will be used automatically when needed
            self.end_of_central_directory.size_of_the_central_directory = (
                central_dir_size
            )

            _ = self.end_of_central_directory.write_to_file(
                self.file, self.allow_zip64
            )
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
        force_zip64: Bool = False,
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
            Pointer(to=self),
            name,
            mode,
            compression_method,
            compresslevel,
            force_zip64,
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
        if self.zip64_end_of_central_directory:
            _ = self.file.seek(
                UInt64(
                    self.zip64_end_of_central_directory.value().offset_of_starting_disk_number
                )
            )
        else:
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

    fn _try_read_zip64_records(mut self) raises:
        """Try to read ZIP64 end of central directory records."""
        # Look for ZIP64 end of central directory locator
        # In ZIP64 files, the structure at the end is:
        # - ZIP64 End of Central Directory Record
        # - ZIP64 End of Central Directory Locator (20 bytes)
        # - End of Central Directory Record (22 bytes)
        # So the ZIP64 locator is at file_size - 42
        if self.file_size < 42:
            return

        try:
            # Try to read ZIP64 end of central directory locator
            _ = self.file.seek(self.file_size - 42)
            var locator = Zip64EndOfCentralDirectoryLocator(self.file)

            # Now read the ZIP64 end of central directory record
            _ = self.file.seek(
                locator.relative_offset_of_the_zip64_end_of_central_directory_record
            )
            var zip64_eocd = Zip64EndOfCentralDirectoryRecord(self.file)

            # Store the ZIP64 record and create a compatible regular EOCD
            self.zip64_end_of_central_directory = zip64_eocd

            # Create a regular EOCD that uses the ZIP64 values
            self.end_of_central_directory = EndOfCentralDirectoryRecord(
                number_of_this_disk=UInt16(
                    min(zip64_eocd.number_of_this_disk, 0xFFFF)
                ),
                number_of_the_disk_with_the_start_of_the_central_directory=UInt16(
                    min(
                        zip64_eocd.number_of_the_disk_with_the_start_of_the_central_directory,
                        0xFFFF,
                    )
                ),
                total_number_of_entries_in_the_central_directory_on_this_disk=UInt16(
                    min(
                        zip64_eocd.total_number_of_entries_in_the_central_directory_on_this_disk,
                        0xFFFF,
                    )
                ),
                total_number_of_entries_in_the_central_directory=UInt16(
                    min(
                        zip64_eocd.total_number_of_entries_in_the_central_directory,
                        0xFFFF,
                    )
                ),
                size_of_the_central_directory=zip64_eocd.size_of_the_central_directory,
                offset_of_starting_disk_number=zip64_eocd.offset_of_starting_disk_number,
                zip_file_comment=List[UInt8](),
            )

            # Calculate the end of central directory start position
            self.end_of_central_directory_start = (
                zip64_eocd.offset_of_starting_disk_number
                + zip64_eocd.size_of_the_central_directory
            )

        except:
            # ZIP64 records not found or invalid, will fall back to regular EOCD
            pass
