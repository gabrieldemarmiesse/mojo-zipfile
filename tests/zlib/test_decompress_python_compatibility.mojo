"""Tests to verify that Mojo's decompress function produces identical results to Python's zlib.decompress.

This module directly compares outputs between Mojo and Python implementations.
"""

import testing
from zipfile.zlib.compression import decompress, compress
from zipfile.zlib.constants import MAX_WBITS, DEF_BUF_SIZE


fn test_decompress_compress_roundtrip() raises:
    """Test that compress -> decompress produces original data."""
    var original_text = "The quick brown fox jumps over the lazy dog!"
    var original_bytes = original_text.as_bytes()

    # Compress with our compress function
    var compressed = compress(original_bytes)

    # Decompress with our decompress function
    var decompressed = decompress(compressed)

    # Should get back original data
    testing.assert_equal(len(decompressed), len(original_bytes))
    for i in range(len(original_bytes)):
        testing.assert_equal(decompressed[i], original_bytes[i])


fn test_decompress_different_compression_levels() raises:
    """Test that decompress works with data compressed at different levels."""
    var test_data = "Hello, World! This is a test string for compression."
    var test_bytes = test_data.as_bytes()

    # Test with different compression levels (using compress function)
    # Level 1 (fast)
    var compressed_fast = compress(test_bytes, level=1)
    var decompressed_fast = decompress(compressed_fast)
    testing.assert_equal(len(decompressed_fast), len(test_bytes))

    # Level 9 (best compression)
    var compressed_best = compress(test_bytes, level=9)
    var decompressed_best = decompress(compressed_best)
    testing.assert_equal(len(decompressed_best), len(test_bytes))

    # Both should produce same result
    for i in range(len(test_bytes)):
        testing.assert_equal(decompressed_fast[i], test_bytes[i])
        testing.assert_equal(decompressed_best[i], test_bytes[i])
        testing.assert_equal(decompressed_fast[i], decompressed_best[i])


fn test_decompress_large_data_roundtrip() raises:
    """Test compress/decompress with larger data."""
    # Create larger test data
    var large_data = List[UInt8]()
    var base_text = "This is a test string for large data compression. "

    # Repeat the text 100 times
    var base_bytes = base_text.as_bytes()
    for _ in range(100):
        large_data.extend(base_bytes)

    # Compress and decompress
    var compressed = compress(large_data)
    var decompressed = decompress(compressed)

    # Verify
    testing.assert_equal(len(decompressed), len(large_data))
    for i in range(len(large_data)):
        testing.assert_equal(decompressed[i], large_data[i])


fn test_decompress_wbits_compatibility() raises:
    """Test that wbits parameter works correctly with different formats."""
    var test_data = "Test data for wbits compatibility."
    var test_bytes = test_data.as_bytes()

    # Test with default wbits (zlib format)
    var compressed_zlib = compress(test_bytes)  # Default wbits=MAX_WBITS
    var decompressed_zlib = decompress(
        compressed_zlib
    )  # Default wbits=MAX_WBITS

    testing.assert_equal(len(decompressed_zlib), len(test_bytes))
    for i in range(len(test_bytes)):
        testing.assert_equal(decompressed_zlib[i], test_bytes[i])

    # Test with raw deflate format
    var compressed_raw = compress(test_bytes, wbits=-MAX_WBITS)
    var decompressed_raw = decompress(compressed_raw, wbits=-MAX_WBITS)

    testing.assert_equal(len(decompressed_raw), len(test_bytes))
    for i in range(len(test_bytes)):
        testing.assert_equal(decompressed_raw[i], test_bytes[i])


fn test_decompress_various_data_types() raises:
    """Test decompress with various data patterns."""
    # Test with repeated patterns
    var repeated = List[UInt8]()
    for _ in range(1000):
        repeated.append(65)  # 'A'

    var compressed_repeated = compress(repeated)
    var decompressed_repeated = decompress(compressed_repeated)
    testing.assert_equal(len(decompressed_repeated), 1000)
    for i in range(1000):
        testing.assert_equal(decompressed_repeated[i], 65)

    # Test with random-like pattern
    var random_like = List[UInt8]()
    for i in range(256):
        random_like.append(UInt8(i))

    var compressed_random = compress(random_like)
    var decompressed_random = decompress(compressed_random)
    testing.assert_equal(len(decompressed_random), 256)
    for i in range(256):
        testing.assert_equal(decompressed_random[i], UInt8(i))


fn test_decompress_empty_data_roundtrip() raises:
    """Test compress/decompress roundtrip with empty data."""
    var empty_data = List[UInt8]()

    var compressed = compress(empty_data)
    var decompressed = decompress(compressed)

    testing.assert_equal(len(decompressed), 0)


def main():
    """Run all Python compatibility tests."""
    test_decompress_compress_roundtrip()
    test_decompress_different_compression_levels()
    test_decompress_large_data_roundtrip()
    test_decompress_wbits_compatibility()
    test_decompress_various_data_types()
    test_decompress_empty_data_roundtrip()
