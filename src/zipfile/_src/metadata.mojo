from .utils import _lists_are_equal
from .read_write_values import read_zip_value, write_zip_value

alias ZIP_STORED: UInt16 = 0
alias ZIP_DEFLATED: UInt16 = 8  # Not implement yet
alias ZIP_BZIP2: UInt16 = 12  # Not implement yet


alias DEFAULT_VERSION = 20
alias ZIP64_VERSION = 45
alias BZIP2_VERSION = 46
alias LZMA_VERSION = 63


struct GeneralPurposeBitFlag(Copyable, Movable):
    var bits: UInt16

    fn __init__(out self, bits: UInt16):
        self.bits = bits

    @always_inline
    fn __init__(
        out self,
        encrypted: Bool = False,
        compression_option_1: Bool = False,
        compression_option_2: Bool = False,
        moved_to_data_descriptor: Bool = False,
        enhanced_deflation: Bool = False,
        is_compressed_patch_data: Bool = False,
        strong_encryption: Bool = False,
        strings_are_utf8: Bool = False,
        mask_header_values: Bool = False,
    ):
        self.bits = 0
        self.bits |= UInt16(1 << 0) * UInt16(Int(encrypted))
        self.bits |= UInt16(1 << 1) * UInt16(Int(compression_option_1))
        self.bits |= UInt16(1 << 2) * UInt16(Int(compression_option_2))
        self.bits |= UInt16(1 << 3) * UInt16(Int(moved_to_data_descriptor))
        self.bits |= UInt16(1 << 4) * UInt16(Int(enhanced_deflation))
        self.bits |= UInt16(1 << 5) * UInt16(Int(is_compressed_patch_data))
        self.bits |= UInt16(1 << 6) * UInt16(Int(strong_encryption))
        self.bits |= UInt16(1 << 11) * UInt16(Int(strings_are_utf8))
        self.bits |= UInt16(1 << 13) * UInt16(Int(mask_header_values))

    fn encrypted(self) -> Bool:
        return (self.bits & UInt16(1 << 0)) != 0

    fn compression_option_1(self) -> Bool:
        return (self.bits & UInt16(1 << 1)) != 0

    fn compression_option_2(self) -> Bool:
        return (self.bits & UInt16(1 << 2)) != 0

    fn moved_to_data_descriptor(self) -> Bool:
        return (self.bits & UInt16(1 << 3)) != 0

    fn enhanced_deflation(self) -> Bool:
        return (self.bits & UInt16(1 << 4)) != 0

    fn is_compressed_patch_data(self) -> Bool:
        return (self.bits & UInt16(1 << 5)) != 0

    fn strong_encryption(self) -> Bool:
        return (self.bits & UInt16(1 << 6)) != 0

    fn strings_are_utf8(self) -> Bool:
        return (self.bits & UInt16(1 << 11)) != 0

    fn mask_header_values(self) -> Bool:
        return (self.bits & UInt16(1 << 13)) != 0


