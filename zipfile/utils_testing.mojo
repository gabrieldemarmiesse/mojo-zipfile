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
