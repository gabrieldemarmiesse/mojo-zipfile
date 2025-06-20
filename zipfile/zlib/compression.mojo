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
)


fn _get_libz_path() raises -> String:
    """Get the path to libz.so, preferring conda environment if available."""
    var conda_prefix = os.getenv("CONDA_PREFIX", "")
    if conda_prefix == "":
        raise Error(
            "CONDA_PREFIX is not set. Did you forget to activate the"
            " environment?"
        )
    return conda_prefix + "/lib/libz.so"


fn _log_zlib_result(Z_RES: ffi.c_int, compressing: Bool = True) raises -> None:
    var prefix: String = ""
    if not compressing:
        prefix = "un"

    if Z_RES == Z_OK or Z_RES == Z_STREAM_END:
        pass
    elif Z_RES == -4:
        raise Error(
            "ERROR " + prefix.upper() + "COMPRESSING: Not enough memory"
        )
    elif Z_RES == -5:
        raise Error(
            "ERROR "
            + prefix.upper()
            + "COMPRESSING: Buffer has not enough memory"
        )
    elif Z_RES == -3:
        raise Error(
            "ERROR "
            + prefix.upper()
            + "COMPRESSING: Data error (bad input format or corrupted)"
        )
    else:
        raise Error(
            "ERROR "
            + prefix.upper()
            + "COMPRESSING: Unhandled exception, got code "
            + String(Z_RES)
        )


fn uncompress(
    data: List[UInt8], expected_uncompressed_size: Int, quiet: Bool = False
) raises -> List[UInt8]:
    var handle = ffi.DLHandle(_get_libz_path())

    var inflateInit2 = handle.get_function[inflateInit2_type]("inflateInit2_")
    var inflate_fn = handle.get_function[inflate_type]("inflate")
    var inflateEnd = handle.get_function[inflateEnd_type]("inflateEnd")

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
    var out_buf = List[UInt8](capacity=expected_uncompressed_size)
    out_buf.resize(expected_uncompressed_size, 0)

    stream.next_out = out_buf.unsafe_ptr()
    stream.avail_out = UInt32(len(out_buf))

    # Use raw deflate by passing -15 as windowBits
    var zlib_version = String(
        "1.2.11"
    )  # Confirm this matches your libz version
    var init_res = inflateInit2(
        UnsafePointer(to=stream),
        -15,  # raw deflate
        zlib_version.unsafe_cstr_ptr().bitcast[UInt8](),
        Int32(sys.sizeof[ZStream]()),
    )

    if init_res != Z_OK:
        _log_zlib_result(init_res, compressing=False)
    var Z_RES = inflate_fn(UnsafePointer(to=stream), Z_FINISH)
    _ = inflateEnd(UnsafePointer(to=stream))
    if not quiet:
        _log_zlib_result(Z_RES, compressing=False)

    return out_buf[: Int(stream.total_out)]


