+++
title = "斯科特定理"
description = ""
date = 2021-04-28 16:03:07+08:00
updated = 2021-04-28 16:03:07+08:00
author = "Lin Yinfeng"
draft = true
[taxonomies]
categories = ["笔记"]
tags = ["计算理论", "Lambda 演算"]
[extra]
license_image = "![Creative Commons License](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png)"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
[extra.katex]
render_options = '''
{
    macros: {
        "\\set": "\\left\\{ #1 \\right\\}",
        "\\lam": "\\lambda #1 . \\;",
        "\\betaEq": "\\mathrel{=_\\beta}",
        "\\pP": "\\mathcal{P}",
        "\\godel": "\\ulcorner #1 \\urcorner",
        "\\church": "\\overline{#1}"
    },
    delimiters: [
        {left: "$$",  right: "$$",  display: true },
        {left: "$",   right: "$",   display: false}
    ]
}
'''
+++

上一篇笔记中，我介绍了[莱斯定理](@/posts/rices-theorem/index.md)，它是图灵机上的不可判定性结果。Lambda 演算作为一个图灵完备的计算模型，其上也有一个非常类似的重要的不可判定性结果，它就是斯科特定理（Scott's theorem），或称斯科特-柯里定理（Scott–Curry theorem）。

<!-- more -->

## 陈述

斯科特定理是说：

> Lambda 项的任意两个不相交的非平凡的行为性的性质是不可区分的。

因为里面出现了非常多古怪的名词，我必须将这个定理更精确地陈述出来。

令 $\Lambda$ 表示全体 lambda 项的集合。Lambda 项的 BNF 为 $t \Coloneqq x \mid \lam{x} t \mid t\ t$，$\Lambda$ 是满足这个 BNF 定义的最小的集合。

一个 lambda 项的性质就是一个 lambda 项的集合 $\pP \subseteq \Lambda$，$\pP(t)$ 意为 $t$ 满足该性质，$t \in \pP$。两个性质 $\pP_1$ 和 $\pP_2$ 是不相交的，指不存在 $t$，$\pP_1(t) \land \pP_2(t)$。

一个 lambda 项的性质 $\pP$ 是非平凡的，指既存在 $t$ 满足 $\pP$，也存在 $t$ 不满足 $\pP$。即 $\pP \neq \emptyset \land \pP \neq \Lambda$。

一个 lambda 项的性质是行为性的（behavioral），指它对 $\beta$-相等（$\beta$-equivalence）封闭。记 $t_1$ 与 $t_2$ $\beta$-相等为 $t_1 \betaEq t_2$。则，一个性质 $\pP$ 是行为性的，如果 $t_1 \betaEq t_2$，$\pP(t_1)$ 当且仅当 $\pP(t_2)$。性质是行为性的，意为着它与具体的项的语法无关，而仅与项的行为，或者说计算语义有关。

两个不相交的性质 $\pP_1$ 与 $\pP_2$ 是不可区分的，指不存在一个**可判定**的性质 $\pP_3$，对于所有的 $t$，$\pP_1(t) \implies \pP_3(t)$，并且 $\pP_2(t) \implies \neg\pP_3(t)$。

那么问题来了，什么叫可判定的呢？在图灵机的语境下，我们说一个**语言**是可判定的，意为这个语言是递归语言。不过此处，我们不需要牵涉其他的计算模型，纯粹在 lambda 演算的语境下定义可判定性。当然，我们可以证明接下来我所说的可判定性在一定意义上和语言的可判定性是等价，但这与本文无关。

为了用 lambda 演算来建模可判定的 lambda 项的性质，我们做两件事清。

1. 用某种编码方式，在 lambda 演算中编码 lambda 项。例如，之后将介绍到，一个 lambda 项 $t$ 可以被编码为 $\church{\godel{t}}$，它的歌德尔编号（Gödel number）的邱奇数（Church numerals）。
2. 对于一个性质 $\pP$，如果存在一个 lambda 项 $u$，对于所有需要被判定的 lambda 项 $t$，要么有 $u\ \church{\godel{t}} \betaEq \church{0}$，要么有 $u\ \church{\godel{t}} \betaEq \church{1}$，我们就说这个性质是可判定的。当然，这里的 $\church{0}$ 和 $\church{1}$ 可以换成一组别的不 $\beta$-相等的 $\beta$-范式（normal form），用 $\church{0}$ 和 $\church{1}$ 只是为了方便，少引入一些 lambda 项。

## 编码

### 哥德尔编号

### 邱奇编码

## 证明

## 平凡编码

## 应用
