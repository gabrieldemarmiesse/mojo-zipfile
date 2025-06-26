from python import PythonObject, Python


def to_py_bytes(data: String) -> PythonObject:
    return to_py_bytes(data.as_bytes())


def to_py_bytes(data: Span[Byte]) -> PythonObject:
    """Convert Mojo String or Span[Byte] to Python bytes."""
    py_builtins = Python.import_module("builtins")

    result_as_list = py_builtins.list()
    for byte in data:
        result_as_list.append(byte)
    return py_builtins.bytes(result_as_list)


fn to_mojo_bytes(some_data: PythonObject) raises -> List[Byte]:
    result = List[Byte]()
    for byte in some_data:
        result.append(UInt8(Int(byte)))
    return result


fn assert_lists_are_equal(
    list1: Span[Byte],
    list2: Span[Byte],
    message: String = "Lists should be equal",
) raises -> None:
    if len(list1) != len(list2):
        raise Error(message + ": Lengths differ")
    for i in range(len(list1)):
        if list1[i] != list2[i]:
            raise Error(
                message
                + ": Elements at index "
                + String(i)
                + " differ ("
                + String(list1[i])
                + " != "
                + String(list2[i])
                + ")"
            )