struct StreamingDecompressor(Copyable, Movable):
    """A streaming decompressor that can decompress data in chunks to avoid large memory usage.
    """

    var stream: ZStream
    var handle: ffi.DLHandle
    var inflate_fn: fn (strm: z_stream_ptr, flush: ffi.c_int) -> ffi.c_int
    var inflateEnd: fn (strm: z_stream_ptr) -> ffi.c_int
    var initialized: Bool
    var finished: Bool
    var input_buffer: List[UInt8]
    var output_buffer: List[UInt8]
    var output_pos: Int
    var output_available: Int

    fn __init__(out self) raises:
        self.handle = ffi.DLHandle(_get_libz_path())
        self.inflate_fn = self.handle.get_function[inflate_type]("inflate")
        self.inflateEnd = self.handle.get_function[inflateEnd_type](
            "inflateEnd"
        )

        self.stream = ZStream(
            next_in=UnsafePointer[Bytef](),
            avail_in=0,
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

        self.initialized = False
        self.finished = False
        self.input_buffer = List[UInt8]()
        # Use 64KB output buffer to balance memory usage and performance
        self.output_buffer = List[UInt8](capacity=65536)
        self.output_buffer.resize(65536, 0)
        self.output_pos = 0
        self.output_available = 0

    fn initialize(mut self) raises:
        """Initialize the zlib stream for decompression."""
        if self.initialized:
            return

        var inflateInit2 = self.handle.get_function[inflateInit2_type](
            "inflateInit2_"
        )
        var zlib_version = String("1.2.11")
        var init_res = inflateInit2(
            UnsafePointer(to=self.stream),
            -15,  # raw deflate
            zlib_version.unsafe_cstr_ptr().bitcast[UInt8](),
            Int32(sys.sizeof[ZStream]()),
        )

        if init_res != Z_OK:
            _log_zlib_result(init_res, compressing=False)

        self.initialized = True

    fn __copyinit__(out self, existing: Self):
        """Copy constructor - creates a fresh decompressor."""
        # Since copying mid-stream state is complex, just create a fresh instance
        self.handle = existing.handle  # Share the same DLHandle
        self.inflate_fn = existing.inflate_fn
        self.inflateEnd = existing.inflateEnd

        self.stream = ZStream(
            next_in=UnsafePointer[Bytef](),
            avail_in=0,
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

        self.initialized = False
        self.finished = False
        self.input_buffer = List[UInt8]()
        self.output_buffer = List[UInt8](capacity=65536)
        self.output_buffer.resize(65536, 0)
        self.output_pos = 0
        self.output_available = 0

    fn __moveinit__(out self, owned existing: Self):
        """Move constructor."""
        self.stream = existing.stream
        self.handle = existing.handle
        self.inflate_fn = existing.inflate_fn
        self.inflateEnd = existing.inflateEnd
        self.initialized = existing.initialized
        self.finished = existing.finished
        self.input_buffer = existing.input_buffer^
        self.output_buffer = existing.output_buffer^
        self.output_pos = existing.output_pos
        self.output_available = existing.output_available

    fn feed_input(mut self, data: List[UInt8]):
        """Feed compressed input data to the decompressor."""
        self.input_buffer += data

    fn _decompress_available(mut self) raises -> Bool:
        """Try to decompress some data from input buffer. Returns True if output was produced.
        """
        if not self.initialized:
            self.initialize()

        if self.finished or len(self.input_buffer) == 0:
            return False

        # Set up input
        self.stream.next_in = self.input_buffer.unsafe_ptr()
        self.stream.avail_in = UInt32(len(self.input_buffer))

        # Reset output buffer
        self.output_pos = 0
        self.output_available = 0
        self.stream.next_out = self.output_buffer.unsafe_ptr()
        self.stream.avail_out = UInt32(len(self.output_buffer))

        # Decompress
        var result = self.inflate_fn(UnsafePointer(to=self.stream), Z_NO_FLUSH)

        if result == Z_STREAM_END:
            self.finished = True
        elif result != Z_OK:
            _log_zlib_result(result, compressing=False)

        # Calculate how much output was produced
        self.output_available = len(self.output_buffer) - Int(
            self.stream.avail_out
        )

        # Remove consumed input
        var consumed = len(self.input_buffer) - Int(self.stream.avail_in)
        if consumed > 0:
            var new_input = List[UInt8]()
            for i in range(consumed, len(self.input_buffer)):
                new_input.append(self.input_buffer[i])
            self.input_buffer = new_input^

        return self.output_available > 0

    fn read(mut self, size: Int) raises -> List[UInt8]:
        """Read up to 'size' bytes of decompressed data."""
        var result = List[UInt8]()
        var remaining = size

        while remaining > 0:
            # If we have data in output buffer, use it first
            if self.output_available > 0:
                var to_copy = min(remaining, self.output_available)
                for i in range(to_copy):
                    result.append(self.output_buffer[self.output_pos + i])

                self.output_pos += to_copy
                self.output_available -= to_copy
                remaining -= to_copy
                continue

            # Try to decompress more data
            if not self._decompress_available():
                # No more data available
                break

        return result

    fn is_finished(self) -> Bool:
        """Check if decompression is complete."""
        return self.finished and self.output_available == 0

    fn __del__(owned self):
        if self.initialized:
            _ = self.inflateEnd(UnsafePointer(to=self.stream))


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
    var handle = ffi.DLHandle(_get_libz_path())

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
        _log_zlib_result(init_res, compressing=True)
        raise Error("Failed to initialize deflate stream")

    var Z_RES = deflate_fn(UnsafePointer(to=stream), Z_FINISH)
    _ = deflateEnd(UnsafePointer(to=stream))

    _log_zlib_result(Z_RES, compressing=True)

    if Z_RES != Z_STREAM_END:
        raise Error("Compression failed with code " + String(Z_RES))
    out_buf.resize(Int(stream.total_out), 0)
    return out_buf^
