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
    ZIP64_VERSION,
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
    var allowZip64: Bool
    var compression: UInt16
    var compresslevel: Optional[Int32]

    fn __init__[
        FileNameType: PathLike
    ](
        out self,
        filename: FileNameType,
        mode: String,
        compression: UInt16 = ZIP_STORED,
        allowZip64: Bool = True,
        compresslevel: Optional[Int32] = None,
    ) raises:
        self.file = open(filename, mode)
        if mode not in String("r", "w"):
            raise Error("Only read and write modes are suported")
        self.mode = mode
        self.allowZip64 = allowZip64
        self.compression = compression
        self.compresslevel = compresslevel
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
        self.allowZip64 = existing.allowZip64
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
        self.compression = existing.compression
        self.compresslevel = existing.compresslevel^

    fn __enter__(ref self) -> ref [__origin_of(self)] ZipFile:
        return self

    fn __exit__(mut self) raises:
        self.close()

    fn close(mut self) raises:
        if self.mode == "w":
            num_entries = len(self.central_directory_files_headers)
            if num_entries > 0xFFFF:
                if not self.allowZip64:
                    raise Error(
                        "Number of entries exceeds 65535 limit and allowZip64"
                        " is False"
                    )

            # Set values in end of central directory record
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk = UInt16(
                min(num_entries, 0xFFFF)
            )
            self.end_of_central_directory.total_number_of_entries_in_the_central_directory = UInt16(
                min(num_entries, 0xFFFF)
            )

            current_pos = self.file.seek(0, os.SEEK_CUR)
            if current_pos > 0xFFFFFFFF:
                if not self.allowZip64:
                    raise Error(
                        "Central directory offset exceeds 4GB limit and"
                        " allowZip64 is False"
                    )
            self.end_of_central_directory.offset_of_starting_disk_number = (
                UInt64(current_pos)
            )

            for header in self.central_directory_files_headers:
                _ = header.write_to_file(self.file, self.allowZip64)

            current_pos = self.file.seek(0, os.SEEK_CUR)
            central_dir_size = (
                UInt64(current_pos)
                - self.end_of_central_directory.offset_of_starting_disk_number
            )
            if central_dir_size > 0xFFFFFFFF:
                if not self.allowZip64:
                    raise Error(
                        "Central directory size exceeds 4GB limit and"
                        " allowZip64 is False"
                    )
            self.end_of_central_directory.size_of_the_central_directory = (
                central_dir_size
            )

            # Check if we need ZIP64 format
            var needs_zip64 = (
                num_entries > 0xFFFF
                or central_dir_size > 0xFFFFFFFF
                or self.end_of_central_directory.offset_of_starting_disk_number
                > 0xFFFFFFFF
            )

            if needs_zip64:
                # Write ZIP64 End of Central Directory Record
                var zip64_eocd_offset = self.file.seek(0, os.SEEK_CUR)
                var zip64_eocd = Zip64EndOfCentralDirectoryRecord(
                    version_made_by=ZIP64_VERSION,
                    version_needed_to_extract=ZIP64_VERSION,
                    number_of_this_disk=0,
                    number_of_the_disk_with_the_start_of_the_central_directory=0,
                    total_number_of_entries_in_the_central_directory_on_this_disk=UInt64(
                        num_entries
                    ),
                    total_number_of_entries_in_the_central_directory=UInt64(
                        num_entries
                    ),
                    size_of_the_central_directory=central_dir_size,
                    offset_of_starting_disk_number=self.end_of_central_directory.offset_of_starting_disk_number,
                    zip64_extensible_data_sector=List[UInt8](),
                )
                _ = zip64_eocd.write_to_file(self.file)

                # Write ZIP64 End of Central Directory Locator
                var zip64_locator = Zip64EndOfCentralDirectoryLocator(
                    number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory=0,
                    relative_offset_of_the_zip64_end_of_central_directory_record=UInt64(
                        zip64_eocd_offset
                    ),
                    total_number_of_disks=1,
                )
                _ = zip64_locator.write_to_file(self.file)

            # Always write the regular End of Central Directory Record
            _ = self.end_of_central_directory.write_to_file(
                self.file, self.allowZip64
            )
        self.file.close()

    # Default when no mode is specified
    fn open(
        mut self, name: String
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        return self.open(self.getinfo(name), "r")

    fn open(
        mut self, name: ZipInfo
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        return self.open(name, "r")

    fn open(
        mut self, name: ZipInfo, mode: StringLiteral["r".value]
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        if self.mode != "r":
            raise Error(
                "You need to use `ZipFile(..., mode='r')` to use open(mode='r')"
            )
        if (
            name._compression != ZIP_STORED
            and name._compression != ZIP_DEFLATED
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
            name._compression,
            name._crc32.value(),
        )

    fn open(
        mut self, name: String, mode: StringLiteral["r".value]
    ) raises -> ZipFileReader[__origin_of(self.file)]:
        return self.open(self.getinfo(name), mode)

    fn open(
        mut self,
        name: String,
        mode: StringLiteral["w".value],
        *,
        force_zip64: Bool = False,
    ) raises -> ZipFileWriter[__origin_of(self)]:
        if self.mode != "w":
            raise Error(
                "You need to use `ZipFile(..., mode='w')` to use open(mode='w')"
            )
        if self.compression != ZIP_STORED and self.compression != ZIP_DEFLATED:
            raise Error(
                "Only ZIP_STORED and ZIP_DEFLATED compression methods are"
                " supported"
            )
        return ZipFileWriter(
            Pointer(to=self),
            name,
            mode,
            self.compression,
            self.compresslevel.value() if self.compresslevel else -1,
            force_zip64,
        )

    fn writestr(
        mut self,
        arcname: String,
        data: String,
    ) raises:
        # Some streaming would be nice here
        file_handle = self.open(arcname, "w")
        file_handle.write(data.as_bytes())
        file_handle.close()

    fn mkdir(mut self, zinfo_or_directory: String, mode: UInt16 = 0o777) raises:
        """Create a directory inside the ZIP archive.

        Arguments:
            zinfo_or_directory: The directory name to create.
            mode: The Unix file permissions for the directory (default 0o777).

        Raises:
            Error: If the archive is not open for writing.
        """
        if self.mode != "w":
            raise Error("mkdir() requires mode 'w'")

        # Ensure directory name ends with '/'
        var dirname = zinfo_or_directory
        if not dirname.endswith("/"):
            dirname = dirname + "/"

        # Create a ZipInfo for the directory
        var zinfo = ZipInfo._create_directory(dirname, mode)

        # Write the directory entry
        self._write_directory(zinfo)

    fn mkdir(
        mut self, zinfo_or_directory: ZipInfo, mode: UInt16 = 0o777
    ) raises:
        """Create a directory inside the ZIP archive using a ZipInfo object.

        Arguments:
            zinfo_or_directory: The ZipInfo object for the directory.
            mode: The Unix file permissions (ignored when ZipInfo is provided).

        Raises:
            Error: If the archive is not open for writing.
        """
        if self.mode != "w":
            raise Error("mkdir() requires mode 'w'")

        # Ensure the ZipInfo represents a directory
        var zinfo = zinfo_or_directory
        if not zinfo.is_dir():
            raise Error("ZipInfo filename must end with '/'")

        # Write the directory entry
        self._write_directory(zinfo)

    fn _write_directory(mut self, zinfo: ZipInfo) raises:
        """Internal method to write a directory entry to the archive."""
        # Record the position where we're writing the local file header
        var header_offset = self.file.seek(0, os.SEEK_CUR)

        # Create local file header for directory
        var filename_bytes = List[UInt8]()
        for byte in zinfo.filename.as_bytes():
            filename_bytes.append(byte)

        var local_header = LocalFileHeader(
            version_needed_to_extract=20,
            general_purpose_bit_flag=GeneralPurposeBitFlag(
                strings_are_utf8=True
            ),
            compression=ZIP_STORED,  # Directories are always stored
            last_mod_file_time=0,
            last_mod_file_date=0,
            crc32=0,  # Directories have CRC32 of 0
            compressed_size=0,  # Directories have size 0
            uncompressed_size=0,  # Directories have size 0
            filename=filename_bytes,
            extra_field=List[UInt8](),
        )

        # Write the local file header
        _ = local_header.write_to_file(self.file, self.allowZip64)

        # Create central directory entry
        var central_header = CentralDirectoryFileHeader(
            local_header, header_offset
        )

        # Set external attributes for directory (MS-DOS directory attribute)
        # The external attributes field:
        # - Lower byte: MS-DOS attributes (0x10 = directory)
        # - Upper 2 bytes: Unix file permissions
        central_header.external_file_attributes = (
            UInt32(zinfo._external_attr) << 16
        ) | 0x10

        # Add to central directory
        self.central_directory_files_headers.append(central_header)

    fn read(mut self, name: String) raises -> List[UInt8]:
        """Read and return the bytes of a file in the archive."""
        file_reader = self.open(name, "r")
        return file_reader.read()

    fn extract(
        mut self, member: String, path: Optional[String] = None
    ) raises -> String:
        """Extract a member from the archive to the file system.

        Arguments:
            member: The name of the file to extract.
            path: The directory to extract to (defaults to current directory).

        Returns:
            The normalized path of the extracted file.

        Raises:
            Error: If the archive is not open for reading or member not found.
        """
        if self.mode != "r":
            raise Error("extract() requires mode 'r'")

        var info = self.getinfo(member)
        return self._extract_member(info, path)

    fn extract(
        mut self, member: ZipInfo, path: Optional[String] = None
    ) raises -> String:
        """Extract a member from the archive to the file system using ZipInfo.

        Arguments:
            member: The ZipInfo object of the file to extract.
            path: The directory to extract to (defaults to current directory).

        Returns:
            The normalized path of the extracted file.

        Raises:
            Error: If the archive is not open for reading.
        """
        if self.mode != "r":
            raise Error("extract() requires mode 'r'")

        return self._extract_member(member, path)

    fn extractall(mut self, path: Optional[String] = None) raises:
        """Extract all members from the archive to the file system.

        Arguments:
            path: The directory to extract to (defaults to current directory).

        Raises:
            Error: If the archive is not open for reading.
        """
        if self.mode != "r":
            raise Error("extractall() requires mode 'r'")

        # Ensure the extraction directory exists
        import os

        if path:
            var extract_dir = path.value()
            os.makedirs(extract_dir, exist_ok=True)

        # Get all members in the archive
        var all_members = self.infolist()

        # Extract each member
        for member in all_members:
            _ = self._extract_member(member, path)

    fn extractall(
        mut self, path: Optional[String], members: List[String]
    ) raises:
        """Extract specified members from the archive to the file system.

        Arguments:
            path: The directory to extract to (defaults to current directory).
            members: List of member names to extract.

        Raises:
            Error: If the archive is not open for reading or member not found.
        """
        if self.mode != "r":
            raise Error("extractall() requires mode 'r'")

        # Ensure the extraction directory exists
        import os

        if path:
            var extract_dir = path.value()
            os.makedirs(extract_dir, exist_ok=True)

        # Extract each specified member
        for member_name in members:
            var info = self.getinfo(member_name)
            _ = self._extract_member(info, path)

    fn extractall(
        mut self, path: Optional[String], members: List[ZipInfo]
    ) raises:
        """Extract specified members from the archive to the file system using ZipInfo objects.

        Arguments:
            path: The directory to extract to (defaults to current directory).
            members: List of ZipInfo objects to extract.

        Raises:
            Error: If the archive is not open for reading.
        """
        if self.mode != "r":
            raise Error("extractall() requires mode 'r'")

        # Ensure the extraction directory exists
        import os

        if path:
            var extract_dir = path.value()
            os.makedirs(extract_dir, exist_ok=True)

        # Extract each specified member
        for member in members:
            _ = self._extract_member(member, path)

    fn _extract_member(
        mut self, info: ZipInfo, path: Optional[String]
    ) raises -> String:
        """Internal method to extract a member to the file system."""
        from pathlib import Path
        import os

        # Sanitize the filename to prevent path traversal attacks
        var target_path = self._sanitize_filename(info.filename)

        # Determine the extraction directory
        var extract_dir: String
        if path:
            extract_dir = path.value()
        else:
            extract_dir = "."  # Default to current directory

        # Build the full target path
        var full_path = Path(extract_dir) / target_path
        var normalized_path = full_path.__str__()

        if info.is_dir():
            # Create directory
            os.makedirs(normalized_path, exist_ok=True)
        else:
            # Create parent directories if they don't exist
            if "/" in normalized_path or "\\" in normalized_path:
                var parent_str = self._get_parent_dir(normalized_path)
                if parent_str != "":
                    os.makedirs(parent_str, exist_ok=True)

            # Extract the file content
            var file_data = self.read(info.filename)

            # Write the file to disk
            with open(normalized_path, "w") as output_file:
                output_file.write_bytes(file_data)

        return normalized_path

    fn _get_parent_dir(self, file_path: String) -> String:
        """Get the parent directory of a file path."""
        var parts = file_path.split("/")
        if len(parts) <= 1:
            # Try backslash for Windows paths
            parts = file_path.split("\\")
            if len(parts) <= 1:
                return ""

        # Remove the last part (filename) and join the rest
        var parent_parts = List[String]()
        for i in range(len(parts) - 1):
            parent_parts.append(parts[i])

        var result = ""
        for i in range(len(parent_parts)):
            if i > 0:
                result += "/"
            result += parent_parts[i]

        return result

    fn _sanitize_filename(self, filename: String) -> String:
        """Sanitize filename to prevent path traversal attacks."""
        var sanitized = filename

        # Remove absolute path components
        if sanitized.startswith("/"):
            sanitized = sanitized[1:]

        # Remove drive letters on Windows (C:, D:, etc.)
        if len(sanitized) >= 2 and sanitized[1] == ":":
            sanitized = sanitized[2:]

        # Remove leading backslashes
        while sanitized.startswith("\\"):
            sanitized = sanitized[1:]

        # Replace ".." components with safe names
        var parts = sanitized.split("/")
        var safe_parts = List[String]()
        for i in range(len(parts)):
            var part = parts[i]
            if part != ".." and part != ".":
                safe_parts.append(part)

        # Join the parts back together
        var result = ""
        for i in range(len(safe_parts)):
            if i > 0:
                result += "/"
            result += safe_parts[i]

        return result

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

    fn namelist(mut self) raises -> List[String]:
        """Return a list of filenames in the archive."""
        self._start_reading_central_directory_file_headers()

        result = List[String]()
        while True:
            header = self._read_next_central_directory_file_header()
            if header is None:
                break
            result.append(String(bytes=header.value().filename))
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
