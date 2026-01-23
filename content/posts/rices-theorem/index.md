+++
title = "莱斯定理"
# description = ""
date = 2020-12-13 23:01:20+08:00
updated = 2021-04-28 16:04:37+08:00
author = "Yinfeng"
draft = false
[taxonomies]
categories = ["笔记"]
tags = ["莱斯定理", "计算理论", "形式语言与自动机"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

学习形式语言自动机这课时花了很久才理解莱斯定理（Rice's Theorem）。懂了以后发现，其实就是之前对着书瞎想的时候，没先把全局要做的事情理清楚，这个定理其实并不复杂。这篇带了一些偷懒（省略）的文章是我对莱斯定理的笔记。

<!-- more -->

## 陈述

莱斯定理的陈述听起来非常厉害，似乎难以证明。

> 递归可枚举语言的所有非平凡性质都是不可判定的。

复习和解释一下里面名词的概念。

- 语言（language）：字符串的集合。
- 递归可枚举语言（recursive enumerable language）：还可以叫图灵可接收语言（Turing-acceptable language）图灵可识别语言（Turing-recognizable language）等。一个语言是递归可枚举语言，当且仅当存在一个图灵机，该图灵机仅接收该语言中的字符串（也就是说，对于不在该语言中的字符串，该图灵机可以拒绝（reject）或者永远不停机）。
- 不可判定（undecidable）：一个语言是可判定的，当且仅当存在一个图灵机，该图灵机接收该语言中的字符串，拒绝不在该语言中的字符串。这样的语言又叫递归语言。

所以这句话说，“递归可枚举语言的所有非平凡性质”，都是不可判定的。潜台词是说，“性质”是一种语言。一般来说，递归可枚举语言的性质就是一个谓词，对某些递归可枚举语言成立，对某些递归可枚举语言不成立。换一种方式来表示，这里我们讨论的性质就直接是一个集合，如果某个元素在这个集合内，那么这个元素就具有这个性质，否则就不具有。

但这里还有一个问题，语言是字符串的集合，递归可枚举语言是个集合而不是字符串。因此，这里说的是递归可枚举语言的字符串表示，而不是语言本身。

因此，这里的“递归可枚举语言的性质”就是递归可枚举语言的字符串表示的一个子集，因为这是语言的性质而不是字符串的性质，这个子集要满足一定条件。如果我们令 $L(w)$ 表示字符串 $w$ 表示的语言。对于性质 $\mathcal{P}$ 任意两个字符串 $w_1$ 和 $w_2$，如果 $L(w_1) = L(w_2)$，就有 $L(w_1) \in \mathcal{P} \land L(w_1) \in \mathcal{P}$ 或者 $L(w_1) \notin \mathcal{P} \land L(w_1) \notin \mathcal{P}$。

特别的，这里讨论的字符串其实指的是**图灵机的字符串表示**。

最后。

- 非平凡（nontrivial）：性质不是对所有元素都成立，也不是对所有元素都不成立的。

所以这里的性质一定会包含部分的而不是全部的递归可枚举语言。

所以最后，莱斯定理真正想表达的东西就是。

$$
\forall \mathcal{P}, \mathcal{P} \subsetneq \mathit{RE} \land \mathcal{P} \neq \emptyset \implies \set{ \langle M \rangle \mid L(M) \in \mathcal{P} } \notin \mathit{RL}
$$

我用 $\mathit{RE}$ 表示所有递归可枚举语言的集合，用 $\mathit{RL}$ 表示所有递归语言（可判定语言）的集合。字母 $\mathcal{P}$ 表示性质。用 $M$ 表示一个图灵机，$L(M)$ 表示该图灵机接收的语言。$\langle \cdot \rangle$ 表示一个东西的字符串表示，例如 $\langle M \rangle$ 表示一个图灵机 $M$ 的字符串表示，$\langle M, w \rangle$ 表示一个图灵机和一个字符串构成的有序对的字符串表示。

## 准备

在证明莱斯定理前，我们先证明通用图灵机（Universal Turing Machine）接收的语言是不可判定的。什么是通用图灵机？通用图灵机就是输入一个图灵机的字符串表示和一个字符串，模拟输入的图灵机在输入的字符串上运行的图灵机。为什么这种图灵机是存在的呢？这里我偷个懒，不做证明。后续涉及到用图灵机构造的方式来做证明的部分，我都仅简要说明。通用图灵机能接收的语言就是。

$$
L_u = \set{ \langle M, w \rangle \mid w \in L(M) }
$$

因为我们已经通过偷懒说明它是图灵机接收的语言，$L_u \in \mathit{RE}$。接着，我们可以证明 $L_u \notin \mathit{RL}$。

假设 $L_u \in \mathit{RL}$，我们有 $\overline{L_u} \in \mathit{RL}$（递归语言对补集操作封闭），且存在通用图灵机 $U$，$U$ 判定 $L_u$。那么，我们可以构造一个新的图灵机 $U'$，它接收 $\langle M \rangle$，构造 $\langle M, \langle M \rangle \rangle$，并模拟 $U$ 的执行，如果 $U$ 接收 $\langle M, \langle M \rangle \rangle$，$U'$ 就拒绝，如果 $U$ 拒绝，$U'$ 就接收。这个新图灵机的构造方式我就再次偷懒略过。新的图灵机 $U'$ 接收的语言是。

$$
L_u' = L(U') = \set{ \langle M \rangle \mid \langle M \rangle \notin L(M) }
$$

根据上述偷懒论述可见，如果我们假设 $L_u$ 可判定，那么 $L_u'$ 就可判定。那么现在，我们考虑 $\langle U' \rangle \in L_u'$ 是否成立。

