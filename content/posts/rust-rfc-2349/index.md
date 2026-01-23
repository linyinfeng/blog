+++
title = "Rust RFC 2349 - Pin 翻译"
# description = ""
date = 2018-08-19 07:36:17+08:00
updated = 2018-08-21 08:52:15+08:00
author = "Yinfeng"
draft = false
[taxonomies]
categories = ["翻译"]
tags = ["Rust", "类型系统"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

本文为 [Rust RFC 2349 - Pin](https://github.com/rust-lang/rfcs/blob/master/text/2349-pin.md) 的中文翻译。

Rust RFCs 并非一成不变，本文翻译于 2018 年 08 月 19 日。

Rust RFCs 仓库目前（2018-08-21）为可选的 MIT 和 Apache 授权，本文使用了其 MIT 授权。[MIT 许可证副本](https://github.com/linyinfeng/blog/tree/master/content/posts/rust-rfc-2349/LICENSE-MIT)。

文中有众多 Rust 中的其他 RFC 甚至 crates 中的概念，水平有限，如有翻译错误或建议，可以向我的 [GitHub](https://github.com/linyinfeng/blog) 仓库提 Issue 或者直接发起 PR 指正，本文文件：[content/posts/rust-rfc-2349/index.md](https://github.com/linyinfeng/blog/tree/master/content/posts/rust-rfc-2349/index.md)。

<!-- more -->

- 特性名：pin
- 开始日期：2018-02-19
- RFC PR：[rust-lang/rfcs#2349](https://github.com/rust-lang/rfcs/pull/2349)
- Rust Issue: [rust-lang/rust#49150](https://github.com/rust-lang/rust/issues/49150)

## 摘要

提出一套新的 API 加入 libcore/libstd 中作为不可以被安全地移动的数据的安全抽象。

## 动机

不应该被移动的类型是长期困扰 Rust 的一个问题。实现它的一个通常的动机是当一个结构包含指向它自己内存的指针——移动这个结构将会使指针无效。这个用例最近已经在生成器的工作中变得非常重要。因为生成器本质上将栈帧实现为一个可以被操作的对象，看起来如果它被允许，这种生成器的惯用法将导致这种自引用类型。

这个提案向 std 中加入了 API，允许你保证一个特定的值永远不会被再次移动，使依赖于自引用的安全 API 存在。

## 指南层次的解释

这个 RFC 的核心目标是提供一个引用类型，保证被引用的对象在销毁前不被移动。我们希望对类型系统做最少的开洞来实现它，而且事实上，这个 RFC 展示了我们能在不对类型系统做任何修改的情况下达成这个目标。

我们把目标拆分，一块一块来看，从 futures（即 async/await）用例看：

- **引用类型**。我们需要一个引用类型的原因是，当我们处理类似 futures 的东西的时候 我们通常希望将小的 futures 组合成大的，并仅仅在顶层把整个结果 futures 放入一个不可移动的位置。因此，我们需要为类似 poll 的方法提供一个引用类型，这样我们可以将大的 future 分解成小的 future，同时确保不可移动性。

- **在销毁前永不移动**。再次考查 futures 这个例子，一旦我们正在 `poll` 一个 future，我们希望它能够保存指向自己的引用，这仅仅在整个 future 无法被移动的时候是可能的。我们不尝试从类型层面追踪*是否*这样的引用是存在的，因为这会导致笨重的类型状态机（typestate）；相反地，我们简单地令从你第一次 `poll` 开始，承诺永远不再次移动一个不可移动的 future。

同时，我们希望支持*可以*移动的 futures（以及迭代器，等等）。可能通过提供两种 `Future`（或 `Iterator`，等等）traits 来实现这一点，但这样的设计会导致不可接受的人体工学开销。

这个 RFC 最关键的选择是我们创建了一个新的库类型，`Pin<'a, T>`，*同时*包含可移动和不可移动的被引用对象。这个类型对应一个新的自动 trait，`Unpin`，它决定了 `Pin<'a, T>` 的意义。

- 如果 `T: Unpin`（默认），那么 `Pin<'a, T>` 完全等价于 `&'a mut T`。
- 如果 `T: !Unpin`，那么 `Pin<'a, T>` 提供一个对具有生命周期 `'a` 的 `T` 的唯一引用，但仅仅提供安全的 `&'a T` 访问。它同时保证了被引用对象*永远不*被移动。然而，访问 `&'a mut T` 是不安全的，因为类似 `men::replace` 的操作意味着 `&mut` 足够将数据移动出被引用对象；你必须承诺不这么做。

要清楚：`Unpin` 的唯一功能是控制 `Pin` 的意义。将 `Unpin` 作为一个自动 traits 意味着绝大多数类型自动地成为可移动的，因此 `Pin` 退化为 `&mut`。如果你需要不可移动性，你可以*去除* `Unpin`，然后 `Pin` 对于你的类型就会变得有意义。

结合所有这些，我们获得了以下 `Future` 的定义：

```rust
trait Future {
    type Item;
    type Error;

    fn poll(self: Pin<Self>, cx: &mut task::Context) -> Poll<Self::Item, Self::Error>;
}
```

默认情况下当我们为一个结构体实现 `Future`，这个定义将与目前的相同，`poll` 将获取 `&mut self`。但当你想要允许你的 future 自引用，你只需要去除 `Unpin` 并注意剩下的部分。

这个 RFC 也给 `Box` 提供了一个 pinned 类似，叫做 `PinBox<T>`。它就像这里讨论的 `Pin` 一样工作——如果类型实现了 `Unpin`，它的功能就和 `Box` 一样；如果类型去除了 `Unpin`，它确保引用之后的类型不会被再次移动。

## 参考层次的解释

### `Unpin` 自动 trait

这个新的自动 trait 被加入到 `core::marker` 和 `std::marker` 模块：

```rust
pub unsafe auto trait Unpin { }
```

一个实现了 `Unpin` 的类型能够被移动出下文将提到的某一个 pinned 引用类型。否则，它们不会暴露允许你将值移出的安全 API。因为 `Unpin` 是一个自动 trait，Rust 中的大部分类型实现了它。没有实现它的类型主要是自引用类型，如某些生成器。

这个 trait 是一个 lang 项目，但仅仅是为了为某些生成器生成负实现。不同于之前的 `?Move` 提案，也不同于如 `Sized` 和 `Copy` 的一些 traits，这个 trait 不对实现或不实现它的类型施加任何基于编译器的语义。相反地，它的语义是完全由使用 `Unpin` 作为标记的库 APIs 强制的。

### `Pin`

`Pin` 结构体被加入到 `core::mem` 和 `std::mem`。这是一种新的，相比 `&mut T` 有更多要求的引用。

```rust
##[fundamental]
pub struct Pin<'a, T: ?Sized + 'a> {
    data: &'a mut T,
}
```

#### 安全 APIs

`Pin` 实现了 `Deref`, 但是仅当类型实现 `Unpin` 时实现了 `DerefMut`。这样，当类型没有实现 `Unpin` 时，调用 `mem::swap` 或
`mem::replace` 是不安全的。

```rust
impl<'a, T: ?Sized> Deref for Pin<'a, T> { ... }

impl<'a, T: Unpin + ?Sized> DerefMut for Pin<'a, T> { ... }
```

它只能安全地被实现了 `Unpin` 的类型的引用构造：

```rust
impl<'a, T: Unpin + ?Sized> Pin<'a, T> {
    pub fn new(reference: &'a mut T) -> Pin<'a, T> { ... }
}
```

它还有一个函数 `borrow`，允许它被转换成一个有更短生存期的 pin。

```rust
impl<'a, T: ?Sized> Pin<'a, T> {
    pub fn borrow<'b>(this: &'b mut Pin<'a, T>) -> Pin<'b, T> { ... }
}
```

它也可以实现额外的 APIs 因为它们对于实现类型转换是很实用的，例如 `AsRef`，`From` 等等。`Pin` 实现了 `CoerceUnsized`，这对能够将它们转为 trait objects 是必要的。（`Pin` implements `CoerceUnsized` as necessary to make coercing them into trait objects possible.）

#### 不安全 APIs

`Pin` 能够被不安全地从可能未实现 `Unpin` 的类型的可变引用构造。使用这个构造函数的用户必须知道他们传递引用的类型在 `Pin` 被构造后将永远不再被移动，即使这个引用的生存期结束了。（举个例子，通过一个你未创建的引用构造的 `Pin` 总是不安全的，因为你不知道一旦这个引用的生存期结束会发生什么。）

```rust
impl<'a, T: ?Sized> Pin<'a, T> {
    pub unsafe fn new_unchecked(reference: &'a mut T) -> Pin<'a, T> { ... }
}
```

`Pin` 也有一个将没有实现 `Unpin` 的类型的 `Pin` 转换为可变引用的 API。使用这个 API 的用户必须确保他们不将被引用对象移动出他们获得的可变引用。

```rust
impl<'a, T: ?Sized> Pin<'a, T> {
    pub unsafe fn get_mut<'b>(this: &'b mut Pin<'a, T>) -> &'b mut T { ... }
}
```

最后，为了方便，`Pin` 实现了一个不安全的 `map` 函数，这使得访问一个字段更简单。调用这个函数的用户必须确保返回的值只要被引用对象不被移动就不被移动（例如，这是一个值的私有字段）。作为闭包参数接收的可变引用也必须不被移动。

```rust
impl<'a, T: ?Sized> Pin<'a, T> {
    pub unsafe fn map<'b, U, F>(this: &'b mut Pin<'a, T>, f: F) -> Pin<'b, U>
    where F: FnOnce(&mut T) -> &mut U
    { ... }
}

// 举个例子：
struct Foo {
    bar: Bar,
}

let foo_pin: Pin<Foo>;

let bar_pin: Pin<Bar> = unsafe { Pin::map(&mut foo_pin, |foo| &mut foo.bar) };
// 等价于：
let bar_pin: Pin<Bar> = unsafe {
    let foo: &mut Foo = Pin::get_mut(&mut foo_pin);
    Pin::new_unchecked(&mut foo.bar)
};
```

### `PinBox`

`PinBox` 类型被加入到 `alloc::boxed` 和 `std::boxed`。正如 `Pin` 类似于引用类型，`Box` 类似于 `Box` 类型，它有相似的 API。

```rust
##[fundamental]
pub struct PinBox<T: ?Sized> {
    inner: Box<T>,
}
```

#### 安全 API

不同于 `Pin`，从一个 `T` 和 `Box<T>` 构建 `PinBox` 是安全的，即使类型没有实现 `Unpin`。

```rust
impl<T> PinBox<T> {
    pub fn new(data: T) -> PinBox<T> { ... }
}

impl<T: ?Sized> From<Box<T>> for PinBox<T> {
    fn from(boxed: Box<T>) -> PinBox<T> { ... }
}
```

它也提供了和 `Pin` 同样的 `Deref` 实现：

```rust
impl<T: ?Sized> Deref for PinBox<T> { ... }
impl<T: Unpin + ?Sized> DerefMut for PinBox<T> { ... }
```

如果数据实现了 `Unpin`，将 `PinBox` 转换为 `Box` 是安全的：

```rust
impl<T: Unpin + ?Sized> From<PinBox<T>> for Box<T> { ... }
```

最后，可以安全地从 `PinBox` 的借用获取一个 `Pin`：

```rust
impl<T: ?Sized> PinBox<T> {
    fn as_pin<'a>(&'a mut self) -> Pin<'a, T> { ... }
}
```

这些 APIs 使 `PinBox` 能够作为一个合理的方法处理没有实现 `Unpin` 的数据。一旦你在 `PinBox` 内分配数据到堆上，你知道它的地址不会改变，同时可以分发对这些数据的 `Pin` 引用。

#### 不安全 API

类似 `Pin`，`PinBox` 可以被不安全地转换为 `&mut T` 和 `Box<T>` 即使它引用的类型没有实现 `Unpin`：

```rust
impl<T: ?Sized> PinBox<T> {
    pub unsafe fn get_mut<'a>(this: &'a mut PinBox<T>) -> &'a mut T { ... }
    pub unsafe fn into_inner(this: PinBox<T>) -> Box<T> { ... }
}
```

### 不可移动生成器

如今，不稳定的生成器特性有选项能够生成包含生存期跨越 yield 点的引用的生成器——这些引用，事实上，是生成器的状态机的引用。因为如果类型移动，内部引用将失效，这类生成器（“不可移动生成器”）的创建目前是不安全的。

一旦 arbitrary_self_types 特性成为对象安全，我们将对生成器 API 做三个改动：

1. 我们将改变 `resume` 方法，接收 `self: Pin<Self>` 而非 `&mut self`。
2. 为不可移动生成器实现 `!Unpin`
3. 使不可移动生成器的定义变为安全的

这就是这个 RFC 中的 API 如何允许自引用数据被安全地创建的例子。

## 缺点

这向 std 添加了额外的 APIs，包括一个自动 trait。这样的添加不能被轻易地接受，仅当它们对于它们所表达的抽象完全合理时才能添加。

## 理由和替代方案

### 对比 `?Move`

一个之前的提案是添加一个内置的 `Move` trait，类似于 `Sized`。一个没有实现 `Move` 的类型在被引用以后不能被移动。

这个解决方案有一些问题。首先，`?Move` 限定最终“传染”了很多不同的不相关的 APIs，并且在几个情况下提出了破坏性的改变，这些 API 的改变无法保持向后兼容。

在某些场景下，这个提案是一个范围小得多的 `?Move`。如果使用 `?Move`，*任何*引用就会表现得如这里的“Pin”引用一样。然而，因为这个灵活性，使一个类型无法移动的负面后果就是会有更加广泛的不良影响。

相反地，我们要求 APIs 通过使用 `Pin` 类型选择支持不可变性，避免“传染”基本的引用类型，与不可移动类型产生关系。

### 对比使用 `unsafe` APIs

另一个我们考虑的替代选项是仅仅使要求不可移动性的 API 不安全。这些 APIs 的用户必须考查并确保它们没有移动自引用类型。举个例子，生成器将像这样：

```rust
trait Generator {
    type Yield;
    type Return;

    unsafe fn resume(&mut self) -> CoResult<Self::Yield, Self::Return>;
}
```

这将不要求对标准库添加任何东西，但这也将使每一个想要调用 resume 的用户负担起保证检查（冒着内存不安全的风险）它们的类型没有被移动或者是可移动的的任务。对于添加这种 APIs，这似乎是一个不良的取舍。

### 作为包装类的 Anchor 和 `StableDeref`

再过去的本 RFC 的迭代中，有一个包装类型叫做 `Anchor`，这个类型能够“锚定”任何智能指针，而且有一个关于不同指针类型的被引用对象的稳定性的 traits 层级。这个类型被替换为了 `PinBox`。

这种方法的主要好处是它与 owning-ref 和 rental 这种 crates 部分整合，这些 crates 也使用稳定性层级。然而，因为要求的不同，owning-ref 以及其他此类 crates 使用的 traits 最终形成了与 Anchor 使用的 traits 没有重叠的一个这个 RFC 提出的 traits 子集。将这些整合进同一个层级结构中相对来说只有很少的好处。

并且，之前，仅有的几个实现了放入 Anchor 所有必要的 traits 的类型是 `Box<T>` 和 `Vec<T>`。因为你无法可变访问一个智能指针（除非被引用对象实现了 `Unpin`），在这个 RFC 的上一个迭代中一个 `Anchor<Vec<T>>` 并没有真的与 `Anchor<Box<[T]>>` 有什么不同。由于这个原因，将 `Anchor` 替换为 `PinBox` 并仅支持 `PinBox<T>`，这在减少了 API 复杂度的同时也没有减少表现力。

### 栈 pinning API（潜在的未来扩展）

这个 API 支持 pinning 一个 `!Unpin` 类型到堆上。然而，它们也可以被安全地放置在栈上，允许创建一个安全的引用栈上分配的 `!Unpin` 类型的 `Pin`。

这个 API 很小，并且不会成为任何人的公共 API 的一部分。由于这个原因，在加入到 std 之前，我们将在第三方 crates 中发展它。这是这个 API 用于引用目的的一个版本：

```rust
pub fn pinned(data: T) -> PinTemporary<'a, T> {
    PinTemporary { data, _marker: PhantomData }
}

struct PinTemporary<'a, T: 'a> {
    data: T,
    _marker: PhantomData<&'a &'a mut ()>,
}

impl<'a, T> PinTemporary<'a, T> {
    pub fn into_pin(&'a mut self) -> Pin<'a, T> {
        unsafe { Pin::new_unchecked(&mut self.data) }
    }
}
```

### 将 `Pin` 作为内置类型（潜在的未来扩展）

`Pin` 类型也可以作为一种新的一级引用——`&'a pin T`。这将有一些好处——举个例子，映射字段的操作将变得平凡，以及“栈 pinning”将不要求额外 API，这将是自然的。然而，添加一个新的引用类型有不好的一面，一个非常大的语言变化。

现在，我们对坚持 std 中的 `Pin` 结构体感到高兴，如果这个类型某天加入了，将 `Pin` 类型转换为这个引用类型的别名。

### 同时有 `Pin` 和 `PinMut`

相比与仅有 `Pin`，叫做 `Pin` 的类型也可以叫做 `PinMut`，我们可以有个类型叫做 `Pin` 的，与 `PinMut` 类似的类型，但仅包含一个共享的，不可变的引用。

因为我们已经对 `Pin`/`PinMut` 的不可变解引用的安全性有信心，这个 `Pin` 类型不会提供普通不可变引用不能提供的有意义的保证。如果一个用户需要传递一个 pinned 的数据的引用，一个 `&Pin`（在本 RFC 中定义的 `Pin`）是足够的。由于这个原因，区分 `Pin`/`PinMut` 导致了额外的类型和复杂性，没有提供有影响力的好处。

## 未解决的问题

除了上述讨论的未来的扩展，std 中的三个 pin 类型将随时间发展，由于它们实现了更多普遍的转换 traits 等等。

我们可能进一步要求 `Pin` 维护更严格的保证，要求 `Pin` 中的 `Unpin` 数据不会泄漏，除非这块内存在程序剩余的生存期中依然有效。这将会导致上文中的栈 API 不健全，但是可能也能用来使其他 API 使用这些保证来确保内存失效时析构器总是会执行。
