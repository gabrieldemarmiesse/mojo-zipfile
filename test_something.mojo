import zipfile
from testing import assert_equal, assert_true
from python import Python


def test_is_zipfile_valid():
    py_zipfile = Python.import_module("zipfile")
    py_tempfile = Python.import_module("tempfile")
    # Create a temporary zip file
    tmp_dir = py_tempfile.TemporaryDirectory()
    tmp_zipfile_path = tmp_dir.name + "/test.zip"
    open_zip = py_zipfile.ZipFile(tmp_zipfile_path, "w")
    open_zip.writestr("test.txt", "This is a test file.")
    open_zip.close()
    # Check if the created file is a zip file
    assert_true(zipfile.is_zipfile(String(tmp_zipfile_path)), "File should be a zip file")
    tmp_dir.cleanup()

def test_identical_analysis():

    open_zip_mojo = zipfile.ZipFile("/tmp/test.zip", "r")

    assert_equal(open_zip_mojo.end_of_central_directory.number_of_this_disk, 0)
    assert_equal(open_zip_mojo.end_of_central_directory.number_of_the_disk_with_the_start_of_the_central_directory, 0)
    assert_equal(open_zip_mojo.end_of_central_directory.total_number_of_entries_in_the_central_directory_on_this_disk, 13)
    assert_equal(open_zip_mojo.end_of_central_directory.total_number_of_entries_in_the_central_directory, 13)
    assert_equal(open_zip_mojo.end_of_central_directory.size_of_the_central_directory, 1453)
    assert_equal(open_zip_mojo.end_of_central_directory.offset_of_starting_disk_number, 11798996)
    assert_equal(len(open_zip_mojo.end_of_central_directory.zip_file_comment), 0)

    assert_equal(len(open_zip_mojo.infolist()), 13)
    reader = open_zip_mojo.open(open_zip_mojo.infolist()[0], "r")
    bytes_of_file = reader.read()

    open_zip_mojo.close()


def test_read_content():
    Python.add_to_path("./")
    trying_stuff = Python.import_module("trying_stuff")
    trying_stuff.dodo()
    
    open_zip_mojo = zipfile.ZipFile("/tmp/dodo.zip", "r")
    assert_equal(len(open_zip_mojo.infolist()), 1)
    hello_file = open_zip_mojo.open("hello.txt", "r")
    content = hello_file.read()
    assert_equal(String(bytes=content), "hello world!")
    open_zip_mojo.close()




def main():
    test_is_zipfile_valid()
    test_identical_analysis()
    test_read_content()
    print("All tests passed!")