+++
title = "PEP 484 -- 类型提示"
description = ""
date = 2018-08-06T22:43:43+08:00
author = "Lin Yinfeng"
draft = true
[taxonomies]
categories = ["翻译"]
tags = ["python", "类型系统"]
[extra]
+++

本文为 [PEP 484 -- Type Hints][pep-484] 的中文翻译。

<!-- more -->

版权：本译文位于公有领域（Public Domain）。

本文只求信达，不求雅。译者无法理解原句时将注释并把原文附在括号内，如非必要不在翻译中添加其他的评价。任何错误或建议均可向我的 GitHub 仓库 [linyinfeng/blog][my-github-blog] 发起 Issues 或 PR。

一些词汇对照如下：

- Hint -- 提示
- Annotation/annotate -- 注解
- Evaluate -- 求值
- Reference -- 引用
- Alias -- 别名
- Generics -- 泛型
- Constraint -- 约束
- Metaclass -- 元类

# 摘要

[PEP 3107][pep-3107] 提出了函数注解的语法，但这个语法的语义被故意保持未定义。现在，在静态类型分析上已经有了足够多的第三方用例，社区将从标准库中标准的符号表和基准线（baseline）工具中受益。

这个 PEP 将提出一个暂定的模块来提供这些标准的定义和工具，附带一些在不能使用注解处的约定。

注意，这个 PEP 明确地不阻止注解的其他用法，也不要求或禁止任何特定的对注解的处理，即使它们遵从这个规范。这个 PEP 仅仅使它们工作得更协调，就像 [PEP 333][pep-333] 对 web 框架做的那样。

举个例子，这是一个简单的函数定义，其参数和返回值的类型被定义在注解中：

```python3
def greeting(name: str) -> str:
    return 'Hello ' + name
```

在运行时，函数注解可以通过 \_\_annotations\_\_ 属性访问，但没有类型检查会发生在运行时。相反的，这个提案假设存在一个单独的离线类型检查器，而用户可以自愿地调用它。本质上，这样一个类型检查器能充当一个很强大的 linter（尽管某些用户为了实现强制的契约式设计或者实现 JIT 优化而在运行时使用一个类似的检查器，这当然是可能的，但这些工具还不够成熟)。

这个提案从 [mypy][mypy] 获得了非常多的启发。例如，“整数的序列”可以被写作 Sequence[int]。使用方括号意味着没有新的语法被加入到语言中。这个例子使用了一个从一个纯 Python 模块 typing 中导入的定制类型 Sequence。Sequence[int] 记号在元类中实现了 \_\_getitem\_\_，能在运行时工作（但它的意义主要在于配合一个离线类型检查器）。

这个类型系统支持 unions，泛型和一个特殊的包含（换句话说，可以被赋给或赋给）所有类型的叫做 Any 的类型。后面一个特性来自 gradual typing 的概念。gradual typing 在 [PEP 483][pep-483] 中被解释。

我们借鉴或者可以与之比较和对比的的其他实现类型提示的方式在 [PEP 482][pep-482] 中被描述。

# 意向和目标

[PEP 3107][pep-3107] 添加了对函数定义中的任意注解的支持。尽管之前没有对这些注解附加任何意义，始终存在一个隐藏的使用他们用来作类型提示的目标 [\[gvr-artima\]][gvr-artima]，这也是 [PEP 3107][pep-3107] 第一个可能的用例。

本 PEP 的目标是提供标准的类型注解语法，扩展 Python 代码，带来更简单的静态分析和重构，可能的运行时类型检查，和（也许在某些情景中）利用类型信息的代码生成。

在这些目标中，静态分析是最重要的。这包括支持诸如 mypy 的离线类型检查器，也包括提供能被 IDE 用作代码补全和重构的一种标准记号。

## 非目标

尽管这个提出的 typing 模块将包含一些运行时类型检查的构建设施——特别是 get_type_hints() 函数——要支持运行时类型检查功能仍然需要开发第三方包，例如使用装饰器或元类。使用类型提示于性能优化留作一个给读者的锻炼。

必须强调，__Python 将仍是一个动态类型语言，并且作者们没有希望开始强制类型提示，即使按照慣例（even by convention）__。

# 注解的意思

任何没有注解的函数应该被任何类型检查器当作有尽可能最通用的类型或者被忽略。带有 @no_type_check 装饰器的函数应该被当作没有注解。

