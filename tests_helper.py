import zipfile

def create_hello_world_zip(path: str):
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("hello.txt", "hello world!")


def create_complicated_zip(path: str):
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("hello.txt", "hello world!")
        zf.writestr("foo/bar.txt", "foo bar")
        zf.writestr("foo/baz.txt", "foo baz")
        zf.writestr("qux.txt", "qux")


def check_empty_zip(path: str):
    assert zipfile.is_zipfile(path)
    with zipfile.ZipFile(path, "r") as zf:
        assert len(zf.namelist()) == 0


def create_empty_zip(path: str):
    with zipfile.ZipFile(path, "w") as zf:
        pass


def verify_hello_world_zip(path: str):
    assert zipfile.is_zipfile(path)
    with zipfile.ZipFile(path, "r") as zf:
        assert len(zf.namelist()) == 1
        assert zf.read("hello.txt") == b"hello world!"


def create_hello_world_zip_with_deflate(path: str):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("hello.txt", "hello world!", compress_type=zipfile.ZIP_DEFLATED)
