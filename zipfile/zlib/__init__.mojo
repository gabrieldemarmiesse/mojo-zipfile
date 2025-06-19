from sys import ffi
from .constants import adler32_type, Bytef, uLong
from .compression import _get_libz_path


fn adler32(data: List[UInt8], value: UInt64 = 1) raises -> UInt64:
    """Computes an Adler-32 checksum of data.

    Args:
        data: The data to compute the checksum for
        value: Starting value of the checksum (default: 1)

    Returns:
        An unsigned 32-bit integer representing the Adler-32 checksum
    """
    var handle = ffi.DLHandle(_get_libz_path())
    var adler32_fn = handle.get_function[adler32_type]("adler32")

    var result = adler32_fn(uLong(value), data.unsafe_ptr(), UInt32(len(data)))

    # Ensure result is treated as unsigned 32-bit
    return UInt64(result) & 0xFFFFFFFF


fn adler32(data: Span[UInt8], value: UInt64 = 1) raises -> UInt64:
    """Computes an Adler-32 checksum of data.

    Args:
        data: The data to compute the checksum for (as a Span)
        value: Starting value of the checksum (default: 1)

    Returns:
        An unsigned 32-bit integer representing the Adler-32 checksum
    """
    var handle = ffi.DLHandle(_get_libz_path())
    var adler32_fn = handle.get_function[adler32_type]("adler32")

    var result = adler32_fn(uLong(value), data.unsafe_ptr(), UInt32(len(data)))

    # Ensure result is treated as unsigned 32-bit
    return UInt64(result) & 0xFFFFFFFF
