from parsing_floats.parsing_floats import _atof
from pathlib import Path
import benchmark

def main():
    canada_as_txt = Path("canada.txt").read_text()

    list_of_floats = canada_as_txt.splitlines()
    number_of_bytes = 0
    for line in list_of_floats:
        number_of_bytes += len(line[])
    
    # Leverage SSO for more consistency in the benchmark
    list_of_floats_inline = List[String]()
    for line in list_of_floats:
        list_of_floats_inline.append(String(line[]))

    @parameter
    fn parsing_all_numbers() raises:
        for line in list_of_floats_inline:
            value = _atof(line[])
            benchmark.keep(value)

    
    report = benchmark.run[parsing_all_numbers](min_runtime_secs=8)
    report.print_full()

    print("MB/s: ", number_of_bytes / 1e6 / report.min())
