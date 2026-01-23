+++
title = "不要在 Python 里 exec/eval/import 不可信代码"
description = "在同一个 Python 解释器中为部分代码做沙箱是不现实的"
date = 2025-09-27 13:11:10+08:00
updated = 2025-09-27 13:11:10+08:00
author = "Yinfeng"
draft = false
[taxonomies]
categories = ["笔记"]
tags = ["Python"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

在同一个 Python 解释器中为部分代码做沙箱是不现实的。

<!-- more -->

## 造监狱

最近遇到一个需求，限制 Python 代码中某些 builtins 的使用，具体的，我想限制在代码中使用列表，包括 `list` 和 `[..]`。
用户代码放置在 `homework.py` 文件中。评测程序不是我写的，但总而言之，评测代码会 `import homework` 然后调用 `homework` 中定义的函数并比较输出。

```python
# homework.py
{{ include(path="./codes/homework.py", trimmed=true) }}
```

### 尝试 1

因为 Python 是如此的动态，以至于我们可以直接修改 `builtins`.

```python
# utils.py
{{ include(path="./codes/utils.py", trimmed=true) }}
```

```python
# jail1.py
{{ include(path="./codes/jail1.py", trimmed=true)}}
```

```console
$ python jail1.py
You should not use 'list' in this problem.
```

因为评测代码比较的是输出，因此使 `list` 函数额外输出一句话完全可以阻止代码通过评测。

问题在于，修改 builtins 是全局的，调用方也会被影响。

```console
$ python -i jail1.py
You should not use 'list' in this problem.
Failed calling sys.__interactivehook__
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
You should not use 'list' in this problem.
Traceback (most recent call last):
  File "<frozen site>", line 520, in register_readline
  File "/nix/store/829wb290i87wngxlh404klwxql5v18p4-python3-3.13.7/lib/python3.13/_pyrepl/readline.py", line 32, in <module>
    from dataclasses import dataclass, field
  File "/nix/store/829wb290i87wngxlh404klwxql5v18p4-python3-3.13.7/lib/python3.13/dataclasses.py", line 3, in <module>
    import copy
  File "/nix/store/829wb290i87wngxlh404klwxql5v18p4-python3-3.13.7/lib/python3.13/copy.py", line 112, in <module>
    d[list] = list.copy
AttributeError: 'function' object has no attribute 'copy'
warning: can't use pyrepl: function() argument 'code' must be code, not str
>>>
```

可见修改 builtins 直接炸烂了 Python 的 REPL。因为 `list` 是个 class，而我们把它改成了一个 function。

在 `importlib.import_module` 后改回 builtins 也是不行的，因为 `homework` module 的 builtins 对象和全局的是同一个。
改回来之后就把监狱拆了。

```python
# jail1_1.py
{{ include(path="./codes/jail1_1.py", trimmed=true)}}
```

```console
$ python jail1_1.py
$ # nothing
```

### 尝试 2

因为 Python 是如此的动态，我们当然可以给不同的模块指定不同的 builtins。

```python
# jail2.py
{{ include(path="./codes/jail2.py", trimmed=true)}}
```

```console
$ python jail2.py
You should not use 'list' in this problem.
```

任务完成！但是等等，homework 里除了 `a = list()`，还有一句 `a = [ ]`。怎么只打出了一句话？
看起来 `[...]` 语法并不调用 `list`？

看起来 `[...]` 的创建就是一个魔法，没有办法去修改它。

### 尝试 3

因为 Python 是如此的动态，它提供了 [`sys.setprofile`](https://docs.python.org/3/library/sys.html#sys.setprofile) 能追踪各种事件。
其中的 `c_call` 事件让我眼前一亮。

> `c_call`: A C function is about to be called. This may be an extension function or a built-in. _arg_ is the C function object.

看起来，列表操作会产生 `c_call` 事件（？），我在这些事件发生时打印一些东西不就行了么？
让我们试试：

```python
# jail3.py
{{ include(path="./codes/jail3.py", trimmed=true)}}
```

```console
$ python jail3.py
<frame at 0x7f87a99f0040, file '.../codes/homework.py', line 1, code answer>, call, None
<frame at 0x7f87a99f0040, file '.../codes/homework.py', line 4, code answer>, return, None
<frame at 0x7f87a99f0040, file '.../codes/jail3.py', line 10, code <module>>, return, None
```

我明明已经追踪了全部事件，也创建，尝试读取了列表，但是我那么大一堆 `c_call` 事件呢？
看起来 CPython 根本不会让 profile 函数追踪 `[...]`，`list[n]` 这些操作，列表操作并不总是会产生 `c_call` 事件。

### 尝试 4

最后，看来似乎只能过滤源码了，我认为这是非常不优雅的方法，但没办法了，配合尝试 2，这也是我最终使用的办法。
毕竟作业的对象是新生，只要让绕过限制所需的努力比好好做做作业更大就行了。

```python
# jail4.py
{{ include(path="./codes/jail4.py", trimmed=true)}}
```

```console
$ python jail4.py
You should not use 'list' in this problem.
Traceback (most recent call last):
  File ".../codes/jail3.py", line 9, in <module>
    check_no_square_brackets(jail2.homework.answer)
    ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^
  File ".../codes/jail3.py", line 6, in check_no_square_brackets
    raise RuntimeError("You should not use square brackets `[...]` in this problem")
RuntimeError: You should not use square brackets `[...]` in this problem
```

## 越狱

因为 Python 是如此的动态，即使我们把一切预先定义的东西都禁止掉，但除了过滤源码，看起来没有什么办法去阻止用户重新获得 builtins。

让我们建一个最严格的 `jail`：什么都不给。

```python
# jail.py
{{ include(path="./codes/jail.py", trimmed=true)}}
```

```console
$ python -i jail.py
>>> jail("import builtins")
Traceback (most recent call last):
  File "<python-input-0>", line 1, in <module>
    jail("import builtins")
    ~~~~^^^^^^^^^^^^^^^^^^^
  File "/home/yinfeng/Source/blog/content/posts/python-jailbreak/codes/jail.py", line 6, in jail
    exec(code, globals={"__builtins__": {}})
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "<string>", line 1, in <module>
ImportError: __import__ not found
```

如何越狱？以下内容参考自 <https://github.com/jailctf/pyjailbreaker>。

1. 获得 object。
2. 获得目前 `object` 的所有的子类，并从中找一个用 `def` 定义了函数的类，获得这个函数。
   因为 `def` 定义的函数带有 `__globals__` 属性，其中包含了定义时的 `globals()`。
   我们希望还 `__globals__` 里包含 `sys` 模块，一个常见的选择是 `os._wrap_close`。
3. 从 `__globals__` 里拿到 `sys` 模块。
4. 从 `sys.modules` 里拿到目前导入的其他模块，比如 `builtins`。
5. 用 `builtins.__import__` 导入任何想要的模块，比如 `inspect`。
6. 因为 Python 是如此的动态，我们直接用 `inspect` 修改栈帧，就能把环境恢复了。

```python
# jailbreak.py
{{ include(path="./codes/jailbreak.py", trimmed=true) }}
```

```console
$ python
>>> import jail
>>> jail.jail(open('jailbreak.py').read())
free!
```
