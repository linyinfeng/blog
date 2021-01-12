+++
title = "分布式系统一致性模型简介"
description = ""
date = 2021-01-12 14:06:51+08:00
updated = 2021-01-12 14:06:51+08:00
author = "Lin Yinfeng"
draft = true
[taxonomies]
categories = ["笔记"]
tags = ["分布式系统", "一致性"]
[extra]
license_image = "![Creative Commons License](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png)"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
[extra.katex]
render_options = '''
{
    macros: {
        "\\set": "\\left\\{ #1 \\right\\}",
        "\\read": "\\mathtt{rd}",
        "\\inc": "\\mathtt{inc}",
        "\\ok": "\\mathtt{ok}",
        "\\write": "\\mathtt{wr}",
        "\\returnsBefore": "\\mathtt{rb}"
    },
    delimiters: [
        {left: "$$",  right: "$$",  display: true },
        {left: "$",   right: "$",   display: false}
    ]
}
'''
+++

这学期末，在老师的推荐下，我阅读了 [Sebastian Burckhardt] 的教程论文《[Principles of Eventual Consistency]》，并感到获益匪浅。这篇教程形式化地定义了多种分布式系统的一致性模型（等其他非常多的东西），最终形成了一个用于证明一个分布式协议是否满足某个一致性模型的证明框架。其中，我最大的收获就是终于弄明白了许多之前我理解模糊的问题。例如，分布式系统一致性有什么好处，它的目的是什么？分布式系统一致性背后的基本思路方式，它的思考方式到底是怎么样的？什么是讨论分布式系统一致性模型中所要考虑的，什么不是？等等这样的问题。

虽然我主业不是搞分布式系统的😅（发现我到现在都没写过有关程序设计语言的博客），但是这个考试周里复习的空闲时间，我还是想写点博客形式化地谈谈我现在对分布式系统一致性的理解，希望能帮到一些没有看明白一致性的自然语言描述的同学。

这文章中，我会使用很多很多的来自 《[Principles of Eventual Consistency]》 的形式化定义，主要，而不是采用自然语言描述，这是为了更加精确的描述，防止这篇文章就如同其他一致性文章一样，难以讲清楚想表达的东西。

[Sebastian Burckhardt]: https://www.microsoft.com/en-us/research/people/sburckha/
[Principles of Eventual Consistency]: https://www.microsoft.com/en-us/research/publication/principles-of-eventual-consistency/

<!-- more -->

## 引言

我通过**数据结构的实现的正确性**（correctness）这个问题来引出分布式系统一致性问题。引言部分不会将其中的各种内容完全形式化。

我们都知道串行的**可变的**数据结构具有什么行为。比如，如果我们把一个串行数据结构叫做计数器，它的初始值是 $0$，有两个操作，$\read$（读）和 $\inc$（递增）。那么它的工作方式可以看作一个，状态是 $\mathbb{N}$，输入是 $\set{\read, \inc}$ 这两个操作，在转移时会输出 $\mathbb{N} \cup \set{\ok}$ 的状态迁移系统。

* 初始状态为 $0$；
* 在 $n$ 状态进行 $\read$ 操作时，转移到 $n$ 状态，输出 $n$；
* 在 $n$ 状态进行 $\inc$ 操作时，转移到 $n + 1$ 状态，输出 $\ok$。

再举一个例子，如果我们有一个串行数据结构叫做寄存器，它能存储一个自然数，初始值为 $0$，有两个操作 $\read$（读）和 $\write$（写）。那么同样，它的工作方式也立刻可以看作一个，状态是 $\mathbb{N}$，输入是 $\set{\read} \cup \set{\write(n) \mid n \in \mathbb{N}}$ 这可数无穷个操作，在转移时会输出 $\mathbb{N} \cup \set{\ok}$ 的状态迁移系统。

* 初始状态为 $0$；
* 在 $n$ 状态进行 $\read$ 操作时，转移到 $n$ 状态，输出 $n$；
* 在 $n$ 状态进行 $\write(m)$ 操作时，转移到 $m$ 状态，输出 $\ok$。

可变串行数据结构的行为是显而易见的，我们可以通过状态的迁移来定义计数器，寄存器，栈，队列，火车票售票系统等等一切我们需要的串行数据结构，不过，这一切的背后是有假设的。

首先，操作的发生是需要时间的，考虑一个客户程序，它要使用我们的串行数据结构计数器（这也是为什么它叫数据结构）。客户程序调用 $\read$ 操作的过程不是一个点，而是一段时间，它会有操作的开始和返回。在所有发生的操作事件上定义一个关系 $\returnsBefore$（returns before），如果一个操作 $a$ 的返回发生在 $b$ 之前，就有 $(a, b) \in \returnsBefore$。

在一个串行系统，而不是分布式系统中，操作只能一个接一个地发生，无法被打断。因为我们的程序只有一个控制流，只有当前正在进行的操作返回后才能进行下一个操作的开始。因此，所有的操作事件 $a$ 与 $b$ 之间，要么 $(a, b) \in \returnsBefore$，要么 $(b, a) \in \returnsBefore$。$\returnsBefore$ 是一个全序（total order），任意两个操作事件之间的先后顺序都是可比较的。

因此，给定一个通过调用某个串行数据结构的实现产生的串行历史（sequential history，一系列操作事件，和它们的 $\returnsBefore$ 关系），我们立刻就可以定义然后检验，这个串行数据结构的实现是否是**正确**的。（1）将这一系列操作事件按照 $\returnsBefore$ 关系进行排序，因为 $\returnsBefore$ 是一个全序，我们有唯一的合法排序；（2）按排序后的顺序，从串行数据结构的初始状态开始，一个一个将事件的操作应用到状态迁移系统上，获得一个期望输出；（3）将期望输出与实际输出进行比较；（4）一个串行数据结构在这个串行历史下是正确的，当且仅当，所有的期望输出与实际输出都相等。

然后我们可以说，一个串行数据结构 $\mathcal{S}$ 的实现是正确的，当且仅当它能产生的所有串行历史，对于 $\mathcal{S}$ 都是正确的。

串行系统下，我们很容易不那么形式化地将数据结构的实现的正确性描述清楚，那么分布式系统中的数据结构呢？有许多麻烦等着我们。

1. 第一个麻烦，在串行系统中，$\returnsBefore$ 是一个全序，而在分布式系统中，$\returnsBefore$ 只是一个偏序关系。在分布式系统中，两个节点，两个进程同时执行操作是再正常不过的事。我们有了并发的操作，它们无法排出先后关系。

2. 在分布式系统中，除非是实时系统，或者大家都有足够精度的物理时钟，或者使用中心化的服务器等一些鲁棒性较差的协议，大部分情况下，去利用 $\returnsBefore$ 关系是不现实的，后面会介绍到，要求解决更新冲突的顺序与 $\returnsBefore$ 一致的一致性模型，叫做可线性化（linearizability），它更多使用在**并发**编程中。

3. 还有，如果我们像串行数据结构那样，要求给所有的操作排出某个顺序（不是 $\returnsBefore$ 关系），我们会得到一个类似顺序一致的模型（sequential consistency），它依然太强了，许多分布式协议并不能做到顺序一致，但这些分布式协议依然是**实用**的，我们也应该要有一个办法来定义它们的正确性。

那么，说了这么久，到底如何合理地来为分布式的数据结构的实现定义正确性呢？**一般情况下**，我们实现的分布式数据结构往往采用了*复制*（replication）的方式
