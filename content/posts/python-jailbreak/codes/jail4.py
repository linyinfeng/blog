import re
import inspect

def check_no_square_brackets(function):
    if len(re.findall(r'\[|\]', inspect.getsource(function), re.M)) != 0:
        raise RuntimeError("You should not use square brackets `[...]` in this problem")

import jail2
check_no_square_brackets(jail2.homework.answer)
