from utils import *
import importlib.util as imp_util
import inspect

def forbidden_builtins(names):
    builtins_dict = inspect.currentframe().f_builtins
    result = builtins_dict.copy()
    for name in names:
        result[name] = make_forbidden_function(name, builtins_dict[name])
    return result

def restricted_import(module_name, names):
    spec = imp_util.find_spec(module_name)
    module = imp_util.module_from_spec(spec)
    module.__builtins__ = forbidden_builtins(names)
    spec.loader.exec_module(module)
    return module

def jail2(module):
    return restricted_import(module, ["list"])

homework = jail2("homework")
homework.answer()
a = list() # homework 之外的代码不受影响
