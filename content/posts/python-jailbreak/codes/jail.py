def jail(code):
    # disable everything
    # https://docs.python.org/3/library/functions.html#exec
    # If the globals dictionary does not contain a value for the key __builtins__,
    # a reference to the dictionary of the built-in module builtins is inserted under that key.
    exec(code, globals={"__builtins__": {}})
