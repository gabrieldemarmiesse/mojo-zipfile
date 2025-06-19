from sys import ffi
from .constants import adler32_type, crc32_type, Bytef, uLong
from .compression import _get_libz_path


fn adler32(data: Span[UInt8], value: UInt64 = 1) raises -> UInt64:
    """Computes an Adler-32 checksum of data.

    Args:
        data: The data to compute the checksum for (as a Span).
        value: Starting value of the checksum (default: 1).

    Returns:
        An unsigned 32-bit integer representing the Adler-32 checksum.
    """
    var handle = ffi.DLHandle(_get_libz_path())
    var adler32_fn = handle.get_function[adler32_type]("adler32")

    var result = adler32_fn(uLong(value), data.unsafe_ptr(), UInt32(len(data)))

    # Ensure result is treated as unsigned 32-bit
    return UInt64(result) & 0xFFFFFFFF


fn generate_crc_32_table() -> InlineArray[UInt32, 256]:
    table = InlineArray[UInt32, 256](fill=0)
    for i in range(256):
        crc = UInt32(i)
        for _ in range(8):
            if (crc & 1) != 0:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
        table[i] = crc
    return table


alias CRC32Table = generate_crc_32_table()


struct CRC32:
    """A re-implementation of the CRC-32 algorithm in Mojo.

    It's the same algorithm used in the zipfile module in Python.
    Reference: https://github.com/python/cpython/blob/main/Modules/binascii.c#L739
    """

    var _internal_value: UInt32

    @staticmethod
    fn get_crc_32(data: Span[UInt8]) -> UInt32:
        crc = CRC32()
        crc.write(data)
        return crc.get_final_crc()

    fn __init__(out self):
        self._internal_value = 0xFFFFFFFF

    fn write(mut self, data: Span[UInt8]):
        for byte in data:
            self._internal_value = CRC32Table[
                (self._internal_value ^ UInt32(byte)) & UInt32(0xFF)
            ] ^ (self._internal_value >> 8)

    fn get_final_crc(self) -> UInt32:
        return ~self._internal_value


fn crc32(data: Span[UInt8], value: UInt32 = 0) -> UInt32:
    """Computes a CRC-32 checksum of data.

    Args:
        data: The data to compute the checksum for (as a Span)
        value: Starting value of the checksum (default: 0)

    Returns:
        An unsigned 32-bit integer representing the CRC-32 checksum
    """
    var crc32_struct = CRC32()
    # Set initial value if provided (inverted because CRC32 starts with 0xFFFFFFFF)
    crc32_struct._internal_value = ~value
    crc32_struct.write(data)
    return crc32_struct.get_final_crc()
