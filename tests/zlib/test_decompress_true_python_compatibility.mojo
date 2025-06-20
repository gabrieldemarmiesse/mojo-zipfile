"""Test zipfile.zlib.decompress compatibility with Python's zlib.decompress.

This module directly compares outputs between Mojo and Python implementations
by calling Python's zlib.decompress in the same process.
"""

import zipfile.zlib as zlib
from testing import assert_equal, assert_true
from python import Python
from zipfile.utils_testing import to_py_bytes
from random import seed, random_ui64


def test_decompress_empty_data_python_compatibility():
    """Test that our decompress implementation matches Python's results for empty data.
    """
    # Import Python's zlib
    py_zlib = Python.import_module("zlib")

    # First compress empty data with Python to get valid compressed data
    empty_data = List[Byte]()
    py_empty_bytes = to_py_bytes(empty_data)
    py_compressed = py_zlib.compress(py_empty_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed.append(UInt8(Int(py_compressed[i])))

    # Decompress with both implementations
    mojo_result = zlib.decompress(mojo_compressed)
    py_result = py_zlib.decompress(py_compressed)

    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "decompressed empty data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "decompressed empty data bytes should match Python",
        )


def test_decompress_hello_python_compatibility():
    """Test that our decompress implementation matches Python's results for 'hello'.
    """
    py_zlib = Python.import_module("zlib")

    # Test simple string "hello"
    hello_data = "hello".as_bytes()
    py_hello_bytes = to_py_bytes(hello_data)
    py_compressed = py_zlib.compress(py_hello_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed.append(UInt8(Int(py_compressed[i])))

    # Decompress with both implementations
    mojo_result = zlib.decompress(mojo_compressed)
    py_result = py_zlib.decompress(py_compressed)

    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "decompressed 'hello' length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "decompressed 'hello' bytes should match Python",
        )


def test_decompress_with_different_wbits_python_compatibility():
    """Test that our decompress implementation matches Python's with different wbits values.
    """
    py_zlib = Python.import_module("zlib")

    test_data = "Test data for wbits compatibility testing.".as_bytes()
    wbits_values = [15, -15, 9, -9]  # zlib format, raw deflate format

    for wbits in wbits_values:
        # Compress with Python using specific wbits
        py_data_bytes = to_py_bytes(test_data)
        py_compressed = py_zlib.compress(py_data_bytes, wbits=wbits)

        # Convert Python compressed result to Mojo bytes
        mojo_compressed = List[Byte]()
        for i in range(len(py_compressed)):
            mojo_compressed.append(UInt8(Int(py_compressed[i])))

        # Decompress with both implementations using same wbits
        mojo_result = zlib.decompress(mojo_compressed, wbits=wbits)
        py_result = py_zlib.decompress(py_compressed, wbits=wbits)

        # Convert Python result to Mojo for comparison
        py_result_list = List[Byte]()
        for i in range(len(py_result)):
            py_result_list.append(UInt8(Int(py_result[i])))

        assert_equal(
            len(mojo_result),
            len(py_result_list),
            "decompressed data length should match Python for wbits "
            + String(wbits),
        )
        for i in range(len(mojo_result)):
            assert_equal(
                mojo_result[i],
                py_result_list[i],
                "decompressed data bytes should match Python for wbits "
                + String(wbits),
            )


