from io import FileHandle
import sys

alias BigEndian = True
alias LittleEndian = False


fn read_as[big_endian: Bool, dtype: DType](data: Span[UInt8]) -> Scalar[dtype]:
    constrained[dtype.is_integral(), "We can only read integers"]()
    constrained[dtype.is_unsigned(), "We can only read unsigned integers"]()
    tmp_array = InlineArray[UInt8, sys.sizeof[Scalar[dtype]]()](0)
    # lazy, do better next time
    for i in range(dtype.sizeof()):
        tmp_array[i] = data[i]
    return Scalar[dtype].from_bytes[big_endian=big_endian](tmp_array)


fn read_zip_value[dtype: DType](data: Span[UInt8]) -> Scalar[dtype]:
    return read_as[LittleEndian, dtype](data)


fn read_zip_value[dtype: DType](file: FileHandle) raises -> Scalar[dtype]:
    return read_as[LittleEndian, dtype](file.read_bytes(dtype.sizeof()))


fn write_zip_value[
    dtype: DType, //
](mut file: FileHandle, value: Scalar[dtype]) raises:
    constrained[dtype.is_integral(), "We can only write integers"]()
    constrained[dtype.is_unsigned(), "We can only write unsigned integers"]()
    file.write_bytes(value.as_bytes[big_endian=LittleEndian]())


fn write_zip_value(mut file: FileHandle, value: List[UInt8]) raises:
    file.write_bytes(value)