推荐但不强制被检查的函数带有所有参数和返回值的注解。对于一个被检查的函数，默认的参数和返回值的注解为 Any。一个例外是实例和类方法的第一个参数。对于实例的方法，如果它没有被注解，将被认为有实例的类的类型；对于类方法，如果它没有被注解，将被认为有一个关联包含这个类方法的的类对象的类型对象（type object）类型。例如，在类 A 中，实例方法的第一个参数拥有隐藏类型 A，类方法的第一个参数的精确类型无法被可用的类型记号表示。

（注意，\_\_init\_\_的返回值应该被显式注解为 -> None。原因是微妙的。如果 \_\_init\_\_ 隐含了 -> None 返回值，那么一个没有参数也没有被注解的 \_\_init\_\_ 是否应该被检查？相比于保留这个二义性或者为这个异常情况提出一个例外行为，我们简单地要求 \_\_init\_\_ 有一个返回值注解。这样它的默认行为就与其他方法一致了。）

一个类型检查器应该检查被检查函数的函数体，使函数体与给定的注解一致。注解也可能被用来检查在别的被检查函数中出现的调用。

类型检查器应该有必要尝试推导尽可能多的信息。最低要求是处理内置装饰器 @property，@staticmethod 和 @classmethod。

# 类型定义语法

这个语法通过一系列拓展增强了 [PEP 3107][pep-3107] 样式的注解，这些扩展将在之后被介绍。在这个语法的基础形式中，使用将类作为类型提示填充到函数注解槽中：

```python3
def greeting(name: str) -> str:
    return 'Hello ' + name
```

这表示参数 name 的类型是 str。以此类推，期望的返回值类型为 str。

类型为参数类型的子类型的表达式也可以被参数接受。

## 可被接受的类型提示

类型提示可以是内置类（包括定义在标准库和第三方扩展模块中的），抽象基类，types 模块中的类型和用户定义的类（包括标准库和第三方模块中的）。

尽管多数时候注解都是类型提示的最好形式，但是有时候更合适的方法是将类型提示书写在特殊的注释或者一个单独的 stub 文件中。（继续阅读以查看例子。）

注解必须是有效的表达式，并且在函数定义时（继续阅读以查看前向引用）求值且不抛出异常。

注解应该保持简单，否则静态分析工具可能无法解释它们的值。例如，动态计算的值不太可能被理解。（这个一个故意的有些含混不清的要求，详细的限制可能在未来的版本中被加入，这仍需要讨论来保证（原文：specific inclusions and exclusions may be added to future versions of this PEP as warranted by the discussion）。）

额外的，可以使用以下特殊的结构体：None，Any，Union，Tuple，Callable，所有的 ABCs（Abstract Base Class, 抽象基类）和 typing 中导出的具体类型的替代（例如 Sequence 和 Dict），类型变量和类型别名。

所有用来支持以下章节中描述的特性的新的名字都可从 typing 模块中找到。

## 使用 None

当在类型提示中使用，表达式 None 被认为等价于 type(None)。

## 类型别名

简单的变量赋值可以定义类型别名：

```python3
Url = str

def retry(url: Url, retry_count: int) -> None: ...
```

注意，我们推荐将别名的单词首字母大写，因为它们表示用户定义类型，和用户定义类一样，典型地以这种方式命名。

类型别名可以和注解中的类型提示一样复杂——在类型注解中可用的在类型别名中也可用。

```python3
from typing import TypeVar, Iterable, Tuple

T = TypeVar('T', int, float, complex)
Vector = Iterable[Tuple[T, T]]

def inproduct(v: Vector[T]) -> T:
    return sum(x*y for x, y in v)
def dilate(v: Vector[T], scale: T) -> Vector[T]:
    return ((x * scale, y * scale) for x, y in v)
vec = []  # type: Vector[float]
```

等价于：

```python3
from typing import TypeVar, Iterable, Tuple

T = TypeVar('T', int, float, complex)

def inproduct(v: Iterable[Tuple[T, T]]) -> T:
    return sum(x*y for x, y in v)
def dilate(v: Iterable[Tuple[T, T]], scale: T) -> Iterable[Tuple[T, T]]:
    return ((x * scale, y * scale) for x, y in v)
vec = []  # type: Iterable[Tuple[float, float]]
```

## Callable

要求传递回调函数的框架可以使用 Callable[[Arg1Type, Arg2Type], ReturnType] 加入类型提示，例如：

```python3
from typing import Callable

def feeder(get_next_item: Callable[[], str]) -> None:
    # 函数体

def async_query(on_success: Callable[[int], None],
                on_error: Callable[[int, Exception], None]) -> None:
    # 函数体
```

可以通过在参数列表处使用省略号声明一个仅指定了返回值的 callable：

```python3
def partial(func: Callable[..., str], *args) -> Callable[..., str]:
    # 函数体
```

