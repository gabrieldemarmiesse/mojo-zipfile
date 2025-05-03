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
