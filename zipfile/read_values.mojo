from builtin.file import FileHandle



alias BigEndian = True
alias LittleEndian =  False


fn read_as[big_endian: Bool, dtype: DType](data: Span[UInt8]) -> Scalar[dtype]:
    constrained[dtype.is_integral(), "We can only read integers"]()
    constrained[dtype.is_unsigned(), "We can only read unsigned integers"]()
    tmp_array = InlineArray[UInt8, dtype.sizeof()](0)
    # lazy, do better next time
    for i in range(dtype.sizeof()):
        tmp_array[i] = data[i]
    return Scalar[dtype].from_bytes[big_endian](tmp_array)


fn read_zip_value[dtype: DType](data: Span[UInt8]) -> Scalar[dtype]:
    return read_as[LittleEndian, dtype](data)

fn read_zip_value[dtype: DType](file: FileHandle) raises -> Scalar[dtype]:
    return read_as[LittleEndian, dtype](file.read_bytes(dtype.sizeof()))