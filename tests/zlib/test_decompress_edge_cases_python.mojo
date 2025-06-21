"""Test edge cases for zlib decompress function with Python validation.

This module tests edge cases and special scenarios that might not be covered
in the general compatibility tests.
"""

from zipfile import zlib
from testing import assert_equal, assert_true
from python import Python
from zipfile.utils_testing import (
    to_py_bytes,
    to_mojo_bytes,
    assert_lists_are_equal,
    test_mojo_vs_python_decompress,
)


def test_decompress_gzip_format_python_compatibility():
    """Test that our decompress works with gzip format (wbits=31) like Python.
    """
    test_data = (
        "Gzip format test data for compatibility verification.".as_bytes()
    )

    test_mojo_vs_python_decompress(
        test_data,
        wbits=31,
        message="gzip decompressed data should match Python",
    )


def test_decompress_minimal_window_size_python_compatibility():
    """Test decompress with minimal window size (wbits=9)."""
    test_data = "Minimal window size test.".as_bytes()

    test_mojo_vs_python_decompress(
        test_data,
        wbits=9,
        message="minimal window size decompressed data should match Python",
    )


def test_decompress_very_small_buffer_python_compatibility():
    """Test decompress with very small buffer size."""
    py_zlib = Python.import_module("zlib")

    test_data = (
        "Testing very small buffer size handling in decompress function."
        .as_bytes()
    )

    # Compress with Python
    py_data_bytes = to_py_bytes(test_data)
    py_compressed = py_zlib.compress(py_data_bytes)

    # Convert Python compressed result to Mojo bytes
    mojo_compressed = List[Byte]()
    for i in range(len(py_compressed)):
        mojo_compressed.append(UInt8(Int(py_compressed[i])))

    # Decompress with very small buffer (should still work)
    mojo_result = zlib.decompress(mojo_compressed, bufsize=1)
    py_result = py_zlib.decompress(py_compressed, bufsize=1)

    # Convert Python result to Mojo for comparison
    py_result_list = List[Byte]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "very small buffer decompressed data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "very small buffer decompressed data bytes should match Python",
        )


def test_decompress_highly_repetitive_data_python_compatibility():
    """Test decompress with highly repetitive data that compresses extremely well.
    """
    py_zlib = Python.import_module("zlib")

    # Create highly repetitive data (should compress to very small size)
    repetitive_data = ("X" * 10000).as_bytes()

    # Compress with Python
    py_data_bytes = to_py_bytes(repetitive_data)
    py_compressed = py_zlib.compress(py_data_bytes)

    # Verify compression ratio is good (compressed size should be much smaller)
    assert_true(
        len(py_compressed) * 100
        < len(repetitive_data),  # Should compress to less than 1% of original
        "highly repetitive data should compress very well",
    )

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
        "highly repetitive decompressed data length should match Python",
    )
    assert_equal(
        len(mojo_result),
        10000,
        "decompressed data should have original length",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "highly repetitive decompressed data bytes should match Python",
        )


def test_decompress_unicode_text_python_compatibility():
    """Test decompress with Unicode text data."""
    py_zlib = Python.import_module("zlib")

    # Unicode text (will be encoded as UTF-8 bytes)
    unicode_text = "Hello, 世界! Héllo, мир! 🌍🚀✨".as_bytes()

    # Compress with Python
    py_data_bytes = to_py_bytes(unicode_text)
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
        "Unicode decompressed data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "Unicode decompressed data bytes should match Python",
        )


def main():
    """Run all edge case tests with Python validation."""
    test_decompress_gzip_format_python_compatibility()
    test_decompress_minimal_window_size_python_compatibility()
    test_decompress_very_small_buffer_python_compatibility()
    test_decompress_highly_repetitive_data_python_compatibility()
    test_decompress_unicode_text_python_compatibility()
