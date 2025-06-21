from sys import ffi
from .constants import adler32_type, crc32_type, Bytef, uLong
from .zlib_shared_object import get_zlib_dl_handle


fn adler32(data: Span[UInt8], value: UInt64 = 1) raises -> UInt64:
    """Computes an Adler-32 checksum of data.

    Args:
        data: The data to compute the checksum for (as a Span).
        value: Starting value of the checksum (default: 1).

    Returns:
        An unsigned 32-bit integer representing the Adler-32 checksum.
    """
    var handle = get_zlib_dl_handle()
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


fn crc32(data: Span[UInt8], value: UInt32 = 0) -> UInt32:
    """Computes a CRC-32 checksum of data.

    This function implements the same CRC-32 algorithm that was previously in the CRC32 struct.
    It follows the same algorithm used in the zipfile module in Python.
    Reference: https://github.com/python/cpython/blob/main/Modules/binascii.c#L739

    Args:
        data: The data to compute the checksum for (as a Span)
        value: Starting value of the checksum (default: 0)

    Returns:
        An unsigned 32-bit integer representing the CRC-32 checksum
    """
    # Initialize CRC with inverted starting value (CRC-32 starts with 0xFFFFFFFF)
    var crc = ~value

    # Process each byte
    for byte in data:
        crc = CRC32Table[(crc ^ UInt32(byte)) & UInt32(0xFF)] ^ (crc >> 8)

    # Return final CRC (inverted)
    return ~crc


fn crc32_update(data: Span[UInt8], crc: UInt32) -> UInt32:
    """Update an existing CRC-32 checksum with new data.

    This function allows for incremental CRC-32 calculation, which is useful
    for processing data in chunks. The intermediate CRC value should be passed
    as the second argument.

    Args:
        data: The new data to include in the checksum
        crc: The current CRC-32 value (from previous calculations)

    Returns:
        The updated CRC-32 checksum
    """
    # Process each byte with the current CRC
    var current_crc = ~crc  # Invert for processing

    for byte in data:
        current_crc = CRC32Table[
            (current_crc ^ UInt32(byte)) & UInt32(0xFF)
        ] ^ (current_crc >> 8)

    # Return inverted result (but don't finalize yet)
    return ~current_crc
