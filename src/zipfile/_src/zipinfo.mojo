from .metadata import CentralDirectoryFileHeader, GeneralPurposeBitFlag
from collections import Optional


struct ZipInfo(Copyable, Movable):
    var filename: String
    var _start_of_header: UInt64
    var _compressed_size: UInt64
    var _uncompressed_size: UInt64
    var _compression: UInt16
    var _crc32: Optional[UInt32]
    var _external_attr: UInt16

    def __init__(out self, header: CentralDirectoryFileHeader):
        self.filename = String(bytes=header.filename)
        self._start_of_header = UInt64(header.relative_offset_of_local_header)
        self._compressed_size = UInt64(header.compressed_size)
        self._uncompressed_size = UInt64(header.uncompressed_size)
        self._compression = header.compression
        self._crc32 = header.crc32
        self._external_attr = 0

    fn is_dir(self) -> Bool:
        return self.filename.endswith("/")

    @staticmethod
    fn _create_directory(dirname: String, mode: UInt16) raises -> ZipInfo:
        """Create a ZipInfo object for a directory.

        Arguments:
            dirname: The directory name (should end with '/').
            mode: Unix file permissions for the directory.

        Returns:
            A ZipInfo object configured for a directory entry.
        """
        # Convert filename to List[UInt8]
        var filename_bytes = List[UInt8]()
        for byte in dirname.as_bytes():
            filename_bytes.append(byte)

        # Create a dummy header for initialization
        var dummy_header = CentralDirectoryFileHeader(
            version_made_by=20,
            version_needed_to_extract=20,
            general_purpose_bit_flag=GeneralPurposeBitFlag(
                strings_are_utf8=True
            ),
            compression=0,  # ZIP_STORED
            last_mod_file_time=0,
            last_mod_file_date=0,
            crc32=0,
            compressed_size=0,
            uncompressed_size=0,
            disk_number_start=0,
            internal_file_attributes=0,
            external_file_attributes=0,
            relative_offset_of_local_header=0,
            filename=filename_bytes,
            extra_field=List[UInt8](),
            file_comment=List[UInt8](),
        )

        var zinfo = ZipInfo(dummy_header)
        zinfo._external_attr = mode
        return zinfo
