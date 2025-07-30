# We list here all public struct, functions, and methods

from ._src.zipfile import ZipFile
from ._src.zipfile import is_zipfile
from ._src.metadata import ZIP_STORED
from ._src.metadata import ZIP_DEFLATED
from ._src.zipinfo import ZipInfo

# (Not implemented) ZIP_BZIP2
# (Not implemented) ZIP_LZMA
# ZipFile(file, mode='r', compression=ZIP_STORED, allowZip64=True, compresslevel=None)
# ZipFile.close()
# ZipFile.getinfo(name)
# ZipFile.infolist()
# ZipFile.namelist()
# ZipFile.open(name, mode='r', *, force_zip64=False)
# ZipFile.extract(member, path=None)
# ZipFile.extractall(path=None, members=None)
# (Not implemented) ZipFile.printdir()
# ZipFile.read(name)
# (Not implemented) ZipFile.testzip()
# (Not implemented) ZipFile.write(filename, arcname=None, compress_type=None, compresslevel=None)
# (Partially implemented) ZipFile.writestr(zinfo_or_arcname, data, compress_type=None, compresslevel=None)
# ZipFile.mkdir(zinfo_or_directory, mode=511)
# (Not implemented) ZipFile.filename
# (Not implemented) ZipFile.debug
# (Not implemented) ZipFile.comment
# (Not implemented) Path(root, at='')
# (Not implemented) Path.name
# (Not implemented) Path.open(mode='r')
# (Not implemented) Path.iterdir()
# (Not implemented) Path.is_dir()
# (Not implemented) Path.is_file()
# (Not implemented) Path.is_symlink()
# (Not implemented) Path.exists()
# (Not implemented) Path.suffix
# (Not implemented) Path.stem
# (Not implemented) Path.suffixes
# (Not implemented) Path.read_text(*, **)
# (Not implemented) Path.read_bytes()
# (Not implemented) Path.joinpath(*other)
# (Not implemented) PyZipFile(file, mode='r', compression=ZIP_STORED, allowZip64=True, optimize=-1)
# (Not implemented) PyZipFile.writepy(pathname, basename='', filterfunc=None)
# (Not implemented) ZipInfo(filename='NoName', date_time=(1980, 1, 1, 0, 0, 0))
# (Not implemented) ZipInfo.from_file(filename, arcname=None, *, strict_timestamps=True)
# ZipInfo.is_dir()
# ZipInfo.filename
# (Not implemented) ZipInfo.date_time
# (Not implemented) ZipInfo.compress_type
# (Not implemented) ZipInfo.comment
# (Not implemented) ZipInfo.extra
# (Not implemented) ZipInfo.create_system
# (Not implemented) ZipInfo.create_version
# (Not implemented) ZipInfo.extract_version
# (Not implemented) ZipInfo.reserved
# (Not implemented) ZipInfo.flag_bits
# (Not implemented) ZipInfo.volume
# (Not implemented) ZipInfo.internal_attr
# (Not implemented) ZipInfo.external_attr
# (Not implemented) ZipInfo.header_offset
# (Not implemented) ZipInfo.CRC
# (Not implemented) ZipInfo.compress_size
# (Not implemented) ZipInfo.file_size
