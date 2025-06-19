from sys import ffi
from memory import memset_zero, UnsafePointer
from sys import info, exit
import sys

alias Bytef = Scalar[DType.uint8]
alias uLong = UInt64

alias z_stream_ptr = UnsafePointer[ZStream]  # forward-declared below

@fieldwise_init
struct ZStream(Copyable, Movable):
    var next_in: UnsafePointer[Bytef]
    var avail_in: UInt32
    var total_in: uLong
    var next_out: UnsafePointer[Bytef]
    var avail_out: UInt32
    var total_out: uLong
    var msg: UnsafePointer[UInt8]
    var state: UnsafePointer[UInt8]
    var zalloc: UnsafePointer[UInt8]
    var zfree: UnsafePointer[UInt8]
    var opaque: UnsafePointer[UInt8]
    var data_type: Int32
    var adler: uLong
    var reserved: uLong


alias inflateInit2_type = fn (
    strm: z_stream_ptr,
    windowBits: Int32,
    version: UnsafePointer[UInt8],
    stream_size: Int32,
) -> ffi.c_int
alias inflate_type = fn (strm: z_stream_ptr, flush: ffi.c_int) -> ffi.c_int
alias inflateEnd_type = fn (strm: z_stream_ptr) -> ffi.c_int

alias Z_OK: ffi.c_int = 0
alias Z_STREAM_END: ffi.c_int = 1
alias Z_NO_FLUSH: ffi.c_int = 0
alias Z_FINISH: ffi.c_int = 4


fn _log_zlib_result(Z_RES: ffi.c_int, compressing: Bool = True) raises -> None:
    var prefix: String = ""
    if not compressing:
        prefix = "un"

    if Z_RES == Z_OK or Z_RES == Z_STREAM_END:
        print(
            "OK "
            + prefix.upper()
            + "COMPRESSING: Everything "
            + prefix
            + "compressed fine"
        )
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
    var handle = ffi.DLHandle("/lib/x86_64-linux-gnu/libz.so")

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
    print("stream created")
    var out_buf = List[UInt8](capacity=expected_uncompressed_size)
    out_buf.resize(expected_uncompressed_size, 0)

    stream.next_out = out_buf.unsafe_ptr()
    stream.avail_out = UInt32(len(out_buf))
    print("stream resized")

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

    print("stream initialized")
    if init_res != Z_OK:
        _log_zlib_result(init_res, compressing=False)
    print("checked init result")
    var Z_RES = inflate_fn(UnsafePointer(to=stream), Z_FINISH)
    _ = inflateEnd(UnsafePointer(to=stream))
    print("stream finished")
    if not quiet:
        _log_zlib_result(Z_RES, compressing=False)

    return out_buf[: Int(stream.total_out)]