struct LocalFileHeader(Copyable, Movable):
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 3, 4)
    alias CRC32_OFFSET = 14

    var version_needed_to_extract: UInt16
    var general_purpose_bit_flag: GeneralPurposeBitFlag
    var compression_method: UInt16
    var last_mod_file_time: UInt16
    var last_mod_file_date: UInt16
    var crc32: UInt32
    var compressed_size: UInt64
    var uncompressed_size: UInt64
    var filename: List[UInt8]
    var extra_field: List[UInt8]

    fn __init__(
        out self,
        version_needed_to_extract: UInt16,
        general_purpose_bit_flag: GeneralPurposeBitFlag,
        compression_method: UInt16,
        last_mod_file_time: UInt16,
        last_mod_file_date: UInt16,
        crc32: UInt32,
        compressed_size: UInt64,
        uncompressed_size: UInt64,
        filename: List[UInt8],
        extra_field: List[UInt8],
    ):
        self.version_needed_to_extract = version_needed_to_extract
        self.general_purpose_bit_flag = general_purpose_bit_flag
        self.compression_method = compression_method
        self.last_mod_file_time = last_mod_file_time
        self.last_mod_file_date = last_mod_file_date
        self.crc32 = crc32
        self.compressed_size = compressed_size
        self.uncompressed_size = uncompressed_size
        self.filename = filename
        self.extra_field = extra_field

    fn __init__(out self, fp: FileHandle) raises:
        # We read the fixed size part of the header
        signature = fp.read_bytes(4)
        if not _lists_are_equal(signature, self.SIGNATURE):
            raise Error("Signature invalid for LocalFileHeader")

        self.version_needed_to_extract = read_zip_value[DType.uint16](fp)
        self.general_purpose_bit_flag = GeneralPurposeBitFlag(
            read_zip_value[DType.uint16](fp)
        )
        self.compression_method = read_zip_value[DType.uint16](fp)
        self.last_mod_file_time = read_zip_value[DType.uint16](fp)
        self.last_mod_file_date = read_zip_value[DType.uint16](fp)
        self.crc32 = read_zip_value[DType.uint32](fp)
        compressed_size_raw = read_zip_value[DType.uint32](fp)
        uncompressed_size_raw = read_zip_value[DType.uint32](fp)

        # Handle ZIP64 markers - read actual values from extra field if present
        if (
            compressed_size_raw == 0xFFFFFFFF
            or uncompressed_size_raw == 0xFFFFFFFF
        ):
            # Initial values from main header
            self.compressed_size = UInt64(compressed_size_raw)
            self.uncompressed_size = UInt64(uncompressed_size_raw)
        else:
            self.compressed_size = UInt64(compressed_size_raw)
            self.uncompressed_size = UInt64(uncompressed_size_raw)
        filename_length = read_zip_value[DType.uint16](fp)
        extra_field_length = read_zip_value[DType.uint16](fp)
        self.filename = fp.read_bytes(Int(filename_length))
        self.extra_field = fp.read_bytes(Int(extra_field_length))

        # Parse ZIP64 extra field if needed
        if (
            compressed_size_raw == 0xFFFFFFFF
            or uncompressed_size_raw == 0xFFFFFFFF
        ):
            if len(self.extra_field) > 0:
                self._parse_zip64_extra_field(
                    compressed_size_raw, uncompressed_size_raw
                )
            else:
                # ZIP64 markers present but no extra field to read from
                raise Error(
                    "ZIP64 markers present but no ZIP64 extra field found -"
                    " invalid ZIP64 file"
                )

    fn _parse_zip64_extra_field(
        mut self, compressed_size_raw: UInt32, uncompressed_size_raw: UInt32
    ) raises:
        """Parse ZIP64 extended information from extra field."""
        var offset = 0
        while offset < len(self.extra_field) - 4:
            var header_id = UInt16(self.extra_field[offset]) | (
                UInt16(self.extra_field[offset + 1]) << 8
            )
            var size = UInt16(self.extra_field[offset + 2]) | (
                UInt16(self.extra_field[offset + 3]) << 8
            )

            if header_id == Zip64ExtendedInformationExtraField.HEADER_ID:
                # Found ZIP64 extra field
                if offset + 4 + Int(size) > len(self.extra_field):
                    raise Error(
                        "ZIP64 extra field extends beyond extra field data"
                    )

                var zip64_data = self.extra_field[
                    offset : offset + 4 + Int(size)
                ]
                var zip64_field = Zip64ExtendedInformationExtraField(zip64_data)

                # Update sizes if they were marked as ZIP64
                if uncompressed_size_raw == 0xFFFFFFFF:
                    self.uncompressed_size = zip64_field.original_size
                if compressed_size_raw == 0xFFFFFFFF:
                    self.compressed_size = zip64_field.compressed_size

                return

            offset += 4 + Int(size)

    fn write_to_file(
        self, mut fp: FileHandle, allow_zip64: Bool = True
    ) raises -> Int:
        # We write the fixed size part of the header
        write_zip_value(fp, self.SIGNATURE)
        write_zip_value(fp, self.version_needed_to_extract)
        write_zip_value(fp, self.general_purpose_bit_flag.bits)
        write_zip_value(fp, self.compression_method)
        write_zip_value(fp, self.last_mod_file_time)
        write_zip_value(fp, self.last_mod_file_date)
        write_zip_value(fp, self.crc32)

        # Check if we need ZIP64 format
        var needs_zip64 = (
            self.compressed_size > 0xFFFFFFFF
            or self.uncompressed_size > 0xFFFFFFFF
        )

        if needs_zip64 and not allow_zip64:
            raise Error("File size exceeds 4GB limit and allowZip64 is False")

        # Create ZIP64 extra field if needed
        var extra_field_data = self.extra_field
        if needs_zip64:
            # Create ZIP64 extra field
            var zip64_extra = Zip64ExtendedInformationExtraField(
                self.uncompressed_size,
                self.compressed_size,
                0,  # no offset in local header
                0,  # no disk number in local header
            )
            # For local file header, include sizes if they exceed 4GB
            var include_original = self.uncompressed_size > 0xFFFFFFFF
            var include_compressed = self.compressed_size > 0xFFFFFFFF
            var zip64_data = zip64_extra.create_extra_field_data(
                include_original, include_compressed, False, False
            )

            # Append ZIP64 extra field to existing extra fields
            for byte in zip64_data:
                extra_field_data.append(byte)

        # Write sizes - use ZIP64 markers only if size exceeds 4GB
        if self.compressed_size > 0xFFFFFFFF:
            write_zip_value(fp, UInt32(0xFFFFFFFF))  # compressed size marker
        else:
            write_zip_value(fp, UInt32(self.compressed_size))

        if self.uncompressed_size > 0xFFFFFFFF:
            write_zip_value(fp, UInt32(0xFFFFFFFF))  # uncompressed size marker
        else:
            write_zip_value(fp, UInt32(self.uncompressed_size))

        write_zip_value(fp, UInt16(len(self.filename)))
        write_zip_value(fp, UInt16(len(extra_field_data)))
        write_zip_value(fp, self.filename)
        write_zip_value(fp, extra_field_data)
        return 30 + len(self.filename) + len(extra_field_data)


