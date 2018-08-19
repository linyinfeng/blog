+++
title = "Futures-rs 博文 Toykio 翻译"
description = ""
date = 2018-08-18T18:24:51+08:00
author = "Lin Yinfeng"
draft = false
[taxonomies]
categories = ["翻译"]
tags = ["Rust", "Future"]
[extra]
+++

本文为 Rust futures-rs 博客 2018 年 8 月 17 日 的 博文 [Toykio][toykio] 的中文翻译。

原文作者 Alexander Polakov（[@polachok][polachok]）。

<!-- more -->

在这个博文中我将展示 toykio，一个用于学习带有事件循环的 executor 如何工作的简单 futures executor。Toykio 仅仅提供很少的特性：一个事件循环以及 TCP 流和监听器。但是事实证明，由于 futures 是可组合的，这已经足够用来构建复杂的客户端和服务器程序。

在下文中，我将向你提供 toykio 组件的快速概述。

# `AsyncTcpStream`

Toykio 定义了 `AsyncTcpStream` 类型，这是一个标准库中的 `TcpStream` 的包装。就像标准库中的 `TcpStream` 一样，`connect` 函数打开一个连接并将 socket 设为非阻塞模式。这意味着 `read()` 和 `write()` 方法将会立刻返回数据或者错误。如果没有足够的数据（对于读操作）或者缓冲区空间（对于写操作），一个特殊的错误 `WouldBlock` 将被返回。我们将在下一节中讨论如何处理它。

# `AsyncRead` 和 `AsyncWrite`

`AsyncRead` 和 `AsyncWrite` traits 是所有 I/O 特性的基础。`AsyncReadExt` 和 `AsyncWriteExt` 的扩展方法（如 `read` 和 `write_all`）均在其上构建。这些 traits 提供了一种 futures 与事件循环连接的方法，同时保证它们独立于任何特定的事件循环实现。

让我们看看为 `AsyncTcpStream` 实现 `AsyncRead` 的方法：

```rust
impl AsyncRead for AsyncTcpStream {
    fn poll_read(&mut self, cx: &mut Context, buf: &mut [u8]) -> Poll<Result<usize, Error>> {
        match self.0.read(buf) {
            Ok(len) => Poll::Ready(Ok(len)),
            Err(ref err) if err.kind() == std::io::ErrorKind::WouldBlock => {
                // 获取 TcpStream 文件描述符
                let fd = self.0.as_raw_fd();
                let waker = cx.waker();

                REACTOR.with(|reactor| reactor.add_read_interest(fd, waker.clone()));

                Poll::Pending
            }
            Err(err) => panic!("error {:?}", err),
        }
    }
}
```

它尝试从底层的 `TcpStream` 读取。如果读取成功了，切片将被填上数据。如果失败并且返回了 `WouldBlock` 错误，就将当前任务的唤醒器注册，这样它将在数据可用的时候被唤醒。下一节中将提到更多有关的细节。

`AsyncWrite` 的实现对 `write` 做了类似的事。

# 事件循环

`Eventloop`（通常也被叫做 reactor）是这个 executor 的核心。它像这样被定义：

```rust
struct InnerEventLoop {
    read: RefCell<BTreeMap<RawFd, Waker>>,
    write: RefCell<BTreeMap<RawFd, Waker>>,
    counter: Cell<usize>,
    wait_queue: RefCell<BTreeMap<TaskId, Task>>,
    run_queue: RefCell<VecDeque<Wakeup>>,
}
```

- `read` 和 `write` 是 `BTreeMaps`，将文件描述符映射到唤醒器。
- `wait_queue` 保存了阻塞的等待事件的任务。
- `run_queue` 保存了唤醒消息。

事件循环提供了在 `read` 和 `write` 事件中注册（和移除）兴趣的方法。让我们看看 `add_read_interest` 做了什么：

```rust
fn add_read_interest(&self, fd: RawFd, waker: Waker) {
    if !self.read.borrow().contains_key(&fd) {
        self.read.borrow_mut().insert(fd, waker);
    }
}
```

但它仅仅是把 `fd` 和 `waker` 插入到 `read` 树中！所有的魔法到底发生在哪里？在主循环中。事件循环被叫做循环是有原因的。让我们看看：

```rust
loop {
    // 事件循环迭代超时。如果没有描述符就绪我们也继续迭代。
    let mut tv: timeval = timeval {
        tv_sec: 1,
        tv_usec: 0,
    };

    // 初始化 fd_sets（文件描述符集）
    let mut read_fds: fd_set = unsafe { std::mem::zeroed() };
    let mut write_fds: fd_set = unsafe { std::mem::zeroed() };

    unsafe { FD_ZERO(&mut read_fds) };
    unsafe { FD_ZERO(&mut write_fds) };
```

