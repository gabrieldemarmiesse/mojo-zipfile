import zipfile

def create_hello_world_zip(path: str):
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("hello.txt", "hello world!")
    print("done!")