注意省略号周围没有方括号。这个情况下这个回调函数的参数完全没有被限定（同时关键字参数也是可接受的）。

因为使用带有关键字参数的回调函数并不是一个常见的用例，所以目前不支持使用 Callable 指定关键字参数的类型。类似的，也没有对可变数量参数的类型的支持。

因为 typing.Callable 作为 collections.abc.Callable 的替代身兼二职，顺从 isinstance(x, collections.abc.Callable) 实现了 isinstance(x, typing.Callable) 。但是不支持 isinstance(x, typing.Callable[...])。

## 泛型

因为容器内对象的的类型信息被保持在容器内，无法用通用的方法被静态地推导
，扩展了抽象基类以支持 subscription 来标记容器元素期望类型（原文：abstract base classes have been extended to support subscription to denote expected types for container elements）。举个例子：

```python3
from typing import Mapping, Set

def notify_by_email(employees: Set[Employee], overrides: Mapping[str, str]) -> None: ...
```

泛型可以通过一个新的工厂函数被参数化（原文：Generics can be parameterized by using a new factory），这个函数 TypeVar 包含在 typing 中，例如：

```python3
from typing import Sequence, TypeVar

T = TypeVar('T')      # 声明类型变量

def first(l: Sequence[T]) -> T:   # 泛型函数
    return l[0]
```

在这个例子中，表示的类型约束是函数 first 的返回值类型与容器 l 中包含的元素的类型相同。

一个 TypeVar() 表达式必须总是被直接赋给一个变量（不应该作为一个大表达式的一部分）。TypeVar 的参数必须是一个和赋给的变量名相同的字符串。类型变量不能被重定义。

TypeVar 支持约束参数类型到一个固定的可能类型集合（注意，这些类型不能被类型变量参数化）。举个例子，我们可以定义一个仅包含 str 和 bytes 的类型变量。默认地，一个类型变量包含所有可能的类型。一个约束了类型变量的例子：

```python3
from typing import TypeVar

AnyStr = TypeVar('AnyStr', str, bytes)

def concat(x: AnyStr, y: AnyStr) -> AnyStr:
    return x + y
```

函数 concat 能与被两个 str 参数或两个 bytes 参数一起被调用，但是不能是 str 和 bytes 的混合。

如果要使用约束，应该使用至少两个约束。指定单一约束是不被允许的。

在类型变量的上下文中，用作约束的类型的子类型将被当作它们各自显式列出的基类。考虑如下例子：

```python3
class MyStr(str): ...

x = concat(MyStr('apple'), MyStr('pie'))
```

这个调用是合法的但是类型变量 AnyStr 将被绑定 str 而不是 MyStr。事实上，推导出的赋给 x 的返回值类型也是 str。

额外地，Any 对所有类型变量都合法。考虑：

```python3
def count_truthy(elements: List[Any]) -> int:
    return sum(1 for elem in elements if elem)
```

这等价为省略泛型记号直接书写 elements: List。

## 用户定义泛型

你可以将 Generic 作为基类定义一个泛型类型。例如：

```python3
from typing import TypeVar, Generic
from logging import Logger

T = TypeVar('T')

class LoggedVar(Generic[T]):
    def __init__(self, value: T, name: str, logger: Logger) -> None:
        self.name = name
        self.logger = logger
        self.value = value

    def set(self, new: T) -> None:
        self.log('Set ' + repr(self.value))
        self.value = new

    def get(self) -> T:
        self.log('Get ' + repr(self.value))
        return self.value

    def log(self, message: str) -> None:
        self.logger.info('{}: {}'.format(self.name, message))
```

将 Generic[T] 作为基类定义了类 LoggedVar 接受一个类型参数 T。这也使 T 在类内成为一个合法的类型。

Generic 基类使用一个定义了 __getitem__ 的元类，因此 LoggedVar[t] 是一个合法的类型：

```python3
from typing import Iterable

def zero_all_vars(vars: Iterable[LoggedVar[int]]) -> None:
    for var in vars:
        var.set(0)
```

一个泛型类型可以有任意数量的类型变量，并且这些变量可能是被约束的。以下例子是合法的：

```python3
from typing import TypeVar, Generic
...

T = TypeVar('T')
S = TypeVar('S')

class Pair(Generic[T, S]):
    ...
```

Generic 中的每一个类型变量都必须是不同的。以下例子是不合法的：

```python3
from typing import TypeVar, Generic
...

T = TypeVar('T')

class Pair(Generic[T, T]):   # INVALID
    ...
```

在一个简单地情形下，当你从其他泛型类中派生子类，并且指定了这个泛型类的类型变量时，Generic[T] 是冗余的：