唔哦，这里有非常多的 `unsafe`！但是别担心，这就是 C FFI 的工作方式。我们需要初始化一些 C 结构体，一个超时和 `fd_set`s。它们后面将被传递给 select(2) 函数。

```rust
    // 将所有读兴趣加入到读 fd_sets
    for fd in self.read.borrow().keys() {
        unsafe { FD_SET(*fd, &mut read_fds as *mut fd_set) };
        nfds = std::cmp::max(nfds, fd + 1);
    }

    // 将所有写兴趣加入到写 fd_sets
    for fd in self.write.borrow().keys() {
        unsafe { FD_SET(*fd, &mut write_fds as *mut fd_set) };
        nfds = std::cmp::max(nfds, fd + 1);
    }
```

这里我们将之前 `read` 和 `write` maps 中的文件描述符置入到 `fd_set`s 中。

```rust
    // `select` 将阻塞到文件描述符上有一些事件发生或者超时
    let rv = unsafe {
        select(
            nfds,
            &mut read_fds,
            &mut write_fds,
            std::ptr::null_mut(),
            &mut tv,
        )
    };

    // 不在乎错误
    if rv == -1 {
        panic!("select()");
    } else if rv == 0 {
        debug!("timeout");
    } else {
        debug!("data available on {} fds", rv);
    }
```

终于我们使用准备的参数调用了 `select`。`select()` 接受 3 个 `fd_set`s（我们在这个例子中忽略了第三个）和一个超时并且返回一些非 0 值如果一个（或多个）集合中的文件标识符就绪了。我们应该随后找到是哪些文件标识符！

```rust
    // 检查是哪些文件标识符并将合适的 future 置入 run 队列
    for (fd, waker) in self.read.borrow().iter() {
        let is_set = unsafe { FD_ISSET(*fd, &mut read_fds as *mut fd_set) };
        if is_set {
            waker.wake();
        }
    }

    // 对 write 做一样的事
    for (fd, waker) in self.write.borrow().iter() {
        let is_set = unsafe { FD_ISSET(*fd, &mut write_fds as *mut fd_set) };
        if is_set {
            waker.wake();
        }
    }
```

我们再次遍历了我们的 map 并检查它们是否在 `fd_set`s 中被设为就绪。当它们被设为就绪，我们就调用它们关联的唤醒器的 wake 方法，这将会把 Wakeup 事件置于准备执行队列上。

```rust
    let mut tasks_done = Vec::new();

    // 现在从 run 队列中 pop 任务并 poll 它们
    while let Some(wakeup) = self.run_queue.borrow_mut().pop_front() {
        let mut handle = self.handle();

        if let Some(ref mut task) = self.wait_queue.borrow_mut().get_mut(&wakeup.index) {
            // 如果一个任务返回了 `Poll::Ready`, 我们就完成了它
            if task.poll(wakeup.waker, &mut handle).is_ready() {
                tasks_done.push(wakeup.index);
            }
        }
    }

    // 删除已经完成的任务
    for idx in tasks_done {
        self.wait_queue.borrow_mut().remove(&idx);
    }

    // 如果 `wait_queue` 中没有更多的任务，停止循环
    if self.wait_queue.borrow().is_empty() {
        return;
    }
```

我们消耗了 `run_queue`，获取 `wait_queue` 中的任务索引并询问这些任务。Ready(done) 任务将从 `wait_queue` 中被移除。

# 一个 future 的一生

在这节中，我将概括一个 future（让我们以 read 为例子）是如何在 eventloop 中被执行的：

- 首先它由 `AsyncTcpStream` 的 `read()` 方法创建，这个方法被所有实现了 `AsyncRead` trait 的类型实现。
- 然后使用 `run()` 或 `spawn()` 方法在 executor 中 spawn 它。
- Executor 调用这个 future 的 poll 方法。Read 中 `poll` 的实现调用 `AsyncTcpStream` 的 `poll_read()` 方法，这个方法将它的兴趣注册到 `readable` 事件中。
- 当一个事件发生，future 将被再次 poll。这个循环将被重复直到 future 返回了 ready。

# 感谢

感谢 futures 团队的所有人。特别感谢 [@aturon][aturon] 的鼓励和 [@MajorBreakfast][MajorBreakfast] 的编辑。

这就是今天的所有内容！你可以在 [github][toykio-github] 和 [crates.io][toykio-crates-io] 上找到 toykio。Hacking 快乐！

[toykio]: https://rust-lang-nursery.github.io/futures-rs/blog/2018/08/17/toykio.html
[toykio-github]: https://github.com/polachok/toykio/tree/futures-0.3
[toykio-crates-io]: https://crates.io/crates/toykio
[polachok]: https://github.com/polachok
[aturon]: https://github.com/aturon
[MajorBreakfast]: https://github.com/MajorBreakfast