struct CentralDirectoryFileHeader(Copyable, Movable):
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 1, 2)

    var version_made_by: UInt16
    var version_needed_to_extract: UInt16
    var general_purpose_bit_flag: GeneralPurposeBitFlag
    var compression_method: UInt16
    var last_mod_file_time: UInt16
    var last_mod_file_date: UInt16
    var crc32: UInt32
    var compressed_size: UInt64
    var uncompressed_size: UInt64
    var disk_number_start: UInt16
    var internal_file_attributes: UInt16
    var external_file_attributes: UInt32
    var relative_offset_of_local_header: UInt64
    var filename: List[UInt8]
    var extra_field: List[UInt8]
    var file_comment: List[UInt8]

    fn __init__(
        out self,
        local_file_header: LocalFileHeader,
        relative_offset_of_local_header: UInt64,
    ):
        self.version_made_by = DEFAULT_VERSION
        self.version_needed_to_extract = (
            local_file_header.version_needed_to_extract
        )
        self.general_purpose_bit_flag = (
            local_file_header.general_purpose_bit_flag
        )
        self.compression_method = local_file_header.compression_method
        self.last_mod_file_time = local_file_header.last_mod_file_time
        self.last_mod_file_date = local_file_header.last_mod_file_date
        self.crc32 = local_file_header.crc32
        self.compressed_size = local_file_header.compressed_size
        self.uncompressed_size = local_file_header.uncompressed_size
        self.disk_number_start = 0
        self.internal_file_attributes = 0
        self.external_file_attributes = 0
        self.relative_offset_of_local_header = relative_offset_of_local_header
        self.filename = local_file_header.filename
        self.extra_field = local_file_header.extra_field
        self.file_comment = List[UInt8]()

    fn __init__(
        out self,
        version_made_by: UInt16,
        version_needed_to_extract: UInt16,
        general_purpose_bit_flag: GeneralPurposeBitFlag,
        compression_method: UInt16,
        last_mod_file_time: UInt16,
        last_mod_file_date: UInt16,
        crc32: UInt32,
        compressed_size: UInt64,
        uncompressed_size: UInt64,
        disk_number_start: UInt16,
        internal_file_attributes: UInt16,
        external_file_attributes: UInt32,
        relative_offset_of_local_header: UInt64,
        filename: List[UInt8],
        extra_field: List[UInt8],
        file_comment: List[UInt8],
    ):
        self.version_made_by = version_made_by
        self.version_needed_to_extract = version_needed_to_extract
        self.general_purpose_bit_flag = general_purpose_bit_flag
        self.compression_method = compression_method
        self.last_mod_file_time = last_mod_file_time
        self.last_mod_file_date = last_mod_file_date
        self.crc32 = crc32
        self.compressed_size = compressed_size
        self.uncompressed_size = uncompressed_size
        self.disk_number_start = disk_number_start
        self.internal_file_attributes = internal_file_attributes
        self.external_file_attributes = external_file_attributes
        self.relative_offset_of_local_header = relative_offset_of_local_header
        self.filename = filename
        self.extra_field = extra_field
        self.file_comment = file_comment

    fn __init__(out self, fp: FileHandle) raises:
        # We read the fixed size part of the header
        signature = fp.read_bytes(4)
        if not _lists_are_equal(signature, self.SIGNATURE):
            err_msg = String("Signature invalid for CentralDirectoryFileHeader")
            err_msg += String(" expected: ")
            err_msg += String(self.SIGNATURE.__str__())
            err_msg += String(" got: ")
            err_msg += String(signature.__str__())
            raise Error(err_msg)

        self.version_made_by = read_zip_value[DType.uint16](fp)
        self.version_needed_to_extract = read_zip_value[DType.uint16](fp)
        self.general_purpose_bit_flag = GeneralPurposeBitFlag(
            read_zip_value[DType.uint16](fp)
        )
        self.compression_method = read_zip_value[DType.uint16](fp)
        self.last_mod_file_time = read_zip_value[DType.uint16](fp)
        self.last_mod_file_date = read_zip_value[DType.uint16](fp)
        self.crc32 = read_zip_value[DType.uint32](fp)
        compressed_size_raw = read_zip_value[DType.uint32](fp)
        uncompressed_size_raw = read_zip_value[DType.uint32](fp)
        filename_length = read_zip_value[DType.uint16](fp)
        extra_field_length = read_zip_value[DType.uint16](fp)
        file_comment_length = read_zip_value[DType.uint16](fp)
        self.disk_number_start = read_zip_value[DType.uint16](fp)
        self.internal_file_attributes = read_zip_value[DType.uint16](fp)
        self.external_file_attributes = read_zip_value[DType.uint32](fp)
        relative_offset_raw = read_zip_value[DType.uint32](fp)

        # Handle ZIP64 markers - read actual values from extra field if present
        self.compressed_size = UInt64(compressed_size_raw)
        self.uncompressed_size = UInt64(uncompressed_size_raw)
        self.relative_offset_of_local_header = UInt64(relative_offset_raw)
        self.filename = fp.read_bytes(Int(filename_length))
        self.extra_field = fp.read_bytes(Int(extra_field_length))
        self.file_comment = fp.read_bytes(Int(file_comment_length))

        # Parse ZIP64 extra field if needed
        if (
            compressed_size_raw == 0xFFFFFFFF
            or uncompressed_size_raw == 0xFFFFFFFF
            or relative_offset_raw == 0xFFFFFFFF
        ):
            if len(self.extra_field) > 0:
                self._parse_zip64_extra_field(
                    compressed_size_raw,
                    uncompressed_size_raw,
                    relative_offset_raw,
                )
            else:
                # ZIP64 markers present but no extra field to read from
                raise Error(
                    "ZIP64 markers present but no ZIP64 extra field found -"
                    " invalid ZIP64 file"
                )

    fn _parse_zip64_extra_field(
        mut self,
        compressed_size_raw: UInt32,
        uncompressed_size_raw: UInt32,
        relative_offset_raw: UInt32,
    ) raises:
        """Parse ZIP64 extended information from extra field."""
        var offset = 0
        while offset < len(self.extra_field) - 4:
            var header_id = UInt16(self.extra_field[offset]) | (
                UInt16(self.extra_field[offset + 1]) << 8
            )
            var size = UInt16(self.extra_field[offset + 2]) | (
                UInt16(self.extra_field[offset + 3]) << 8
            )

            if header_id == Zip64ExtendedInformationExtraField.HEADER_ID:
                # Found ZIP64 extra field
                if offset + 4 + Int(size) > len(self.extra_field):
                    raise Error(
                        "ZIP64 extra field extends beyond extra field data"
                    )

                var zip64_data = self.extra_field[
                    offset : offset + 4 + Int(size)
                ]
                var zip64_field = Zip64ExtendedInformationExtraField(zip64_data)

                # Update sizes if they were marked as ZIP64
                if uncompressed_size_raw == 0xFFFFFFFF:
                    self.uncompressed_size = zip64_field.original_size
                if compressed_size_raw == 0xFFFFFFFF:
                    self.compressed_size = zip64_field.compressed_size
                if relative_offset_raw == 0xFFFFFFFF:
                    self.relative_offset_of_local_header = (
                        zip64_field.relative_header_offset
                    )

                return

            offset += 4 + Int(size)

    fn write_to_file(
        self, mut fp: FileHandle, allow_zip64: Bool = True
    ) raises -> Int:
        write_zip_value(fp, self.SIGNATURE)
        write_zip_value(fp, self.version_made_by)
        write_zip_value(fp, self.version_needed_to_extract)
        write_zip_value(fp, self.general_purpose_bit_flag.bits)
        write_zip_value(fp, self.compression_method)
        write_zip_value(fp, self.last_mod_file_time)
        write_zip_value(fp, self.last_mod_file_date)
        write_zip_value(fp, self.crc32)

        # Check if we need ZIP64 format
        var needs_zip64 = (
            self.compressed_size > 0xFFFFFFFF
            or self.uncompressed_size > 0xFFFFFFFF
            or self.relative_offset_of_local_header > 0xFFFFFFFF
        )

        if needs_zip64 and not allow_zip64:
            if (
                self.compressed_size > 0xFFFFFFFF
                or self.uncompressed_size > 0xFFFFFFFF
            ):
                raise Error(
                    "File size exceeds 4GB limit and allowZip64 is False"
                )
            if self.relative_offset_of_local_header > 0xFFFFFFFF:
                raise Error(
                    "File offset exceeds 4GB limit and allowZip64 is False"
                )

        # Create ZIP64 extra field if needed
        var extra_field_data = self.extra_field
        if needs_zip64:
            # Create ZIP64 extra field
            var zip64_extra = Zip64ExtendedInformationExtraField(
                self.uncompressed_size,
                self.compressed_size,
                self.relative_offset_of_local_header,
                0,  # no disk number typically
            )
            # For central directory, include fields based on what will be marked as ZIP64
            var include_original = self.uncompressed_size > 0xFFFFFFFF
            var include_compressed = self.compressed_size > 0xFFFFFFFF
            var include_offset = (
                self.relative_offset_of_local_header > 0xFFFFFFFF
            )
            var zip64_data = zip64_extra.create_extra_field_data(
                include_original, include_compressed, include_offset, False
            )

            # Append ZIP64 extra field to existing extra fields
            for byte in zip64_data:
                extra_field_data.append(byte)

        # Write sizes - use ZIP64 markers only if size exceeds 4GB
        if self.compressed_size > 0xFFFFFFFF:
            write_zip_value(fp, UInt32(0xFFFFFFFF))  # compressed size marker
        else:
            write_zip_value(fp, UInt32(self.compressed_size))

        if self.uncompressed_size > 0xFFFFFFFF:
            write_zip_value(fp, UInt32(0xFFFFFFFF))  # uncompressed size marker
        else:
            write_zip_value(fp, UInt32(self.uncompressed_size))

        write_zip_value(fp, UInt16(len(self.filename)))
        write_zip_value(fp, UInt16(len(extra_field_data)))
        write_zip_value(fp, UInt16(len(self.file_comment)))
        write_zip_value(fp, self.disk_number_start)
        write_zip_value(fp, self.internal_file_attributes)
        write_zip_value(fp, self.external_file_attributes)

        # Write offset - use ZIP64 marker only if offset exceeds 4GB
        if self.relative_offset_of_local_header > 0xFFFFFFFF:
            write_zip_value(fp, UInt32(0xFFFFFFFF))  # offset marker
        else:
            write_zip_value(fp, UInt32(self.relative_offset_of_local_header))

        write_zip_value(fp, self.filename)
        write_zip_value(fp, extra_field_data)
        write_zip_value(fp, self.file_comment)
        return (
            46
            + len(self.filename)
            + len(extra_field_data)
            + len(self.file_comment)
        )


