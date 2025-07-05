# We list here all public struct, functions, and methods

from ._src.zipfile import ZipFile

# Path
# PyZipFile
# ZipInfo
from ._src.zipfile import is_zipfile
from ._src.metadata import ZIP_STORED
from ._src.metadata import ZIP_DEFLATED

# ZIP_BZIP2
# ZIP_LZMA
# ZipFile(file, mode='r', compression=ZIP_STORED, allowZip64=True, compresslevel=None, *, strict_timestamps=True, metadata_encoding=None)
# ZipFile.close()
# ZipFile.getinfo(name)
# ZipFile.infolist()
# ZipFile.namelist()
# ZipFile.open(name, mode='r', pwd=None, *, force_zip64=False)
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
# Path(root, at='')
# Path.name
# Path.open(mode='r', *, pwd, **)
# Path.iterdir()
# Path.is_dir()
# Path.is_file()
# Path.is_symlink()
# Path.exists()
# Path.suffix
# Path.stem
# Path.suffixes
# Path.read_text(*, **)
# Path.read_bytes()
# Path.joinpath(*other)
# PyZipFile(file, mode='r', compression=ZIP_STORED, allowZip64=True, optimize=-1)
# PyZipFile.writepy(pathname, basename='', filterfunc=None)
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
