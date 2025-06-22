struct ZipFileReader[origin: Origin[mut=True]]:
    var file: Pointer[FileHandle, origin]
    var compressed_size: UInt64
    var uncompressed_size: UInt64
    var compression_method: UInt16
    var start: UInt64
    var expected_crc32: UInt32
    var current_crc32: UInt32
    var _inner_buffer: List[UInt8]  # Only used for ZIP_STORED now
    var _streaming_decompressor: zlib.Decompress  # For ZIP_DEFLATED
    var _bytes_read_from_file: UInt64  # Track how much compressed data we've read

    fn __init__(
        out self,
        file: Pointer[FileHandle, origin],
        compressed_size: UInt64,
        uncompressed_size: UInt64,
        compression_method: UInt16,
        expected_crc32: UInt32,
    ) raises:
        self.file = file
        self.compressed_size = compressed_size
        self.uncompressed_size = uncompressed_size
        self.compression_method = compression_method
        self.start = file[].seek(0, os.SEEK_CUR)
        self.expected_crc32 = expected_crc32
        self.current_crc32 = 0  # Initialize CRC32 to 0
        self._inner_buffer = List[UInt8]()
        self._streaming_decompressor = zlib.decompressobj(-zlib.MAX_WBITS)
        self._bytes_read_from_file = 0

    fn _is_at_start(self) raises -> Bool:
        return self.file[].seek(0, os.SEEK_CUR) == self.start

    fn _remaining_size(self) raises -> Int:
        end = self.start + self.compressed_size

        return Int(end - self.file[].seek(0, os.SEEK_CUR))

    fn _check_crc32(self) raises:
        if self.current_crc32 != self.expected_crc32:
            raise Error(
                "CRC32 mismatch, expected: "
                + String(self.expected_crc32)
                + ", got: "
                + String(self.current_crc32)
            )

    fn read(mut self, owned size: Int = -1) raises -> List[UInt8]:
        if self.compression_method == ZIP_STORED:
            if size == -1:
                size = self._remaining_size()
            else:
                size = min(size, self._remaining_size())

            bytes = self.file[].read_bytes(size)
            self.current_crc32 = zlib.crc32(bytes, self.current_crc32)

            if self._remaining_size() == 0:
                # We are at the end of the file
                self._check_crc32()
            return bytes
        elif self.compression_method == ZIP_DEFLATED:
            return self._read_deflated(size)
        else:
            raise Error(
                "Unsupported compression method: "
                + String(self.compression_method)
            )

    fn _read_deflated(mut self, size: Int) raises -> List[UInt8]:
        """Read deflated data using streaming decompression."""
        # Read compressed data in chunks and feed to decompressor
        # Use 32KB chunks to balance I/O and memory usage
        alias CHUNK_SIZE = 32768

        var result = List[UInt8]()
        var bytes_needed = size if size > 0 else -1  # -1 means read all

        while True:
            # Determine how much to request from decompressor
            var chunk_request = 65536  # Default chunk size
            if bytes_needed > 0:
                chunk_request = min(bytes_needed, 65536)

            # First, try to get data from the decompressor
            var decompressed_data = self._streaming_decompressor.read(
                chunk_request
            )

            if len(decompressed_data) > 0:
                # Add to result
                result += decompressed_data

                # Update CRC32 with decompressed data
                self.current_crc32 = zlib.crc32(
                    decompressed_data, self.current_crc32
                )

                # Update bytes needed counter
                if bytes_needed > 0:
                    bytes_needed -= len(decompressed_data)
                    if bytes_needed <= 0:
                        # We have enough data
                        return result

                # If reading all data (size <= 0), continue until finished
                if size <= 0:
                    # Check if we've read all data and verify CRC
                    if (
                        self._streaming_decompressor.is_finished()
                        and self._bytes_read_from_file == self.compressed_size
                    ):
                        self._check_crc32()
                        return result
                    # Otherwise continue reading
                else:
                    # For specific size requests, return what we have so far
                    return result

            # If decompressor can't provide data, check if we need more input
            if self._streaming_decompressor.is_finished():
                # All done, return what we have
                if self._bytes_read_from_file == self.compressed_size:
                    self._check_crc32()
                return result

            # Read more compressed data from file if available
            if self._bytes_read_from_file < self.compressed_size:
                var remaining_compressed = (
                    self.compressed_size - self._bytes_read_from_file
                )
                var to_read = min(CHUNK_SIZE, Int(remaining_compressed))

                var compressed_chunk = self.file[].read_bytes(to_read)
                self._bytes_read_from_file += UInt64(len(compressed_chunk))

                # Feed to decompressor
                self._streaming_decompressor.feed_input(compressed_chunk)
            # We've read all compressed data from file, but decompressor may still have data to process
            # This is normal - zlib might need multiple calls to process all the input
            # Continue the loop to let decompressor process remaining input buffer data