- 若 $\langle U' \rangle \in L_u'$，则 $\langle U' \rangle \notin L(U')$，即 $\langle U' \rangle \notin L_u'$；
- 若 $\langle U' \rangle \notin L_u'$，则 $\neg \langle U' \rangle \notin L(U')$，即 $\langle U' \rangle \in L_u'$。

$\langle U' \rangle$ 不能既在 $L_u'$ 里又不在 $L_u'$ 里，我们导出了一个矛盾，表明我们的假设，$L_u$ 可判定，是错误的。因此，通用图灵机 $U$ 识别的语言 $L_u$ 不可判定，$L_u \notin \mathit{RL}$。

## 证明

为什么我们花了很多篇幅说明了 $L_u$ 不可判定？因为假设莱斯定理不成立，即存在一个递归可枚举语言的非平凡性质是可判定的，那么 $L_u$ 就可判定。也就是说，我们能把 $L_u$ 规约到任意一个递归可枚举语言的非平凡性质的判定问题上。记 $L_{\mathcal{P}}$ 为性质 $\mathcal{P}$ 表示的语言。

$$
\set{ \langle M \rangle \mid L(M) \in \mathcal{P} }
$$

怎么做呢，对于不同的非平凡性质，分为两种情况。

### 性质不包含空语言

我们首先讨论性质不包含空语言的情况，即 $\emptyset \notin \mathcal{P}$。为什么要区分性质是否包含空语言呢，这主要是由证明方法决定的。

那么首先，我们要说明我们能把 $L_u$ 的判定问题规约到任意一个，不包含空语言的递归可枚举语言的非平凡性质，的判定问题上。

对于任意 $L_u$ 的输入 $\langle M, w \rangle$，我们都可以构造一个新的图灵机 $M'$。
在构造之前，我们还需要一个额外的图灵机。
因为 $\mathcal{P}$ 非平凡，因此一定存在一个语言 $L \in \mathcal{P}$；又因为 $\mathcal{P} \subsetneq \mathit{RE}$，一定存在一个图灵机 $M_L$，$L(M_L) = L$。

然后，我们按如下方式构造新的图灵机 $M'$。首先，这个图灵机用额外的磁带（多带图灵机在可判定性和识别语言的能力上与图灵机等价）存储 $\langle M \rangle$ 和 $w$，并在 $w$ 上模拟 $M$，如果 $M$ 没有接收（停机但不接收或者永不停机），就不继续做任何事，不接收，拒绝任何输入，此时 $L(M') = \emptyset$ 空语言；如果模拟的 $M$ 接收了，$M'$ 接下来在自己的输入 $x$ 上模拟 $M_L$，此时，$L(M') = L$。

这个构造显然可行。具体细节我继续偷懒不加进一步说明。特别要注意到的是，由于对 $M$ 的模拟可能不停机，此时一定有 $L(M') = \emptyset$，所以我们才要求性质不包含空语言。

现在，我们如果能判定新的图灵机 $M'$ 的语言 $L(M') \in \mathcal{P}$，显然我们就能判定这个图灵机内部模拟的第一个图灵机 $M$ 是否接收 $w$。即 $L_{\mathcal{P}} \in \mathit{RL} \implies L_u \in \mathit{RL}$。由于上节中我们已经证明 $L_u \notin \mathit{RL}$，因此 $L_{\mathcal{P}} \notin \mathit{RL}$。

### 性质包含空语言

包含空语言的性质又该如何处理呢。

考虑包含空语言的性质 $\mathcal{P}$，$\overline{\mathcal{P}} = \mathit{RE} - \mathcal{P}$ 一定不包含空语言（特别注意这里考虑递归可枚举语言性质的补集时全集是递归可枚举语言的集合而不是所有语言的集合）。根据已证明的结论，$L_{\overline{\mathcal{P}}} \notin \mathit{RL}$。可以注意到，因为对于所有图灵机 $M$，$L(M) \in \mathit{RE}$，所以有。

$$
L_{\overline{\mathcal{P}}} = \set{ \langle M \rangle \mid L(M) \in \overline{\mathcal{P}} } = \set{ \langle M \rangle \mid L(M) \in \mathit{RE} - \mathcal{P} } = \overline{L_{\mathcal{P}}}
$$

因为 $\mathit{RL}$ 对补集操作封闭，所以 $L_{\mathcal{P}} \in \mathit{RL} \implies L_{\overline{\mathcal{P}}} \in \mathit{RL}$。由于我们已经证明 $L_{\overline{\mathcal{P}}} \notin \mathit{RL}$，所以 $L_{\mathcal{P}} \notin \mathit{RL}$。

综合两种情况，我们带有一些偷懒地证明了莱斯定理。

$$
\forall \mathcal{P}, \mathcal{P} \subsetneq \mathit{RE} \land \mathcal{P} \neq \emptyset \implies \set{ \langle M \rangle \mid L(M) \in \mathcal{P} } \notin \mathit{RL}
$$

## 应用

莱斯定理告诉我们啥。举一些例子。

- $\mathcal{P} = \set{\emptyset}$，判定一个图灵机接收的语言是否是空语言是不可判定问题；
- $\mathcal{P} = \set{L}$，判定一个图灵机接收的语言是某个特定语言，如判定一个图灵机接收回文，判定一个图灵机只接收空串等，都是不可判定问题；
- $\mathcal{P} \set{L \mid L \in \mathit{RE}, w \in L}$，判定一个图灵机能接收某个串是不可判定问题，即 $L_u$ 不可判定。

等等。