def test_decompress_with_different_bufsize_python_compatibility():
    """Test that our decompress implementation matches Python's with different bufsize values.
    """
    py_zlib = Python.import_module("zlib")

    test_data = (
        "Test data for bufsize compatibility testing with longer text."
        .as_bytes()
    )
    bufsize_values = [1, 16, 1024, 16384]  # Different buffer sizes

    # Compress with Python first
    py_data_bytes = to_py_bytes(test_data)
    py_compressed = py_zlib.compress(py_data_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed.append(UInt8(Int(py_compressed[i])))

    for bufsize in bufsize_values:
        # Decompress with both implementations using same bufsize
        mojo_result = zlib.decompress(mojo_compressed, bufsize=bufsize)
        py_result = py_zlib.decompress(py_compressed, bufsize=bufsize)

        # Convert Python result to Mojo for comparison
        py_result_list = List[Byte]()
        for i in range(len(py_result)):
            py_result_list.append(UInt8(Int(py_result[i])))

        assert_equal(
            len(mojo_result),
            len(py_result_list),
            "decompressed data length should match Python for bufsize "
            + String(bufsize),
        )
        for i in range(len(mojo_result)):
            assert_equal(
                mojo_result[i],
                py_result_list[i],
                "decompressed data bytes should match Python for bufsize "
                + String(bufsize),
            )


def test_decompress_large_data_python_compatibility():
    """Test that our decompress implementation matches Python's with large data.
    """
    py_zlib = Python.import_module("zlib")

    # Large repetitive data that should compress well
    large_data = (
        "This is a large test string that will be repeated many times. " * 100
    ).as_bytes()

    # Compress with Python
    py_data_bytes = to_py_bytes(large_data)
    py_compressed = py_zlib.compress(py_data_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed.append(UInt8(Int(py_compressed[i])))

    # Decompress with both implementations
    mojo_result = zlib.decompress(mojo_compressed)
    py_result = py_zlib.decompress(py_compressed)

    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "decompressed large data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "decompressed large data bytes should match Python",
        )


def test_decompress_random_data_python_compatibility():
    """Test that our decompress implementation matches Python's with random data.
    """
    py_zlib = Python.import_module("zlib")

    # Set seed for reproducible random data
    seed(42)

    # Generate random test data
    random_data = List[Byte]()
    for _ in range(200):
        random_data.append(Byte(random_ui64(0, 255)))

    # Compress with Python
    py_data_bytes = to_py_bytes(random_data)
    py_compressed = py_zlib.compress(py_data_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed.append(UInt8(Int(py_compressed[i])))

    # Decompress with both implementations
    mojo_result = zlib.decompress(mojo_compressed)
    py_result = py_zlib.decompress(py_compressed)

    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "decompressed random data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "decompressed random data bytes should match Python",
        )


def test_decompress_binary_data_python_compatibility():
    """Test that our decompress implementation matches Python's with binary data.
    """
    py_zlib = Python.import_module("zlib")

    # Binary data with all byte values 0-255
    binary_data = List[Byte]()
    for i in range(256):
        binary_data.append(Byte(i))

    # Compress with Python
    py_data_bytes = to_py_bytes(binary_data)
    py_compressed = py_zlib.compress(py_data_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed.append(UInt8(Int(py_compressed[i])))

    # Decompress with both implementations
    mojo_result = zlib.decompress(mojo_compressed)
    py_result = py_zlib.decompress(py_compressed)

    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "decompressed binary data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "decompressed binary data bytes should match Python",
        )


def test_decompress_mojo_compress_python_decompress_roundtrip():
    """Test that data compressed with Mojo can be decompressed with Python and vice versa.
    """
    py_zlib = Python.import_module("zlib")

    test_data = (
        "Cross-compatibility test between Mojo and Python zlib.".as_bytes()
    )

    # Test 1: Mojo compress -> Python decompress
    mojo_compressed = zlib.compress(test_data)
    py_compressed_bytes = to_py_bytes(mojo_compressed)
    py_decompressed = py_zlib.decompress(py_compressed_bytes)

    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_decompressed)):
        py_result_list.append(UInt8(Int(py_decompressed[i])))

    assert_equal(
        len(test_data),
        len(py_result_list),
        "Mojo compress -> Python decompress should preserve data length",
    )
    for i in range(len(test_data)):
        assert_equal(
            test_data[i],
            py_result_list[i],
            "Mojo compress -> Python decompress should preserve data",
        )

    # Test 2: Python compress -> Mojo decompress
    py_data_bytes = to_py_bytes(test_data)
    py_compressed = py_zlib.compress(py_data_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed_from_py = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed_from_py.append(UInt8(Int(py_compressed[i])))

    mojo_decompressed = zlib.decompress(mojo_compressed_from_py)

    assert_equal(
        len(test_data),
        len(mojo_decompressed),
        "Python compress -> Mojo decompress should preserve data length",
    )
    for i in range(len(test_data)):
        assert_equal(
            test_data[i],
            mojo_decompressed[i],
            "Python compress -> Mojo decompress should preserve data",
        )


def test_decompress_compression_levels_python_compatibility():
    """Test that decompress works with data compressed at different levels by Python.
    """
    py_zlib = Python.import_module("zlib")

    test_data = ("Compression level test data. " * 20).as_bytes()
    compression_levels = [
        0,
        1,
        6,
        9,
        -1,
    ]  # No compression, fast, default, best, default (-1)

    for level in compression_levels:
        # Compress with Python at specific level
        py_data_bytes = to_py_bytes(test_data)
        py_compressed = py_zlib.compress(py_data_bytes, level)

        # Convert Python compressed result to Mojo bytes
        mojo_compressed = List[Byte]()
        for i in range(len(py_compressed)):
            mojo_compressed.append(UInt8(Int(py_compressed[i])))

        # Decompress with both implementations
        mojo_result = zlib.decompress(mojo_compressed)
        py_result = py_zlib.decompress(py_compressed)

        # Convert Python result to Mojo for comparison
        py_result_list = List[Byte]()
        for i in range(len(py_result)):
            py_result_list.append(UInt8(Int(py_result[i])))

        assert_equal(
            len(mojo_result),
            len(py_result_list),
            "decompressed data length should match Python for level "
            + String(level),
        )
        for i in range(len(mojo_result)):
            assert_equal(
                mojo_result[i],
                py_result_list[i],
                "decompressed data bytes should match Python for level "
                + String(level),
            )


def main():
    """Run all Python compatibility tests for decompress."""
    test_decompress_empty_data_python_compatibility()
    test_decompress_hello_python_compatibility()
    test_decompress_with_different_wbits_python_compatibility()
    test_decompress_with_different_bufsize_python_compatibility()
    test_decompress_large_data_python_compatibility()
    test_decompress_random_data_python_compatibility()
    test_decompress_binary_data_python_compatibility()
    test_decompress_mojo_compress_python_decompress_roundtrip()
    test_decompress_compression_levels_python_compatibility()
