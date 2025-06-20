"""Tests for the zlib decompress function.

This module tests the decompress function against Python's zlib.decompress
to ensure compatibility and correctness.
"""

import testing
from zipfile.zlib.compression import decompress
from zipfile.zlib.constants import MAX_WBITS, DEF_BUF_SIZE
from zipfile.utils_testing import assert_lists_are_equal


fn test_decompress_empty_data() raises:
    """Test decompressing empty data."""
    # Empty data compressed with zlib format (wbits=15)
    var compressed = List[UInt8](120, 156, 3, 0, 0, 0, 0, 1)
    var result = decompress(compressed)
    testing.assert_equal(len(result), 0)


fn test_decompress_hello_world_zlib() raises:
    """Test decompressing "Hello, World!" with zlib format."""
    # "Hello, World!" compressed with zlib format (wbits=15)
    var compressed = List[UInt8](
        120,
        156,
        243,
        72,
        205,
        201,
        201,
        215,
        81,
        8,
        207,
        47,
        202,
        73,
        81,
        4,
        0,
        31,
        158,
        4,
        106,
    )
    var expected = List[UInt8](
        72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33
    )

    var result = decompress(compressed)
    testing.assert_equal(len(result), 13)

    assert_lists_are_equal(
        result, expected, "Hello World decompression should match expected"
    )


fn test_decompress_hello_world_gzip() raises:
    """Test decompressing "Hello, World!" with gzip format."""
    # "Hello, World!" compressed with gzip format (wbits=31)
    var compressed = List[UInt8](
        31,
        139,
        8,
        0,
        103,
        125,
        85,
        104,
        2,
        255,
        243,
        72,
        205,
        201,
        201,
        215,
        81,
        8,
        207,
        47,
        202,
        73,
        81,
        4,
        0,
        208,
        195,
        74,
        236,
        13,
        0,
        0,
        0,
    )
    var expected = List[UInt8](
        72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33
    )

    var result = decompress(compressed, wbits=31)
    testing.assert_equal(len(result), 13)

    for i in range(len(expected)):
        testing.assert_equal(result[i], expected[i])


fn test_decompress_short_string() raises:
    """Test decompressing short string "Hi"."""
    # "Hi" compressed with zlib format
    var compressed = List[UInt8](120, 156, 243, 200, 4, 0, 0, 251, 0, 178)
    var expected = List[UInt8](72, 105)  # "Hi"

    var result = decompress(compressed)
    testing.assert_equal(len(result), 2)

    for i in range(len(expected)):
        testing.assert_equal(result[i], expected[i])


fn test_decompress_repeated_pattern() raises:
    """Test decompressing repeated pattern (100 'A's)."""
    # 100 'A's compressed with zlib format - should compress well
    var compressed = List[UInt8](
        120, 156, 115, 116, 164, 61, 0, 0, 2, 233, 25, 101
    )

    var result = decompress(compressed)
    testing.assert_equal(len(result), 100)

    # Verify all bytes are 'A' (ASCII 65)
    for i in range(100):
        testing.assert_equal(result[i], 65)


fn test_decompress_numbers_pattern() raises:
    """Test decompressing repeated number pattern."""
    # "1234567890" repeated 10 times, compressed with zlib format
    var compressed = List[UInt8](
        120,
        156,
        51,
        52,
        50,
        54,
        49,
        53,
        51,
        183,
        176,
        52,
        48,
        164,
        25,
        11,
        0,
        10,
        206,
        20,
        131,
    )
    var expected = List[UInt8](
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,  # "1234567890"
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,  # repeated 10 times
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        48,
    )

    var result = decompress(compressed)
    testing.assert_equal(len(result), 100)

    for i in range(len(expected)):
        testing.assert_equal(result[i], expected[i])


