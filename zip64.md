# ZIP64 Support - Public API Changes Required

## Overview
This document outlines all the public API changes needed to add ZIP64 support to the Mojo zipfile library, following Python's zipfile module interface.

## 1. Constructor Changes

### ZipFile Constructor
**Current:**
```mojo
fn __init__[FileNameType: PathLike](out self, filename: FileNameType, mode: String) raises
```

**Required:**
```mojo
fn __init__[FileNameType: PathLike](out self, filename: FileNameType, mode: String, allowZip64: Bool = True) raises
```

**Changes:**
- Add `allowZip64` parameter with default value `True` (matches Python 3.4+ behavior)
- When `allowZip64=True`: Automatically use ZIP64 extensions when file size > 4GB
- When `allowZip64=False`: Raise error if ZIP64 extensions would be required

## 2. Method Parameter Changes

### open_to_write Method
**Current:**
```mojo
fn open_to_write(
    mut self,
    name: String,
    mode: String,
    compression_method: UInt16 = ZIP_STORED,
    compresslevel: Int32 = -1,
) raises -> ZipFileWriter[__origin_of(self)]
```

**Required:**
```mojo
fn open_to_write(
    mut self,
    name: String,
    mode: String,
    compression_method: UInt16 = ZIP_STORED,
    compresslevel: Int32 = -1,
    force_zip64: Bool = False,
) raises -> ZipFileWriter[__origin_of(self)]
```

**Changes:**
- Add `force_zip64` parameter to force ZIP64 format regardless of file size

### writestr Method
**Current:**
```mojo
fn writestr(
    mut self,
    arcname: String,
    data: String,
    compression_method: UInt16 = ZIP_STORED,
    compresslevel: Int32 = -1,
) raises
```

**Required:**
```mojo
fn writestr(
    mut self,
    arcname: String,
    data: String,
    compression_method: UInt16 = ZIP_STORED,
    compresslevel: Int32 = -1,
    force_zip64: Bool = False,
) raises
```

**Changes:**
- Add `force_zip64` parameter to force ZIP64 format regardless of data size

## 3. New Metadata Structures

### ZIP64 Extended Information Extra Field
**New Structure Required:**
```mojo
struct Zip64ExtraField(Copyable, Movable):
    alias HEADER_ID: UInt16 = 0x0001
    var uncompressed_size: Optional[UInt64]
    var compressed_size: Optional[UInt64]
    var relative_header_offset: Optional[UInt64]
    var disk_start_number: Optional[UInt32]
```

### ZIP64 End of Central Directory Record
**New Structure Required:**
```mojo
struct Zip64EndOfCentralDirectoryRecord(Copyable, Movable):
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 6, 6)
    var size_of_zip64_end_of_central_directory_record: UInt64
    var version_made_by: UInt16
    var version_needed_to_extract: UInt16
    var number_of_this_disk: UInt32
    var number_of_the_disk_with_the_start_of_the_central_directory: UInt32
    var total_number_of_entries_in_the_central_directory_on_this_disk: UInt64
    var total_number_of_entries_in_the_central_directory: UInt64
    var size_of_the_central_directory: UInt64
    var offset_of_start_of_central_directory: UInt64
    var zip64_extensible_data_sector: List[UInt8]
```

### ZIP64 End of Central Directory Locator
**New Structure Required:**
```mojo
struct Zip64EndOfCentralDirectoryLocator(Copyable, Movable):
    alias SIGNATURE = List[UInt8](0x50, 0x4B, 6, 7)
    var number_of_the_disk_with_the_start_of_the_zip64_end_of_central_directory: UInt32
    var relative_offset_of_the_zip64_end_of_central_directory_record: UInt64
    var total_number_of_disks: UInt32
```

## 4. Enhanced Data Type Support

### Field Size Changes
**Current limitations (need ZIP64 when exceeded):**
- File sizes: UInt32 (max 4GB)
- Central directory offset: UInt32 (max 4GB)
- Number of entries: UInt16 (max 65535)

**ZIP64 extensions:**
- File sizes: UInt64 (max ~18 exabytes)
- Central directory offset: UInt64
- Number of entries: UInt64

### Modified Structures
**LocalFileHeader - Add ZIP64 support:**
- Keep existing UInt32 fields for compatibility
- Use 0xFFFFFFFF as marker value when ZIP64 extension present
- Parse extra field for ZIP64 extended information

**CentralDirectoryFileHeader - Add ZIP64 support:**
- Keep existing UInt32 fields for compatibility  
- Use 0xFFFFFFFF as marker value when ZIP64 extension present
- Parse extra field for ZIP64 extended information

**EndOfCentralDirectoryRecord - Add ZIP64 support:**
- Keep existing fields for compatibility
- Use 0xFFFF/0xFFFFFFFF as marker values when ZIP64 extension present

## 5. ZipInfo Structure Changes

### Current ZipInfo
```mojo
struct ZipInfo(Copyable, Movable):
    var filename: String
    var _start_of_header: UInt64
    var _compressed_size: UInt64
    var _uncompressed_size: UInt64
    var _compression_method: UInt16
    var _crc32: Optional[UInt32]
```

**Changes:**
- Fields already use UInt64 for sizes (good!)
- Add `_needs_zip64: Bool` property
- Add `_zip64_extra_field: Optional[Zip64ExtraField]`

## 6. New Public Methods

### is_zip64 Method
**New Method Required:**
```mojo
fn is_zip64(self) -> Bool
```
Returns True if the ZIP file uses ZIP64 extensions.

### ZipInfo.is_zip64 Method
**New Method Required:**
```mojo
fn is_zip64(self) -> Bool
```
Returns True if this individual file entry requires ZIP64 extensions.

## 7. Version Constants

### New Version Constants
**Add to metadata.mojo:**
```mojo
alias ZIP64_VERSION: UInt16 = 45  # Already exists but ensure it's used
```

## 8. Error Handling

### New Error Conditions
- Raise error when `allowZip64=False` and file would exceed 4GB
- Raise error when ZIP64 required but not supported by reader
- Handle ZIP64 signature validation

## 9. Internal Implementation Changes

### Automatic ZIP64 Detection
- Check file sizes during write operations
- Automatically enable ZIP64 when thresholds exceeded (if `allowZip64=True`)
- Handle reading both ZIP64 and traditional formats transparently

### Backwards Compatibility
- Traditional ZIP format support maintained
- ZIP64 extensions optional and automatic
- Reading supports both formats seamlessly

## 10. Constants and Thresholds

### ZIP64 Trigger Values
```mojo
alias ZIP64_LIMIT: UInt64 = 0xFFFFFFFF  # 4GB - 1 byte
alias ZIP64_FILECOUNT_LIMIT: UInt64 = 0xFFFF  # 65535 files
```

## Summary of Public API Changes

1. **Constructor**: Add `allowZip64: Bool = True` parameter
2. **Methods**: Add `force_zip64: Bool = False` parameter to `open_to_write()` and `writestr()`
3. **New Methods**: Add `is_zip64()` methods to both `ZipFile` and `ZipInfo`
4. **Enhanced Structures**: Support ZIP64 extensions in existing metadata structures
5. **New Structures**: Add ZIP64-specific record types
6. **Constants**: Add ZIP64 threshold constants

These changes maintain full backward compatibility while enabling support for large archives following Python's zipfile API design.