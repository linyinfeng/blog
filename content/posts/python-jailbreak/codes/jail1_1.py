from utils import *
import importlib

def jail1_1(module_name):
    import builtins
    old_list = list
    builtins.list = make_forbidden_function("list", list)
    module = importlib.import_module(module_name)
    builtins.list = old_list
    return module

homework = jail1_1("homework")
homework.answer()
