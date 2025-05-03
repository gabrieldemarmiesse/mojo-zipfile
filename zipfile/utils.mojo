fn _lists_are_equal[
    dtype: DType, //
](a: List[Scalar[dtype]], b: List[Scalar[dtype]]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True