struct EndOfCentralDirectoryRecord(Copyable, Movable):
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 5, 6)

    var number_of_this_disk: UInt16
    var number_of_the_disk_with_the_start_of_the_central_directory: UInt16
    var total_number_of_entries_in_the_central_directory_on_this_disk: UInt16
    var total_number_of_entries_in_the_central_directory: UInt16
    var size_of_the_central_directory: UInt64
    var offset_of_starting_disk_number: UInt64
    var zip_file_comment: List[UInt8]

    fn __init__(
        out self,
        number_of_this_disk: UInt16,
        number_of_the_disk_with_the_start_of_the_central_directory: UInt16,
        total_number_of_entries_in_the_central_directory_on_this_disk: UInt16,
        total_number_of_entries_in_the_central_directory: UInt16,
        size_of_the_central_directory: UInt64,
        offset_of_starting_disk_number: UInt64,
        zip_file_comment: List[UInt8],
    ):
        self.number_of_this_disk = number_of_this_disk
        self.number_of_the_disk_with_the_start_of_the_central_directory = (
            number_of_the_disk_with_the_start_of_the_central_directory
        )
        self.total_number_of_entries_in_the_central_directory_on_this_disk = (
            total_number_of_entries_in_the_central_directory_on_this_disk
        )
        self.total_number_of_entries_in_the_central_directory = (
            total_number_of_entries_in_the_central_directory
        )
        self.size_of_the_central_directory = size_of_the_central_directory
        self.offset_of_starting_disk_number = offset_of_starting_disk_number
        self.zip_file_comment = zip_file_comment

    fn __init__(out self, fp: FileHandle) raises:
        # We read the fixed size part of the header
        signature = fp.read_bytes(4)
        if not _lists_are_equal(signature, self.SIGNATURE):
            raise Error("Signature invalid for EndOfCentralDirectoryRecord")

        self.number_of_this_disk = read_zip_value[DType.uint16](fp)
        self.number_of_the_disk_with_the_start_of_the_central_directory = (
            read_zip_value[DType.uint16](fp)
        )
        entries_on_disk = read_zip_value[DType.uint16](fp)
        total_entries = read_zip_value[DType.uint16](fp)

        # Store initial values - may be updated from ZIP64 record
        self.total_number_of_entries_in_the_central_directory_on_this_disk = (
            entries_on_disk
        )
        self.total_number_of_entries_in_the_central_directory = total_entries
        size_raw = read_zip_value[DType.uint32](fp)
        offset_raw = read_zip_value[DType.uint32](fp)

        # Store initial values - may be updated from ZIP64 record
        self.size_of_the_central_directory = UInt64(size_raw)
        self.offset_of_starting_disk_number = UInt64(offset_raw)
        zip_file_comment_length = read_zip_value[DType.uint16](fp)
        self.zip_file_comment = fp.read_bytes(Int(zip_file_comment_length))

    fn write_to_file(
        self, mut fp: FileHandle, allow_zip64: Bool = True
    ) raises -> Int:
        write_zip_value(fp, self.SIGNATURE)
        write_zip_value(fp, self.number_of_this_disk)
        write_zip_value(
            fp, self.number_of_the_disk_with_the_start_of_the_central_directory
        )

        # Check if we need ZIP64 format
        var needs_zip64 = (
            self.size_of_the_central_directory > 0xFFFFFFFF
            or self.offset_of_starting_disk_number > 0xFFFFFFFF
            or self.total_number_of_entries_in_the_central_directory > 0xFFFF
        )

        if needs_zip64 and not allow_zip64:
            if self.size_of_the_central_directory > 0xFFFFFFFF:
                raise Error(
                    "Central directory size exceeds 4GB limit and allowZip64 is"
                    " False"
                )
            if self.offset_of_starting_disk_number > 0xFFFFFFFF:
                raise Error(
                    "Central directory offset exceeds 4GB limit and allowZip64"
                    " is False"
                )
            if self.total_number_of_entries_in_the_central_directory > 0xFFFF:
                raise Error(
                    "Number of entries exceeds 65535 limit and allowZip64 is"
                    " False"
                )

        if needs_zip64:
            # Write ZIP64 markers in the regular EOCD
            write_zip_value(fp, UInt16(0xFFFF))  # entries on disk
            write_zip_value(fp, UInt16(0xFFFF))  # total entries
            write_zip_value(fp, UInt32(0xFFFFFFFF))  # central directory size
            write_zip_value(fp, UInt32(0xFFFFFFFF))  # central directory offset
        else:
            # Write regular values
            write_zip_value(
                fp,
                self.total_number_of_entries_in_the_central_directory_on_this_disk,
            )
            write_zip_value(
                fp, self.total_number_of_entries_in_the_central_directory
            )
            write_zip_value(fp, UInt32(self.size_of_the_central_directory))
            write_zip_value(fp, UInt32(self.offset_of_starting_disk_number))

        write_zip_value(fp, UInt16(len(self.zip_file_comment)))
        write_zip_value(fp, self.zip_file_comment)
        return 22 + len(self.zip_file_comment)


