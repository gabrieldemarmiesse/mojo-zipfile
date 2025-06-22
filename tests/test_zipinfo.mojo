import zipfile
from testing import assert_equal, assert_true, assert_raises
from python import Python
from pathlib import Path


def test_identical_analysis():
    Python.add_to_path("./tests")
    tests_helper = Python.import_module("tests_helper")
    file_path = "/tmp/test8.zip"
    tests_helper.create_complicated_zip(file_path)

    open_zip_mojo = zipfile.ZipFile(file_path, "r")

    assert_equal(open_zip_mojo.end_of_central_directory.number_of_this_disk, 0)
    assert_equal(
        open_zip_mojo.end_of_central_directory.number_of_the_disk_with_the_start_of_the_central_directory,
        0,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk,
        4,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.total_number_of_entries_in_the_central_directory,
        4,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.size_of_the_central_directory,
        222,
    )
    assert_equal(
        open_zip_mojo.end_of_central_directory.offset_of_starting_disk_number,
        187,
    )
    assert_equal(
        len(open_zip_mojo.end_of_central_directory.zip_file_comment), 0
    )
    infolist = open_zip_mojo.infolist()

    assert_equal(len(infolist), 4)
    assert_equal(infolist[0].filename, "hello.txt")
    assert_equal(infolist[1].filename, "foo/bar.txt")
    assert_equal(infolist[2].filename, "foo/baz.txt")
    assert_equal(infolist[3].filename, "qux.txt")
    # check crc computation
    for zipinfo in infolist:
        file_like = open_zip_mojo.open_to_read(zipinfo, "r")
        content = file_like.read()

    open_zip_mojo.close()
