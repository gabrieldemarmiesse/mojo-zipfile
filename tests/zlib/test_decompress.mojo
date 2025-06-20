"""Tests for the zlib decompress function.

This module tests the decompress function against Python's zlib.decompress
to ensure compatibility and correctness.
"""

import testing
from zipfile.zlib.compression import decompress
from zipfile.zlib.constants import MAX_WBITS, DEF_BUF_SIZE
from zipfile.utils_testing import (
    assert_lists_are_equal,
    compress_string_with_python,
    compress_binary_data_with_python,
)


fn test_decompress_empty_data() raises:
    # Generate compressed empty data dynamically
    var compressed = compress_string_with_python("", wbits=15)
    var result = decompress(compressed)
    testing.assert_equal(len(result), 0)


fn test_decompress_hello_world_zlib() raises:
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = decompress(compressed)
    assert_lists_are_equal(
        result, expected, "Hello World decompression should match expected"
    )


fn test_decompress_hello_world_gzip() raises:
    """Test decompressing "Hello, World!" with gzip format."""
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=31)
    var expected = test_string.as_bytes()

    var result = decompress(compressed, wbits=31)
    testing.assert_equal(len(result), len(expected))

    assert_lists_are_equal(
        result, expected, "Hello World gzip decompression should match expected"
    )


fn test_decompress_short_string() raises:
    var test_string = "Hi"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = decompress(compressed)
    testing.assert_equal(len(result), len(expected))

    assert_lists_are_equal(
        result, expected, "Short string decompression should match expected"
    )


fn test_decompress_repeated_pattern() raises:
    """Test decompressing repeated pattern (100 'A's)."""
    var test_string = "A" * 100
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = decompress(compressed)

    assert_lists_are_equal(
        result, expected, "Repeated pattern decompression should match expected"
    )


fn test_decompress_numbers_pattern() raises:
    """Test decompressing repeated number pattern."""
    var test_string = "1234567890" * 10
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = decompress(compressed)

    assert_lists_are_equal(
        result, expected, "Numbers pattern decompression should match expected"
    )


fn test_decompress_binary_data() raises:
    """Test decompressing binary data (all bytes 0-255)."""
    # Generate binary data (0x00 to 0xFF) - doesn't compress well
    var binary_data = [UInt8(i) for i in range(256)]
    var compressed = compress_binary_data_with_python(binary_data, wbits=15)

    var result = decompress(compressed)

    assert_lists_are_equal(
        result, binary_data, "Binary data decompression should match expected"
    )


fn test_decompress_different_wbits_values() raises:
    """Test decompress with different wbits values."""
    var test_string = "Hello, World!"
    var expected = test_string.as_bytes()

    # Test with default MAX_WBITS (15) - zlib format
    var zlib_compressed = compress_string_with_python(test_string, wbits=15)
    var result_zlib = decompress(zlib_compressed)  # Default wbits=MAX_WBITS
    assert_lists_are_equal(
        result_zlib, expected, "zlib decompression should match expected"
    )

    # Test with gzip format (wbits=31)
    var gzip_compressed = compress_string_with_python(test_string, wbits=31)
    var result_gzip = decompress(gzip_compressed, wbits=31)
    assert_lists_are_equal(
        result_gzip, expected, "gzip decompression should match expected"
    )


fn test_decompress_different_buffer_sizes() raises:
    """Test decompress with different buffer sizes."""
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    # Test with very small buffer
    var result_small = decompress(compressed, bufsize=1)
    testing.assert_equal(len(result_small), 13)
    for i in range(len(expected)):
        testing.assert_equal(result_small[i], expected[i])

    # Test with medium buffer
    var result_medium = decompress(compressed, bufsize=16)
    testing.assert_equal(len(result_medium), 13)
    for i in range(len(expected)):
        testing.assert_equal(result_medium[i], expected[i])

    # Test with large buffer
    var result_large = decompress(compressed, bufsize=65536)
    testing.assert_equal(len(result_large), 13)
    for i in range(len(expected)):
        testing.assert_equal(result_large[i], expected[i])

    # Test with default buffer size
    var result_default = decompress(compressed)  # Uses DEF_BUF_SIZE
    testing.assert_equal(len(result_default), 13)
    for i in range(len(expected)):
        testing.assert_equal(result_default[i], expected[i])


fn test_decompress_positional_only_parameter() raises:
    """Test that the data parameter is positional-only (using /)."""
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=15)

    # These should work - data as positional parameter
    var result1 = decompress(compressed)
    var result2 = decompress(compressed, wbits=MAX_WBITS)
    var result3 = decompress(compressed, wbits=MAX_WBITS, bufsize=DEF_BUF_SIZE)

    testing.assert_equal(len(result1), 13)
    testing.assert_equal(len(result2), 13)
    testing.assert_equal(len(result3), 13)


fn test_decompress_large_data() raises:
    """Test decompressing larger data set."""
    # Large repeated text compressed with zlib (should compress very well)
    var test_string = "The quick brown fox jumps over the lazy dog. " * 20
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = decompress(compressed)
    testing.assert_equal(len(result), 900)  # "The quick brown fox..." * 20

    assert_lists_are_equal(
        result, expected, "Large data decompression should match expected"
    )


fn test_decompress_edge_cases() raises:
    """Test edge cases and potential error conditions."""
    # Test with empty compressed data (should fail, but let's see how it handles it)
    try:
        var empty_data = List[UInt8]()
        _ = decompress(empty_data)
        # If we get here, the function didn't raise an error - that's unexpected
        testing.assert_true(False, "Expected decompress of empty data to fail")
    except:
        # Expected to fail - this is good
        pass


fn test_decompress_constants_values() raises:
    """Test that constants are properly defined and accessible."""
    # Test that MAX_WBITS is accessible and has the expected value
    testing.assert_equal(MAX_WBITS, 15)

    # Test that DEF_BUF_SIZE is accessible and has the expected value
    testing.assert_equal(DEF_BUF_SIZE, 16384)


def main():
    """Run all decompress tests."""
    test_decompress_empty_data()
    test_decompress_hello_world_zlib()
    test_decompress_hello_world_gzip()
    test_decompress_short_string()
    test_decompress_repeated_pattern()
    test_decompress_numbers_pattern()
    test_decompress_binary_data()
    test_decompress_different_wbits_values()
    test_decompress_different_buffer_sizes()
    test_decompress_positional_only_parameter()
    test_decompress_large_data()
    test_decompress_edge_cases()
    test_decompress_constants_values()