struct Zip64EndOfCentralDirectoryRecord(Copyable, Movable):
    """ZIP64 End of Central Directory Record structure.

    This structure contains extended information for ZIP64 archives
    that exceed the limits of the regular End of Central Directory Record.
    """

    alias SIGNATURE = List[UInt8](0x50, 0x4B, 6, 6)

    var size_of_zip64_end_of_central_directory_record: UInt64
    var version_made_by: UInt16
    var version_needed_to_extract: UInt16
    var number_of_this_disk: UInt32
    var number_of_the_disk_with_the_start_of_the_central_directory: UInt32
    var total_number_of_entries_in_the_central_directory_on_this_disk: UInt64
    var total_number_of_entries_in_the_central_directory: UInt64
    var size_of_the_central_directory: UInt64
    var offset_of_starting_disk_number: UInt64
    var zip64_extensible_data_sector: List[UInt8]

    fn __init__(out self, fp: FileHandle) raises:
        """Initialize from file handle."""
        signature = fp.read_bytes(4)
        if not _lists_are_equal(signature, self.SIGNATURE):
            raise Error(
                "Signature invalid for Zip64EndOfCentralDirectoryRecord"
            )

        self.size_of_zip64_end_of_central_directory_record = read_zip_value[
            DType.uint64
        ](fp)
        self.version_made_by = read_zip_value[DType.uint16](fp)
        self.version_needed_to_extract = read_zip_value[DType.uint16](fp)
        self.number_of_this_disk = read_zip_value[DType.uint32](fp)
        self.number_of_the_disk_with_the_start_of_the_central_directory = (
            read_zip_value[DType.uint32](fp)
        )
        self.total_number_of_entries_in_the_central_directory_on_this_disk = (
            read_zip_value[DType.uint64](fp)
        )
        self.total_number_of_entries_in_the_central_directory = read_zip_value[
            DType.uint64
        ](fp)
        self.size_of_the_central_directory = read_zip_value[DType.uint64](fp)
        self.offset_of_starting_disk_number = read_zip_value[DType.uint64](fp)

        # Read extensible data sector if present
        remaining_size = (
            Int(self.size_of_zip64_end_of_central_directory_record) - 44
        )  # 44 is the fixed size
        if remaining_size > 0:
            self.zip64_extensible_data_sector = fp.read_bytes(remaining_size)
        else:
            self.zip64_extensible_data_sector = List[UInt8]()

    fn __init__(
        out self,
        version_made_by: UInt16,
        version_needed_to_extract: UInt16,
        number_of_this_disk: UInt32,
        number_of_the_disk_with_the_start_of_the_central_directory: UInt32,
        total_number_of_entries_in_the_central_directory_on_this_disk: UInt64,
        total_number_of_entries_in_the_central_directory: UInt64,
        size_of_the_central_directory: UInt64,
        offset_of_starting_disk_number: UInt64,
        zip64_extensible_data_sector: List[UInt8],
    ):
        """Initialize ZIP64 End of Central Directory Record."""
        # Calculate the size of the record (minimum 44 bytes for fixed fields)
        self.size_of_zip64_end_of_central_directory_record = 44 + len(
            zip64_extensible_data_sector
        )
        self.version_made_by = version_made_by
        self.version_needed_to_extract = version_needed_to_extract
        self.number_of_this_disk = number_of_this_disk
        self.number_of_the_disk_with_the_start_of_the_central_directory = (
            number_of_the_disk_with_the_start_of_the_central_directory
        )
        self.total_number_of_entries_in_the_central_directory_on_this_disk = (
            total_number_of_entries_in_the_central_directory_on_this_disk
        )
        self.total_number_of_entries_in_the_central_directory = (
            total_number_of_entries_in_the_central_directory
        )
        self.size_of_the_central_directory = size_of_the_central_directory
        self.offset_of_starting_disk_number = offset_of_starting_disk_number
        self.zip64_extensible_data_sector = zip64_extensible_data_sector

    fn write_to_file(self, mut fp: FileHandle) raises -> Int:
        """Write ZIP64 End of Central Directory Record to file."""
        write_zip_value(fp, self.SIGNATURE)
        write_zip_value(fp, self.size_of_zip64_end_of_central_directory_record)
        write_zip_value(fp, self.version_made_by)
        write_zip_value(fp, self.version_needed_to_extract)
        write_zip_value(fp, self.number_of_this_disk)
        write_zip_value(
            fp, self.number_of_the_disk_with_the_start_of_the_central_directory
        )
        write_zip_value(
            fp,
            self.total_number_of_entries_in_the_central_directory_on_this_disk,
        )
        write_zip_value(
            fp, self.total_number_of_entries_in_the_central_directory
        )
        write_zip_value(fp, self.size_of_the_central_directory)
        write_zip_value(fp, self.offset_of_starting_disk_number)
        write_zip_value(fp, self.zip64_extensible_data_sector)
        return 56 + len(self.zip64_extensible_data_sector)


