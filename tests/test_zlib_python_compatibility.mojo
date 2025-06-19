"""Test zipfile.zlib.adler32 compatibility with Python's zlib.adler32."""

import zipfile.zlib as zlib
from testing import assert_equal
from python import Python


def test_adler32_python_compatibility():
    """Test that our adler32 implementation matches Python's results."""

    # Import Python's zlib and create byte objects
    py_zlib = Python.import_module("zlib")

    # Test empty data
    empty_data = List[UInt8]()
    mojo_result = zlib.adler32(empty_data)
    py_empty_bytes = Python.evaluate("b''")
    py_result = py_zlib.adler32(py_empty_bytes)
    assert_equal(
        mojo_result, Int(py_result), "adler32 empty data should match Python"
    )

    # Test simple string "hello"
    hello_data = String("hello").as_bytes()
    mojo_result = zlib.adler32(hello_data)
    py_hello_bytes = Python.evaluate("b'hello'")
    py_result = py_zlib.adler32(py_hello_bytes)
    assert_equal(
        mojo_result, Int(py_result), "adler32 'hello' should match Python"
    )

    # Test with custom starting value
    world_data = String("world").as_bytes()
    mojo_result = zlib.adler32(world_data, 12345)
    py_world_bytes = Python.evaluate("b'world'")
    py_result = py_zlib.adler32(py_world_bytes, 12345)
    assert_equal(
        mojo_result,
        Int(py_result),
        "adler32 with custom value should match Python",
    )

    # Test concatenation/running checksum
    hello_adler = zlib.adler32(hello_data)
    py_hello_adler = py_zlib.adler32(py_hello_bytes)
    assert_equal(hello_adler, Int(py_hello_adler), "hello adler should match")

    space_world_data = String(" world").as_bytes()

    mojo_combined = zlib.adler32(space_world_data, hello_adler)
    py_space_world_bytes = Python.evaluate("b' world'")
    py_combined = py_zlib.adler32(py_space_world_bytes, py_hello_adler)
    assert_equal(
        mojo_combined, Int(py_combined), "running checksum should match Python"
    )

    # Verify this equals direct computation of "hello world"
    hello_world_data = String("hello world").as_bytes()
    mojo_direct = zlib.adler32(hello_world_data)
    py_hello_world_bytes = Python.evaluate("b'hello world'")
    py_direct = py_zlib.adler32(py_hello_world_bytes)
    assert_equal(
        mojo_combined,
        mojo_direct,
        "running checksum should equal direct computation",
    )
    assert_equal(
        Int(py_combined),
        Int(py_direct),
        "Python running checksum should equal direct",
    )

    # Test byte values 0-9
    binary_data = List[UInt8]()
    for i in range(10):
        binary_data.append(UInt8(i))
    mojo_result = zlib.adler32(binary_data)
    py_binary_bytes = Python.evaluate("bytes(range(10))")
    py_result = py_zlib.adler32(py_binary_bytes)
    assert_equal(
        mojo_result, Int(py_result), "adler32 binary data should match Python"
    )
