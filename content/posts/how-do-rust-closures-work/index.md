+++
title = "Rust 闭包笔记"
description = ""
date = 2019-03-15T11:06:01+08:00
author = "Lin Yinfeng"
draft = false
[taxonomies]
categories = ["笔记"]
tags = ["Rust", "闭包", "函数式编程"]
[extra]
license_image = "![Creative Commons License](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png)"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

近日在学习 Rust 语言。Rust 语言的闭包设计非常有趣，一方面，它看起来非常复杂，为了支持闭包设计了三种不同的 trait，`Fn`、`FnMut` 和 `FnOnce`；一方面其设计又透露出了语言设计中闭包的本质。通过考察 Rust 闭包的设计，我们能更好的理解闭包到底是什么，在拥有生存期和借用检查的语言 Rust 中，闭包如何工作。

本文将在 Rust 下实现一个能够阐述闭包工作原理的朴素版闭包（也是一个 Boxed Closure）。并在实现的基础上对 Rust 闭包作进一步探究。

<!-- more -->

## 闭包的概念

闭包（Closure）是一个在计算机科学中广泛使用的概念，又叫词法闭包（Lexical Closure）。即闭包能够“捕获”词法作用域中的变量，这是与编译时代码的结构直接相关的。也就是说，在**声明闭包而不是闭包被调用的时候**，其函数体可以捕获外围词法作用域中的变量。

### 闭包是匿名函数吗？