struct Zip64EndOfCentralDirectoryLocator(Copyable, Movable):
    """ZIP64 End of Central Directory Locator structure.

    This structure is used to locate the ZIP64 End of Central Directory Record.
    """

    alias SIGNATURE = List[UInt8](0x50, 0x4B, 6, 7)

    var number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory: UInt32
    var relative_offset_of_the_zip64_end_of_central_directory_record: UInt64
    var total_number_of_disks: UInt32

    fn __init__(out self, fp: FileHandle) raises:
        """Initialize from file handle."""
        signature = fp.read_bytes(4)
        if not _lists_are_equal(signature, self.SIGNATURE):
            raise Error(
                "Signature invalid for Zip64EndOfCentralDirectoryLocator"
            )

        self.number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory = read_zip_value[
            DType.uint32
        ](
            fp
        )
        self.relative_offset_of_the_zip64_end_of_central_directory_record = (
            read_zip_value[DType.uint64](fp)
        )
        self.total_number_of_disks = read_zip_value[DType.uint32](fp)

    fn __init__(
        out self,
        number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory: UInt32,
        relative_offset_of_the_zip64_end_of_central_directory_record: UInt64,
        total_number_of_disks: UInt32,
    ):
        """Initialize ZIP64 End of Central Directory Locator."""
        self.number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory = number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory
        self.relative_offset_of_the_zip64_end_of_central_directory_record = (
            relative_offset_of_the_zip64_end_of_central_directory_record
        )
        self.total_number_of_disks = total_number_of_disks

    fn write_to_file(self, mut fp: FileHandle) raises -> Int:
        """Write ZIP64 End of Central Directory Locator to file."""
        write_zip_value(fp, self.SIGNATURE)
        write_zip_value(
            fp,
            self.number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory,
        )
        write_zip_value(
            fp,
            self.relative_offset_of_the_zip64_end_of_central_directory_record,
        )
        write_zip_value(fp, self.total_number_of_disks)
        return 20


