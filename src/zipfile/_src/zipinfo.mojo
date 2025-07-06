from .metadata import CentralDirectoryFileHeader
from collections import Optional


struct ZipInfo(Copyable, Movable):
    var filename: String
    var _start_of_header: UInt64
    var _compressed_size: UInt64
    var _uncompressed_size: UInt64
    var _compression: UInt16
    var _crc32: Optional[UInt32]

    def __init__(out self, header: CentralDirectoryFileHeader):
        self.filename = String(bytes=header.filename)
        self._start_of_header = UInt64(header.relative_offset_of_local_header)
        self._compressed_size = UInt64(header.compressed_size)
        self._uncompressed_size = UInt64(header.uncompressed_size)
        self._compression = header.compression
        self._crc32 = header.crc32

    fn is_dir(self) -> Bool:
        return self.filename.endswith("/")