这两个概念之间没有什么关系，就以[维基百科 Closure 词条](https://en.wikipedia.org/wiki/Closure_(computer_programming))上举的一个常见的 `adder` 例子来说：

```python
# Python
def f(x):
    def g(y):
        return x + y
    return g
def h(x):
    return lambda y: x + y
a = f(1)
b = h(1)
# ...
```

在这两个例子中，a 和 b 均为闭包，JavaScript 中的 `function` 也是一样，是不是闭包当然和没有名字并没有理论和实践上的联系。当然，可以说对于将函数设计为一等对象（First class object）的语言，函数是否匿名一般不产生任何实际区别。

### 通常形式

对于函数基于栈的且没有垃圾回收（Garbage Collection）的语言，往往无法实现完全的闭包。这是因为，闭包从语义上应当能够延长其捕获的变量的生存期（lifetime）到长于或等于闭包的生存期。对于广泛利用栈进行函数局部变量分配和流程控制的语言，函数的局部变量的生存期严格与函数调用栈绑定，即从函数调用到函数返回（严格来说是局部变量内存的生存期，显然局部变量的生存期必然小于等于其内存的生存期）。

举例来说，有上述特征的 C++ 的闭包就易于引发为定义行为（Undefined Behavior）。因为其引用捕获的局部变量的生存期无法自动延长。而例如 Java，JavaScript 和 Go 的闭包就不会，因为其编译器（对于 JavaScript 来说往往是 JIT 编译器）将对局部变量做逃逸分析（Escape Analysis）。将可能“逃逸”的变量生存期延长，由垃圾回收器而不是函数调用栈维护其生存期。又或者将所有局部变量分配在堆上由垃圾回收器维护也是一样。

即使如此，各个语言下闭包的基本表现是不变的。闭包通常被实现为其捕获的词法环境和一个函数的组合。

考虑一个名为 closure，调用方式为 `closure(arg1, arg2, ..., argN)`，其捕获了变量 `env_arg1`, `env_arg2`, ..., `env_argM`。可以将其实现为一个函数和其词法环境的组合：

```text
{
    env: (env_arg1, ..., env_argM),
    f: fn(env_arg1, ..., env_argM, arg1, ..., argN),
}
```

## 一个朴素 Rust 闭包的设计与实现

理解了闭包是什么，我们就可以写出一个朴素的闭包。最终我们实现的闭包**用起来**将会有点繁琐（无自动类型推导），但行为几乎与内置闭包一致。最终实现将会看起来像一个类似于 C++ 14 Generalized Lambda Capture 特性的闭包宏。

另外，虽然这个闭包看起来将与内置闭包差不多，实际上的区别是有的，不只是无类型推导这一点，这些内容将在实现后一一阐述。

因为提到了 C++ 14 Generalized Lambda Capture, 所以先解释一下这是什么特性，以下是一个例子：

```cpp
auto c = [ v = std::move(v) ] { // A generalized capture list
    do_something_with( v )
};
```

在 C++ 14 之前，捕获列表中只能按值或者按引用捕获变量，通过 Generalized Lambda Capture，C++ 实现了捕获任意表达式，同时也顺便实现了移动捕获。

其实，Rust 的闭包与 C++ **语义和使用上的设计**几乎可以说是非常相似，但是由于 Rust 做出的内存安全（Memory Safe）承诺，引入了三个不同的 trait。将这个放在一边，我们按朴素思想实现一个闭包的结构，或者说数据。

```rust
/// Wrong implementation
pub struct Closure<Env, Args, Out> {
    env: Env,
    f: fn(Env, Args) -> Out,
}
```

由于 Rust 中有元组的存在，我们可以简单地把所有捕获变量的类型用一个类型变量（Type Parameter）`Env` 表示，所有调用参数的类型用 `Args` 表示，最后单独用 `Out` 表示调用结果类型。

考量这个设计，闭包含有一个环境和指针合理吗？从**实现功能的角度**是合理的（后面我们将看到这个设计的问题所在）。

继续考量这个设计。将环境实现为 `Env` 类型是否合理？合理，闭包应该拥有（Own）其捕获的内容（即使拥有的是引用（Reference）也是拥有）。这些内容的生存期应与闭包是相同的。将函数设计为 `fn(Env, Args) -> Out` 是否合理？对于返回值来说肯定是合理的，对于 `Args` 来说也是，因为函数调用的时候将拥有其参数（即使拥有的是引用）。对于拥有引用的概念，可以举一个例子：

```rust
let v1 = String::new();
let v2 = String::new();
let mut v3 = String::new();
let t = (v1, &v2, &mut v3); // Type: (String, &String, &mut String)
```

构造的 tuple 字面量按语义来说移动给了变量 t，其包含两个 `String` 引用并拥有一个 `String`。

但是 `Env` 的设计是不合理的，这样设计意味着函数将获得闭包中 Closure 的所有权并不归还，这样此闭包将只能调用一次。Rust 中，变量可以通过 move, `&mut` 和 `&` 方式传递入函数。这三种方式在 Rust 现行类型系统中是无法统一的。因为 move 闭包将获得环境的所有权，`&mut` 闭包将造成对其环境的可变借用（Mutable borrowing），`&` 闭包将造成对其环境的不可变借用（Immutable borrowing）。Rust 的生存期机制和借用检查必须对这三种闭包作出区别，或者说，这三种闭包必然在调用时携带不同的类型信息以用来检查。对比之下，C++ 的闭包则并不区别，`operator()` 的 `this` 类型可以始终为一个指向闭包对象的指针。

区分三种不同的 `Env` 后:

```rust
pub struct MoveClosure<Env, Args, Out> {
    env: Env,
    f: fn(Env, Args) -> Out,
}
pub struct RefMutClosure<Env, Args, Out> {
    env: Env,
    f: fn(&mut Env, Args) -> Out,
}
pub struct RefClosure<Env, Args, Out> {
    env: Env,
    f: fn(&Env, Args) -> Out,
}
```

当我们写出一个闭包，即往往是写出一个函数体时，其携带的函数应该是由编译器自动推导得出的。得益于 Rust 的类型推导机制，Rust 的闭包做到了，而 C++ 的闭包并没有做到，这也是为什么 C++ 需要手动写出捕获列表而 Rust 不用。归根结底，Rust 闭包的这三种类型是由函数体对闭包环境的使用方式决定的。**不要误将 Rust 带有 move 关键字的闭包和 FnOnce 对应**，他们实际上没有什么关系。后面我们可以看到，闭包在捕获时和调用时的行为应该分开分析。

为了使我们的闭包可以被调用，应该实现对应的 trait。由于上述区别，Rust 对可调用对象也无法有类似 C++ `operator()` 的统一的 trait。对三种不同的 `self` 参数必须有三种不同的函数类型。因此，Rust 在 `std::ops` 中定义了 `FnOnce`, `FnMut` 和 `Fn` 三个不同的 trait：

```rust
pub trait FnOnce<Args> {
    type Output;
    extern "rust-call" fn call_once(self, args: Args) -> Self::Output;
}
pub trait FnMut<Args>: FnOnce<Args> {
    extern "rust-call" fn call_mut(&mut self, args: Args) -> Self::Output;
}
pub trait Fn<Args>: FnMut<Args> {
    extern "rust-call" fn call(&self, args: Args) -> Self::Output;
}
```

其中 `extern "rust-call"` 是专用于这几个 trait 的调用约定（Calling Convention，一种 ABI），区别于 Rust 本身的调用约定 `extern "Rust"`。

为了手动为我们的对象实现这三种 trait，我们需要开启两个不稳定的 Rust 特性（Feature）：

```rust
![feature(fn_traits, unboxed_closures)]
```

为三种闭包实现所有可以实现的 trait：

`MoveClosure`:

```rust
impl<Env, Args, Out> FnOnce<Args> for MoveClosure<Env, Args, Out> {
    type Output = Out;
    extern "rust-call" fn call_once(self, args: Args) -> Self::Output {
        (self.f)(self.env, args)
    }
}
```

`RefMutClosure`:

```rust
impl<Env, Args, Out> FnOnce<Args> for RefMutClosure<Env, Args, Out> {
    type Output = Out;
    extern "rust-call" fn call_once(mut self, args: Args) -> Self::Output {
        (self.f)(&mut self.env, args)
    }
}
impl<Env, Args, Out> FnMut<Args> for RefMutClosure<Env, Args, Out> {
    extern "rust-call" fn call_mut(&mut self, args: Args) -> Self::Output {
        (self.f)(&mut self.env, args)
    }
}
```

`RefClosure`:

```rust
impl<Env, Args, Out> FnOnce<Args> for RefClosure<Env, Args, Out> {
    type Output = Out;
    extern "rust-call" fn call_once(self, args: Args) -> Self::Output {
        (self.f)(&self.env, args)
    }
}
impl<Env, Args, Out> FnMut<Args> for RefClosure<Env, Args, Out> {
    extern "rust-call" fn call_mut(&mut self, args: Args) -> Self::Output {
        (self.f)(&self.env, args)
    }
}
impl<Env, Args, Out> Fn<Args> for RefClosure<Env, Args, Out> {
    extern "rust-call" fn call(&self, args: Args) -> Self::Output {
        (self.f)(&self.env, args)
    }
}
```

编写过程中不难发现，所有的 `Fn` 一定能被实现为 `FnMut` 和 `FnOnce`，所有的 `FnMut` 一定能够被实现为 `FnOnce`，反之则不行。对于确定的函数体，Rust 将选择最宽松的一个调用，即按照 `Fn` > `FnMut` > `FnOnce` 的优先级。

最后再给三个结构实现创建闭包的 `new` 函数，作用是隐藏内部环境和函数。

现在我们可以通过翻译一些程序，实际使用上面编写的闭包：

```rust
// 内置闭包
let x = 1i32;
let c = |y| x + y;
assert_eq!(c(1i32), 2);

// 手动实现的闭包
let x = 1i32;
let c = {
    let env = (x,);
    fn f((x,): &(i32,), (y,): (i32,)) -> i32 {
        x + y
    }
    RefClosure::new(env, f)
};
assert_eq!(c(1), 2);
```

注意上例中 `i32` 实现了 `Copy`。

其中 `let c` 后创建闭包的内容其实是模式化的，编写一个简单的 macro_rules 宏将其简化：

```rust
[macro_export] macro_rules! boxed_closure {
    (move [$($env_name:ident: $env_type:ty = $env_exp:expr,)*]
        ($($arg_name:ident: $arg_type:ty,)*) -> $out:ty $body:block) => ({
        fn f(($($env_name,)*): ($($env_type,)*), ($($arg_name,)*): ($($arg_type,)*)) -> $out $body
        $crate::MoveClosure::new(($($env_exp,)*), f)
    });
    (move [$($env_name:ident: $env_type:ty = $env_exp:expr,)*]
        ($($arg_name:ident: $arg_type:ty,)*) $body:block) => ({
        fn f(($($env_name,)*): ($($env_type,)*), ($($arg_name,)*): ($($arg_type,)*)) $body
        $crate::MoveClosure::new(($($env_exp,)*), f)
    });
    (ref mut [$($env_name:ident: $env_type:ty = $env_exp:expr),*,]
        ($($arg_name:ident: $arg_type:ty),*,) -> $out:ty $body:block) => ({
        fn f(($($env_name,)*): &mut ($($env_type,)*), ($($arg_name,)*): ($($arg_type,)*)) -> $out $body
        $crate::RefMutClosure::new(($($env_exp,)*), f)
    });
    (ref mut [$($env_name:ident: $env_type:ty = $env_exp:expr),*,]
        ($($arg_name:ident: $arg_type:ty),*,) $body:block) => ({
        fn f(($($env_name,)*): &mut ($($env_type,)*), ($($arg_name,)*): ($($arg_type,)*)) $body
        $crate::RefMutClosure::new(($($env_exp,)*), f)
    });
    (ref [$($env_name:ident: $env_type:ty = $env_exp:expr),*,]
        ($($arg_name:ident: $arg_type:ty),*,) -> $out:ty $body:block) => ({
        fn f(($($env_name,)*): &($($env_type,)*), ($($arg_name,)*): ($($arg_type,)*)) -> $out $body
        $crate::RefClosure::new(($($env_exp,)*), f)
    });
    (ref [$($env_name:ident: $env_type:ty = $env_exp:expr),*,]
        ($($arg_name:ident: $arg_type:ty),*,) $body:block) => ({
        fn f(($($env_name,)*): &($($env_type,)*), ($($arg_name,)*): ($($arg_type,)*)) $body
        $crate::RefClosure::new(($($env_exp,)*), f)
    });
}
```

上述闭包可被翻译为：

```rust
let x = 1i32;
let c = boxed_closure! {
    ref [x: i32 = x,] (y: i32,) -> i32 {
        x + y
    }
};
assert_eq!(c(1), 2);
```

完整 crate 已经上传到 GitHub 仓库 [linyinfeng/closure](https://github.com/linyinfeng/closure)。注意，这是一个非常简陋的闭包设计，仅仅用于阐述一个典型闭包的工作原理。相比于 Rust 内置闭包来说，它的设计是简洁的，使用是繁琐的，性能是低下的。下面将对 Rust 内置闭包的工作进行分析和探讨，同时也与实现的朴素闭包作比较。

## 内置闭包

### Unboxed

上文实现的闭包实际上与内置闭包非常相似，翻译后使用起来基本没有区别。

但是区别还是有的，首先是先前提到过的没有类型推导，所有捕获和类型都必须显示写出。

而最重要的一点是上文偶尔提到的 boxed 和 unboxed，这是什么意思呢。可以试验取上文实现的闭包的一个结构的大小和内置闭包的大小作比较：

```rust
#![feature(core_intrinsics)]
use boxed_closure::boxed_closure;

fn type_of<T>(_: &T) -> &'static str {
    unsafe { std::intrinsics::type_name::<T>() }
}

fn size_of<T>(_: &T) -> usize {
    std::mem::size_of::<T>()
}

fn main() {
    let mut s = String::from("Hello");
    {
        let mut c = || s.push('!');
        println!("Type of a closure c: {}", type_of(&c));
        println!("Size of a closure c: {}", size_of(&c));
        c();
        c();
    }
    assert_eq!(s, "Hello!!");

    let mut s = String::from("Hello");
    {
        let mut c = boxed_closure! {
            ref mut [s: &mut String = &mut s,] () {
                s.push('!');
            }
        };
        println!("Type of a closure c: {}", type_of(&c));
        println!("Size of a closure c: {}", size_of(&c));
        c();
        c();
    }
    assert_eq!(s, "Hello!!");
}
```

输出

```text
Type of a closure c: [closure@src/main.rs:15:21: 15:35 s:&mut std::string::String]
Size of a closure c: 8
Type of a closure c: closure::RefMutClosure<(&mut std::string::String,), (), ()>
Size of a closure c: 16
```

在我的机器上函数指针和引用的大小均为 8，因此整个 `RefMutClosure` struct 的大小为 16。而内置闭包的大小却仅仅为 8，为什么呢？

进一步实验：

```rust
let mut s = String::from("Hello");
let content_of_c: *const ();
{
    let mut c = || s.push('!');
    content_of_c = unsafe { std::mem::transmute_copy(&c) };
    c();
    c();
}
let pointer_to_s: *const () = unsafe { std::mem::transmute_copy(&&s) };
assert_eq!(content_of_c, pointer_to_s);
assert_eq!(s, "Hello!!");
```

可见 Rust 内置闭包实际上**只包含了环境**。原因是 Rust 的闭包是 unboxed 闭包，其函数直接被编译器定义在 `FnOnce`，`FnMut` 和 `Fn` 的实现中，因此，内置闭包对象根本不需要携带函数指针。对内置闭包的函数调用大部分情况下在编译期就绑定了（除非使用 trait object），而不是运行时。这样做的好处是方便 LLVM 做内联优化，同时闭包本身也不需要额外携带一个指针了，可以统一地交给 trait object 做。

### `move` 关键字

`move` 关键字的意义有时令人感到困惑。在远古 Rust 中，`move` 关键字是另作他用的，后来被删除了。应该是在现在版本的闭包出现以后才重新作为一个有用的关键字出现。在内置闭包捕获变量的时候，Rust 总是尽可能以 `&` > `&mut` > `move` 的顺序进行捕获，这将对捕获的变量产生最少的影响。但是，某些情况下，我们需要闭包获得变量的所有权，但是闭包函数体并不需要获得变量的所有权。这时候我们使用 `move` 关键字强制 Rust 将所有捕获的变量移动入闭包的环境中，以延长被移动的对象的生存期。

可以考虑一下为什么有 `move` 闭包却没有 `mut` 闭包呢？因为强制 `mut` 捕获并不会造成任何的好处却会对被捕获的变量产生一个可变借用，这没有任何意义，就与写了 `let r = &mut x;` 却不修改 r 一样，编译器将提示去除 `mut`。

### `Fn`，`FnMut`，`FnOnce` 的推导

正如之前反复强调的，闭包究竟实现 `Fn`，`FnMut`，`FnOnce` 中的哪几个 trait，是由闭包对环境的使用，也就是函数体决定的。

举个例子：

```rust
let s = String::from("hello");
let c = move || println!("{}", s);
c();
c();
```

能正常运行，输出：

```text
s = hello
s = hello
```

```rust
let s = String::from("hello");
let c = || dbg!(s);
println!("{}", s);
c();
c();
```

将编译错误：

```text
error[E0382]: borrow of moved value: `s`
error[E0382]: use of moved value: `c`
```

这是因为 `dbg!(s)` 将获取 `s` 的所有权再返回 `s`，而 `println!("{}", s)` 只会获取 `s` 的引用。同样，`s` 被移动进第一个闭包是因为 `move` 关键字的作用，而 `s` 被移动进第二个闭包是因为第二个闭包的函数体要求 `s` 的所有权。即使两个例子中 `s` 均被移动进闭包，第一个闭包依然根据函数体被实现了 `Fn`，`FnMut`，`FnOnce`，第二个闭包被根据函数体实现了 `FnOnce`。

### 闭包的 `mut`

下面示例代码中的 `c` 变量有时候也令人感到困惑。

```rust
let mut s = String::from("Hello");
{
    let mut c = || s.push('!'); // !
    c();
    c();
}
assert_eq!(s, "Hello!!");
```

为什么编译器要求 c 必须是可变的才能执行 c() 呢？这是因为不能通过不可变引用闭包修改其内容，包括其中的可变引用。另一方面，也可以从类型上看，无法将不可变的内置闭包传递给要求可变 self 引用的 call_mut。

## 脱离闭包

Rust 中，最简单高阶函数一般这样书写：

```rust
fn higher_order_fn<F>(f: F)
where
    F: Fn() -> i32,
```

不理会对 F 的更多约束，考虑在编写高阶函数时，应该选择 `FnOnce`，`FnMut` 还是 `Fn`？

`FnOnce`，`FnMut` 和 `Fn` 并非只为闭包服务。不管是我们实现的朴素闭包也好，还是普通函数也好，都实现了这几个 traits。事实上：

```rust
fn main() {
    println!("{}", std::mem::size_of_val(&main)); // 0
}
```

Rust 中的函数也是“unboxed“实现，同样也实现了 `Fn` 系列 traits。

所以我想最后应该从另一个层面再次考虑 `FnOnce`，`FnMut` 和 `Fn`，以至于在实践中，理解其语义应当就能作出正确的选择：

* `Fn`，函数不保有自己的状态
* `FnMut`，函数可以改变自己的状态
* `FnOnce`，函数消费自己的状态

也就是说：

* 需要纯函数的时候，书写 `Fn`
* 需要函数保存内部状态的时候，如伪随机数生成函数，书写 `FnMut`
* 类似于创建线程这样的调用，选择 `FnOnce`
  ```rust
  pub fn spawn<F, T>(f: F) -> JoinHandle<T> where
      F: FnOnce() -> T,
      F: Send + 'static,
      T: Send + 'static,
  ```
