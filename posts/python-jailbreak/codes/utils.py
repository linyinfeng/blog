def make_forbidden_function(name, original):
    def f(*args, **kwargs):
        # print some
        print(f"You should not use '{name}' in this problem.")
        return original(*args, **kwargs)
    return f
