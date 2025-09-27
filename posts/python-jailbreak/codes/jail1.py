from utils import *
import importlib

def jail1(module):
    import builtins
    builtins.list = make_forbidden_function("list", list)
    return importlib.import_module(module)

homework = jail1("homework")
homework.answer()