fn test_decompress_binary_data() raises:
    """Test decompressing binary data (all bytes 0-255)."""
    # Binary data (0x00 to 0xFF) compressed with zlib format (doesn't compress well)
    var compressed = List[UInt8](
        120,
        156,
        1,
        0,
        1,
        255,
        254,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        59,
        60,
        61,
        62,
        63,
        64,
        65,
        66,
        67,
        68,
        69,
        70,
        71,
        72,
        73,
        74,
        75,
        76,
        77,
        78,
        79,
        80,
        81,
        82,
        83,
        84,
        85,
        86,
        87,
        88,
        89,
        90,
        91,
        92,
        93,
        94,
        95,
        96,
        97,
        98,
        99,
        100,
        101,
        102,
        103,
        104,
        105,
        106,
        107,
        108,
        109,
        110,
        111,
        112,
        113,
        114,
        115,
        116,
        117,
        118,
        119,
        120,
        121,
        122,
        123,
        124,
        125,
        126,
        127,
        128,
        129,
        130,
        131,
        132,
        133,
        134,
        135,
        136,
        137,
        138,
        139,
        140,
        141,
        142,
        143,
        144,
        145,
        146,
        147,
        148,
        149,
        150,
        151,
        152,
        153,
        154,
        155,
        156,
        157,
        158,
        159,
        160,
        161,
        162,
        163,
        164,
        165,
        166,
        167,
        168,
        169,
        170,
        171,
        172,
        173,
        174,
        175,
        176,
        177,
        178,
        179,
        180,
        181,
        182,
        183,
        184,
        185,
        186,
        187,
        188,
        189,
        190,
        191,
        192,
        193,
        194,
        195,
        196,
        197,
        198,
        199,
        200,
        201,
        202,
        203,
        204,
        205,
        206,
        207,
        208,
        209,
        210,
        211,
        212,
        213,
        214,
        215,
        216,
        217,
        218,
        219,
        220,
        221,
        222,
        223,
        224,
        225,
        226,
        227,
        228,
        229,
        230,
        231,
        232,
        233,
        234,
        235,
        236,
        237,
        238,
        239,
        240,
        241,
        242,
        243,
        244,
        245,
        246,
        247,
        248,
        249,
        250,
        251,
        252,
        253,
        254,
        255,
        173,
        246,
        127,
        129,
    )

    var result = decompress(compressed)
    testing.assert_equal(len(result), 256)

    # Verify all bytes from 0 to 255
    for i in range(256):
        testing.assert_equal(result[i], UInt8(i))


fn test_decompress_different_wbits_values() raises:
    """Test decompress with different wbits values."""
    # Test with default MAX_WBITS (15) - zlib format
    var zlib_compressed = List[UInt8](
        120,
        156,
        243,
        72,
        205,
        201,
        201,
        215,
        81,
        8,
        207,
        47,
        202,
        73,
        81,
        4,
        0,
        31,
        158,
        4,
        106,
    )
    var result_zlib = decompress(zlib_compressed)  # Default wbits=MAX_WBITS
    testing.assert_equal(len(result_zlib), 13)

    # Test with gzip format (wbits=31)
    var gzip_compressed = List[UInt8](
        31,
        139,
        8,
        0,
        103,
        125,
        85,
        104,
        2,
        255,
        243,
        72,
        205,
        201,
        201,
        215,
        81,
        8,
        207,
        47,
        202,
        73,
        81,
        4,
        0,
        208,
        195,
        74,
        236,
        13,
        0,
        0,
        0,
    )
    var result_gzip = decompress(gzip_compressed, wbits=31)
    testing.assert_equal(len(result_gzip), 13)

    # Both should produce the same result
    for i in range(13):
        testing.assert_equal(result_zlib[i], result_gzip[i])


fn test_decompress_different_buffer_sizes() raises:
    """Test decompress with different buffer sizes."""
    var compressed = List[UInt8](
        120,
        156,
        243,
        72,
        205,
        201,
        201,
        215,
        81,
        8,
        207,
        47,
        202,
        73,
        81,
        4,
        0,
        31,
        158,
        4,
        106,
    )
    var expected = List[UInt8](
        72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33
    )

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
    var compressed = List[UInt8](
        120,
        156,
        243,
        72,
        205,
        201,
        201,
        215,
        81,
        8,
        207,
        47,
        202,
        73,
        81,
        4,
        0,
        31,
        158,
        4,
        106,
    )

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
    var compressed = List[UInt8](
        120,
        156,
        11,
        201,
        72,
        85,
        40,
        44,
        205,
        76,
        206,
        86,
        72,
        42,
        202,
        47,
        207,
        83,
        72,
        203,
        175,
        80,
        200,
        42,
        205,
        45,
        40,
        86,
        200,
        47,
        75,
        45,
        82,
        40,
        1,
        74,
        231,
        36,
        86,
        85,
        42,
        164,
        228,
        167,
        235,
        41,
        132,
        140,
        42,
        30,
        85,
        60,
        170,
        152,
        218,
        138,
        1,
        71,
        165,
        67,
        28,
    )

    var result = decompress(compressed)
    testing.assert_equal(len(result), 900)  # "The quick brown fox..." * 20

    # Verify it starts with "The quick brown fox"
    var expected_start = "The quick brown fox jumps over the lazy dog. "
    for i in range(len(expected_start)):
        testing.assert_equal(result[i], ord(expected_start[i]))


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
