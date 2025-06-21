from sys import ffi
from memory import memset_zero, UnsafePointer
from sys import info, exit
import sys
import os
from .constants import (
    ZStream,
    Bytef,
    z_stream_ptr,
    inflateInit2_type,
    inflate_type,
    inflateEnd_type,
    deflateInit2_type,
    deflate_type,
    deflateEnd_type,
    Z_OK,
    Z_STREAM_END,
    Z_NO_FLUSH,
    Z_FINISH,
    Z_DEFAULT_COMPRESSION,
    Z_BEST_COMPRESSION,
    Z_BEST_SPEED,
    Z_DEFLATED,
    Z_DEFAULT_STRATEGY,
    MAX_WBITS,
    DEF_BUF_SIZE,
    log_zlib_result,
)
from .zlib_shared_object import get_zlib_dl_handle


fn compress(
    data: Span[Byte], /, level: Int = -1, wbits: Int = MAX_WBITS
) raises -> List[Byte]:
    """Compress data using zlib compression.

    Args:
        data: The data to compress.
        level: Compression level (0-9, -1 for default).
        wbits: Window bits parameter controlling format and window size
               - Positive values (9-15): zlib format with header and trailer
               - Negative values (-9 to -15): raw deflate format
               - Values 25-31: gzip format.

    Returns:
        Compressed data as List[Byte].
    """
    var handle = get_zlib_dl_handle()

    var deflateInit2 = handle.get_function[deflateInit2_type]("deflateInit2_")
    var deflate_fn = handle.get_function[deflate_type]("deflate")
    var deflateEnd = handle.get_function[deflateEnd_type]("deflateEnd")

    var stream = ZStream(
        next_in=data.unsafe_ptr(),
        avail_in=UInt32(len(data)),
        total_in=0,
        next_out=UnsafePointer[Bytef](),
        avail_out=0,
        total_out=0,
        msg=UnsafePointer[UInt8](),
        state=UnsafePointer[UInt8](),
        zalloc=UnsafePointer[UInt8](),
        zfree=UnsafePointer[UInt8](),
        opaque=UnsafePointer[UInt8](),
        data_type=0,
        adler=0,
        reserved=0,
    )

    # Estimate compressed size (upper bound)
    var estimated_size = len(data) + (len(data) // 1000) + 12
    var out_buf = List[UInt8](capacity=estimated_size)
    out_buf.resize(estimated_size, 0)

    stream.next_out = out_buf.unsafe_ptr()
    stream.avail_out = UInt32(len(out_buf))

    # Set compression level, defaulting to Z_DEFAULT_COMPRESSION if -1
    var compression_level = Int32(level)
    if level == -1:
        compression_level = Z_DEFAULT_COMPRESSION

    var zlib_version = String("1.2.11")
    var init_res = deflateInit2(
        UnsafePointer(to=stream),
        compression_level,
        Z_DEFLATED,
        Int32(wbits),  # Use wbits parameter for window size/format
        8,  # memLevel
        Z_DEFAULT_STRATEGY,
        zlib_version.unsafe_cstr_ptr().bitcast[UInt8](),
        Int32(sys.sizeof[ZStream]()),
    )

    if init_res != Z_OK:
        log_zlib_result(init_res, compressing=True)
        raise Error("Failed to initialize deflate stream")

    var Z_RES = deflate_fn(UnsafePointer(to=stream), Z_FINISH)
    _ = deflateEnd(UnsafePointer(to=stream))

    log_zlib_result(Z_RES, compressing=True)

    if Z_RES != Z_STREAM_END:
        raise Error("Compression failed with code " + String(Z_RES))
    out_buf.resize(Int(stream.total_out), 0)
    return out_buf^
