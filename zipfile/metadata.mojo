from .utils import _lists_are_equal
from .read_write_values import read_zip_value, write_zip_value

alias ZIP_STORED: UInt16 = 0
alias ZIP_DEFLATED: UInt16 = 8  # Not implement yet
alias ZIP_BZIP2: UInt16 = 12  # Not implement yet


@value
struct LocalFileHeader:
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 3, 4)

    var version_needed_to_extract: UInt16
    var general_purpose_bit_flag: UInt16
    var compression_method: UInt16
    var last_mod_file_time: UInt16
    var last_mod_file_date: UInt16
    var crc32: UInt32
    var compressed_size: UInt32
    var uncompressed_size: UInt32
    var filename: List[UInt8]
    var extra_field: List[UInt8]

    fn __init__(
        out self,
        version_needed_to_extract: UInt16,
        general_purpose_bit_flag: UInt16,
        compression_method: UInt16,
        last_mod_file_time: UInt16,
        last_mod_file_date: UInt16,
        crc32: UInt32,
        compressed_size: UInt32,
        uncompressed_size: UInt32,
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
        self.general_purpose_bit_flag = read_zip_value[DType.uint16](fp)
        self.compression_method = read_zip_value[DType.uint16](fp)
        self.last_mod_file_time = read_zip_value[DType.uint16](fp)
        self.last_mod_file_date = read_zip_value[DType.uint16](fp)
        self.crc32 = read_zip_value[DType.uint32](fp)
        self.compressed_size = read_zip_value[DType.uint32](fp)
        self.uncompressed_size = read_zip_value[DType.uint32](fp)
        filename_length = read_zip_value[DType.uint16](fp)
        extra_field_length = read_zip_value[DType.uint16](fp)
        self.filename = fp.read_bytes(Int(filename_length))
        self.extra_field = fp.read_bytes(Int(extra_field_length))

    fn write_to_file(self, mut fp: FileHandle) raises:
        # We write the fixed size part of the header
        write_zip_value(fp, self.SIGNATURE)
        write_zip_value(fp, self.version_needed_to_extract)
        write_zip_value(fp, self.general_purpose_bit_flag)
        write_zip_value(fp, self.compression_method)
        write_zip_value(fp, self.last_mod_file_time)
        write_zip_value(fp, self.last_mod_file_date)
        write_zip_value(fp, self.crc32)
        write_zip_value(fp, self.compressed_size)
        write_zip_value(fp, self.uncompressed_size)
        write_zip_value(fp, UInt16(len(self.filename)))
        write_zip_value(fp, UInt16(len(self.extra_field)))
        write_zip_value(fp, self.filename)
        write_zip_value(fp, self.extra_field)


@value
struct CentralDirectoryFileHeader:
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 1, 2)

    var version_made_by: UInt16
    var version_needed_to_extract: UInt16
    var general_purpose_bit_flag: UInt16
    var compression_method: UInt16
    var last_mod_file_time: UInt16
    var last_mod_file_date: UInt16
    var crc32: UInt32
    var compressed_size: UInt32
    var uncompressed_size: UInt32
    var disk_number_start: UInt16
    var internal_file_attributes: UInt16
    var external_file_attributes: UInt32
    var relative_offset_of_local_header: UInt32
    var filename: List[UInt8]
    var extra_field: List[UInt8]
    var file_comment: List[UInt8]

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
        self.general_purpose_bit_flag = read_zip_value[DType.uint16](fp)
        self.compression_method = read_zip_value[DType.uint16](fp)
        self.last_mod_file_time = read_zip_value[DType.uint16](fp)
        self.last_mod_file_date = read_zip_value[DType.uint16](fp)
        self.crc32 = read_zip_value[DType.uint32](fp)
        self.compressed_size = read_zip_value[DType.uint32](fp)
        self.uncompressed_size = read_zip_value[DType.uint32](fp)
        filename_length = read_zip_value[DType.uint16](fp)
        extra_field_length = read_zip_value[DType.uint16](fp)
        file_comment_length = read_zip_value[DType.uint16](fp)
        self.disk_number_start = read_zip_value[DType.uint16](fp)
        self.internal_file_attributes = read_zip_value[DType.uint16](fp)
        self.external_file_attributes = read_zip_value[DType.uint32](fp)
        self.relative_offset_of_local_header = read_zip_value[DType.uint32](fp)
        self.filename = fp.read_bytes(Int(filename_length))
        self.extra_field = fp.read_bytes(Int(extra_field_length))
        self.file_comment = fp.read_bytes(Int(file_comment_length))


@value
struct EndOfCentralDirectoryRecord:
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 5, 6)

    var number_of_this_disk: UInt16
    var number_of_the_disk_with_the_start_of_the_central_directory: UInt16
    var total_number_of_entries_in_the_central_directory_on_this_disk: UInt16
    var total_number_of_entries_in_the_central_directory: UInt16
    var size_of_the_central_directory: UInt32
    var offset_of_starting_disk_number: UInt32
    var zip_file_comment: List[UInt8]

    fn __init__(out self, fp: FileHandle) raises:
        # We read the fixed size part of the header
        signature = fp.read_bytes(4)
        if not _lists_are_equal(signature, self.SIGNATURE):
            raise Error("Signature invalid for EndOfCentralDirectoryRecord")

        self.number_of_this_disk = read_zip_value[DType.uint16](fp)
        self.number_of_the_disk_with_the_start_of_the_central_directory = (
            read_zip_value[DType.uint16](fp)
        )
        self.total_number_of_entries_in_the_central_directory_on_this_disk = (
            read_zip_value[DType.uint16](fp)
        )
        self.total_number_of_entries_in_the_central_directory = read_zip_value[
            DType.uint16
        ](fp)
        self.size_of_the_central_directory = read_zip_value[DType.uint32](fp)
        self.offset_of_starting_disk_number = read_zip_value[DType.uint32](fp)
        zip_file_comment_length = read_zip_value[DType.uint16](fp)
        self.zip_file_comment = fp.read_bytes(Int(zip_file_comment_length))
