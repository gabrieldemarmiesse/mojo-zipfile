from ._src.checksums import adler32, crc32
from ._src.compression import compress, compressobj, Compress
from ._src.decompression import decompress, decompressobj, StreamingDecompressor
from ._src.constants import (
    MAX_WBITS,
    DEF_BUF_SIZE,
    Z_BEST_SPEED,
    Z_DEFAULT_COMPRESSION,
    Z_BEST_COMPRESSION,
)