```python3
from typing import TypeVar, Iterator

T = TypeVar('T')

class MyIter(Iterator[T]):
    ...
```

这个类的定义等价于：

```python3
class MyIter(Iterator[T], Generic[T]):
    ...
```

可以在多重继承中使用 Generic：

```python3
from typing import TypeVar, Generic, Sized, Iterable, Container, Tuple

T = TypeVar('T')

class LinkedList(Sized, Generic[T]):
    ...

K = TypeVar('K')
V = TypeVar('V')

class MyMapping(Iterable[Tuple[K, V]],
                Container[Tuple[K, V]],
                Generic[K, V]):
    ...
```

不指定类型参数派生一个泛型类将假定每一个类型参数都是 Any。在下面的例子中，MyIterable 不是一个泛型但隐式地继承自 Iterable[Any]：

```python3
from typing import Iterable

class MyIterable(Iterable):  # Same as Iterable[Any]
    ...
```

不支持泛型元类

## 类型参数的作用域规则

类型参数遵从普通的名字决议（name resolution）规则。然而，在静态类型检查的情形下有一些特殊情况：

- 一个在泛型函数中使用的类型变量在同一个代码块中能被推导表示成不同的类型。例如：
    ```python3
    from typing import TypeVar, Generic

    T = TypeVar('T')

    def fun_1(x: T) -> T: ... # T 在这
    def fun_2(x: T) -> T: ... # 和在这可以不同

    fun_1(1)                  # 正确, T 被推导为 int
    fun_2('a')                # 正确, 现在 T 是 str
    ```
- 类内方法中的与参数化类的类型参数相同的类型变量始终绑定到这个变量。例如：
    ```python3
    from typing import TypeVar, Generic

    T = TypeVar('T')

    class MyClass(Generic[T]):
        def meth_1(self, x: T) -> T: ... # T 在这
        def meth_2(self, x: T) -> T: ... # 和在这始终相同

    a = MyClass() # type: MyClass[int]
    a.meth_1(1)   # 正确
    a.meth_2('a') # 错误
    ```
- 类内方法中不是参数化类的参数的类型变量使这个方法变为这个类型变量的泛型函数：
    ```python3
    T = TypeVar('T')
    S = TypeVar('S')
    class Foo(Generic[T]):
        def method(self, x: T, y: S) -> S:
            ...

    x = Foo() # type: Foo[int]
    y = x.method(0, "abc") # 推导出的 y 类型为 str
    ```
- 未绑定的类型变量不应该出现在泛型函数的函数体或者类内除了函数定义的部分:
    ```python3
    T = TypeVar('T')
    S = TypeVar('S')

    def a_fun(x: T) -> None:
        # 这是正确的
        y = [] # type: List[T]
        # 但这是错误的
        y = [] # type: List[S]

    class Bar(Generic[T]):
        # 这也是错误的
        an_attr = [] # type: List[S]

        def do_something(x: S) -> S: # 但这是正确的
            ...
    ```
- 泛型函数内出现的泛型类定义不能使用用来参数化泛型函数的类型变量：
    ```python3
    from typing import List

    def a_fun(x: T) -> None:

        # 这是正确的
        a_list = [] # type: List[T]
        ...

        # 但这是错误的
        class MyGeneric(Generic[T]):
            ...
    ```
- 嵌套泛型类不能使用相同的类型变量。外层泛型类的类型变量的作用域不覆盖内层的：
    ```python3
    T = TypeVar('T')
    S = TypeVar('S')

    class Outer(Generic[T]):
        class Bad(Iterable[T]):      # 错误
            ...
        class AlsoBad:
            x = None # type: List[T] # 也是错误的

        class Inner(Iterable[S]):    # 正确
            ...
        attr = None # type: Inner[T] # 也是正确的
    ```

## 实例化类型类和类型擦除

用户定义的类型类可以被实例化。假设我们写了一个 Node 类继承 Generic[T]：

```python3
from typing import TypeVar, Generic

T = TypeVar('T')

class Node(Generic[T]):
    ...
```

[my-github-blog]: https://github.com/linyinfeng/blog
[mypy]: http://mypy-lang.org
[pep-3107]: https://www.python.org/dev/peps/pep-3107
[pep-333]: https://www.python.org/dev/peps/pep-0333
[pep-482]: https://www.python.org/dev/peps/pep-0482
[pep-483]: https://www.python.org/dev/peps/pep-0483
[pep-484]: https://www.python.org/dev/peps/pep-0484
[gvr-artima]: http://www.artima.com/weblogs/viewpost.jsp?thread=85551