struct Zip64ExtendedInformationExtraField(Copyable, Movable):
    """ZIP64 Extended Information Extra Field structure.

    This structure contains extended information for individual files
    in ZIP64 format when they exceed 4GB limits.
    """

    alias HEADER_ID = UInt16(0x0001)

    var original_size: UInt64
    var compressed_size: UInt64
    var relative_header_offset: UInt64
    var disk_start_number: UInt32

    fn __init__(out self, data: Span[UInt8]) raises:
        """Initialize from extra field data."""
        if len(data) < 4:
            raise Error("ZIP64 extended information extra field too short")

        # Read header ID and size
        var header_id = UInt16(data[0]) | (UInt16(data[1]) << 8)
        if header_id != self.HEADER_ID:
            raise Error("Invalid ZIP64 extended information header ID")

        var size = UInt16(data[2]) | (UInt16(data[3]) << 8)
        if len(data) < 4 + Int(size):
            raise Error("ZIP64 extended information extra field data too short")

        # Initialize fields with default values
        self.original_size = 0
        self.compressed_size = 0
        self.relative_header_offset = 0
        self.disk_start_number = 0

        # Parse the data based on size
        var offset = 4
        if size >= 8:
            # Original size
            self.original_size = (
                UInt64(data[offset])
                | (UInt64(data[offset + 1]) << 8)
                | (UInt64(data[offset + 2]) << 16)
                | (UInt64(data[offset + 3]) << 24)
                | (UInt64(data[offset + 4]) << 32)
                | (UInt64(data[offset + 5]) << 40)
                | (UInt64(data[offset + 6]) << 48)
                | (UInt64(data[offset + 7]) << 56)
            )
            offset += 8

        if size >= 16:
            # Compressed size
            self.compressed_size = (
                UInt64(data[offset])
                | (UInt64(data[offset + 1]) << 8)
                | (UInt64(data[offset + 2]) << 16)
                | (UInt64(data[offset + 3]) << 24)
                | (UInt64(data[offset + 4]) << 32)
                | (UInt64(data[offset + 5]) << 40)
                | (UInt64(data[offset + 6]) << 48)
                | (UInt64(data[offset + 7]) << 56)
            )
            offset += 8

        if size >= 24:
            # Relative header offset
            self.relative_header_offset = (
                UInt64(data[offset])
                | (UInt64(data[offset + 1]) << 8)
                | (UInt64(data[offset + 2]) << 16)
                | (UInt64(data[offset + 3]) << 24)
                | (UInt64(data[offset + 4]) << 32)
                | (UInt64(data[offset + 5]) << 40)
                | (UInt64(data[offset + 6]) << 48)
                | (UInt64(data[offset + 7]) << 56)
            )
            offset += 8

        if size >= 28:
            # Disk start number
            self.disk_start_number = (
                UInt32(data[offset])
                | (UInt32(data[offset + 1]) << 8)
                | (UInt32(data[offset + 2]) << 16)
                | (UInt32(data[offset + 3]) << 24)
            )

    fn __init__(
        out self,
        original_size: UInt64,
        compressed_size: UInt64,
        relative_header_offset: UInt64,
        disk_start_number: UInt32,
    ):
        """Initialize ZIP64 Extended Information Extra Field."""
        self.original_size = original_size
        self.compressed_size = compressed_size
        self.relative_header_offset = relative_header_offset
        self.disk_start_number = disk_start_number

    fn write_to_file(self, mut fp: FileHandle) raises -> Int:
        """Write ZIP64 Extended Information Extra Field to file."""
        # Header ID (2 bytes)
        write_zip_value(fp, self.HEADER_ID)

        # Calculate size based on which fields are needed
        var size = 0
        var has_sizes = self.original_size != 0 or self.compressed_size != 0
        var has_offset = self.relative_header_offset != 0
        var has_disk = self.disk_start_number != 0

        if has_sizes:
            size += (
                16  # 8 bytes for original size + 8 bytes for compressed size
            )
        if has_offset:
            size += 8  # 8 bytes for relative header offset
        if has_disk:
            size += 4  # 4 bytes for disk start number

        # Write size (2 bytes)
        write_zip_value(fp, UInt16(size))

        # Write data fields in order
        if has_sizes:
            write_zip_value(fp, self.original_size)
            write_zip_value(fp, self.compressed_size)
        if has_offset:
            write_zip_value(fp, self.relative_header_offset)
        if has_disk:
            write_zip_value(fp, self.disk_start_number)

        return 4 + size  # 4 bytes for header + size bytes for data

    fn create_extra_field_data(
        self,
        include_original_size: Bool,
        include_compressed_size: Bool,
        include_offset: Bool,
        include_disk: Bool,
    ) raises -> List[UInt8]:
        """Create extra field data for ZIP64 Extended Information."""
        var data = List[UInt8]()

        # Header ID (2 bytes, little endian)
        data.append(UInt8(self.HEADER_ID & 0xFF))
        data.append(UInt8((self.HEADER_ID >> 8) & 0xFF))

        # Calculate size based on which fields are needed
        var size = 0
        if include_original_size:
            size += 8
        if include_compressed_size:
            size += 8
        if include_offset:
            size += 8
        if include_disk:
            size += 4

        # Size (2 bytes, little endian)
        data.append(UInt8(size & 0xFF))
        data.append(UInt8((size >> 8) & 0xFF))

        # Write data fields in ZIP64 spec order
        if include_original_size:
            # Original size (8 bytes, little endian)
            for i in range(8):
                data.append(UInt8((self.original_size >> (i * 8)) & 0xFF))
        if include_compressed_size:
            # Compressed size (8 bytes, little endian)
            for i in range(8):
                data.append(UInt8((self.compressed_size >> (i * 8)) & 0xFF))
        if include_offset:
            # Relative header offset (8 bytes, little endian)
            for i in range(8):
                data.append(
                    UInt8((self.relative_header_offset >> (i * 8)) & 0xFF)
                )
        if include_disk:
            # Disk start number (4 bytes, little endian)
            for i in range(4):
                data.append(UInt8((self.disk_start_number >> (i * 8)) & 0xFF))

        return data
