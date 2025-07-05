# We list here all public struct, functions, and methods

from ._src.zipfile import ZipFile
from ._src.zipfile import is_zipfile
from ._src.metadata import ZIP_STORED
from ._src.metadata import ZIP_DEFLATED

# ZIP_BZIP2
# ZIP_LZMA
# ZipFile(file, mode='r', compression=ZIP_STORED, allowZip64=True, compresslevel=None, *, strict_timestamps=True, metadata_encoding=None)
# ZipFile.close()
# ZipFile.getinfo(name)
# ZipFile.infolist()
# (Not implemented) ZipFile.namelist()
# (Partially implemented) ZipFile.open_to_read(name, mode='r', pwd=None, *, force_zip64=False)
# (Partially implemented) ZipFile.open_to_write(name, mode='w', pwd=None, *, force_zip64=False)
# ZipFile.extract(member, path=None, pwd=None)
# ZipFile.extractall(path=None, members=None, pwd=None)
# ZipFile.printdir()
# ZipFile.setpassword(pwd)
# ZipFile.read(name, pwd=None)
# ZipFile.testzip()
# ZipFile.write(filename, arcname=None, compress_type=None, compresslevel=None)
# ZipFile.writestr(zinfo_or_arcname, data, compress_type=None, compresslevel=None)
# ZipFile.mkdir(zinfo_or_directory, mode=511)
# ZipFile.filename
# ZipFile.debug
# ZipFile.comment
# (Not implemented) Path(root, at='')
# (Not implemented) Path.name
# (Not implemented) Path.open(mode='r', *, pwd, **)
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
# ZipInfo(filename='NoName', date_time=(1980, 1, 1, 0, 0, 0))
# ZipInfo.from_file(filename, arcname=None, *, strict_timestamps=True)
# ZipInfo.is_dir()
# ZipInfo.filename
# ZipInfo.date_time
# ZipInfo.compress_type
# ZipInfo.comment
# ZipInfo.extra
# ZipInfo.create_system
# ZipInfo.create_version
# ZipInfo.extract_version
# ZipInfo.reserved
# ZipInfo.flag_bits
# ZipInfo.volume
# ZipInfo.internal_attr
# ZipInfo.external_attr
# ZipInfo.header_offset
# ZipInfo.CRC
# ZipInfo.compress_size
# ZipInfo.file_size
