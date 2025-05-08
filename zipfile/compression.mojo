from sys import ffi
from memory import memset_zero, UnsafePointer
from sys import info, exit

alias Bytef = Scalar[DType.uint8]
alias uLong = UInt64
alias zlib_type = fn (
    _out: UnsafePointer[Bytef],
    _out_len: UnsafePointer[UInt64],
    _in: UnsafePointer[Bytef],
    _in_len: uLong,
) -> ffi.c_int


fn _log_zlib_result(Z_RES: ffi.c_int, compressing: Bool = True) raises -> None:
    var prefix: String = ""
    if not compressing:
        prefix = "un"

    if Z_RES == 0:
        print(
            "OK "
            + prefix.upper()
            + "COMPRESSING: Everything "
            + prefix
            + "compressed fine"
        )
    elif Z_RES == -4:
        raise Error(
            "ERROR " + prefix.upper() + "COMPRESSING: Not enought memory"
        )
    elif Z_RES == -5:
        raise Error(
            "ERROR "
            + prefix.upper()
            + "COMPRESSING: Buffer have not enough memory"
        )
    else:
        raise Error(
            "ERROR " + prefix.upper() + "COMPRESSING: Unhandled exception, got code " + String(Z_RES)
        )




fn uncompress(data: List[UInt8],  expected_uncompressed_size: Int, quiet: Bool = False) raises -> List[UInt8]:
    """Uncompresses a zlib compressed byte List.

    Args:
        data: The zlib compressed byte List.
        quiet: Whether to print the result of the zlib operation. Defaults to True.

    Returns:
        The uncompressed byte List.

    Raises:
        Error: If the zlib operation fails.
    """
    var handle = ffi.DLHandle("/lib/x86_64-linux-gnu/libz.so")
    var zlib_uncompress = handle.get_function[zlib_type]("uncompress")

    var uncompressed = List[UInt8](capacity=expected_uncompressed_size)
    uncompressed.resize(expected_uncompressed_size, 0)
    var uncompressed_len = List[uLong](len(uncompressed))

    var Z_RES = zlib_uncompress(
        uncompressed.unsafe_ptr(),
        uncompressed_len.unsafe_ptr(),
        data.unsafe_ptr(),
        len(data),
    )
    _ = data
    print("uncompressed_len: ", uncompressed_len[0])

    if not quiet:
        _log_zlib_result(Z_RES, compressing=False)
    # Can probably do something more efficient here with pointers, but eh.
    var res = List[UInt8]()
    for i in range(uncompressed_len[0]):
        res.append(uncompressed[i])
    return res
