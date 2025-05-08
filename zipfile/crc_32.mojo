"""A re-implementation of the CRC-32 algorithm in Mojo.
It's the same algorithm used in the zipfile module in Python.
Reference: https://github.com/python/cpython/blob/main/Modules/binascii.c#L739
"""


fn generate_crc_32_table() -> InlineArray[UInt32, 256]:
    table = InlineArray[UInt32, 256](fill=0)
    for i in range(256):
        crc = UInt32(i)
        for _ in range(8):
            if (crc & 1) != 0:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
        table[i] = crc
    return table


alias CRC32Table = generate_crc_32_table()


struct CRC32:
    var _internal_value: UInt32

    @staticmethod
    fn get_crc_32(data: Span[UInt8]) -> UInt32:
        crc = CRC32()
        crc.write(data)
        return crc.get_final_crc()

    fn __init__(out self):
        self._internal_value = 0xFFFFFFFF

    fn write(mut self, data: Span[UInt8]):
        for byte in data:
            self._internal_value = CRC32Table[
                (self._internal_value ^ UInt32(byte[])) & UInt32(0xFF)
            ] ^ (self._internal_value >> 8)

    fn get_final_crc(self) -> UInt32:
        return ~self._internal_value
