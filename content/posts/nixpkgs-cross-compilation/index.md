+++
title = "Nixpkgs 交叉编译笔记"
description = ""
date = 2023-09-16 13:20:35+08:00
updated = 2023-09-16 13:20:35+08:00
author = "Lin Yinfeng"
draft = true
[taxonomies]
categories = ["笔记"]
tags = ["Nix", "Nixpkgs", "函数式编程"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

本文结合 [nixpkgs manual](https://nixos.org/manual/nixpkgs/unstable) 和 [nixpkgs 源码](https://github.com/NixOS/nixpkgs/tree/master/pkgs) 探究 nixpkgs 的交叉编译机制。

<!-- more -->

## 复杂的交叉编译需求

起因是有位同学想要用 nixpkgs 做到这样一件事：在 `aarch64-darwin` 上，构建一个 host 为 `x86_64-linux`，target 到 `i686-linux` 的 `gcc8` 在虚拟机中使用。

这是一个不太常规的需求。应对常规的交叉编译需求，nixpkgs 可以也只能传递两个 system 参数，`localSystem` 和 `crossSystem`：

```nix
let
  pkgs = import <nixpkgs> {
    localSystem = "..";
    crossSystem = "..";
  };
in ...
```

两个参数意为，在 `localSystem` 上构建 host 为 `crossSystem`，target 为 `crossSystem` 的软件。此时，软件的 host 和 target 是一样的，无法满足这位同学的需求。因此，有必要更深入地了解一下 nixpkgs 的交叉编译机制，从而找到满足需求的做法。

## 源码笔记

Nixpkgs 的文档并没有告诉我们如何获得一个指定 `(build, host, target)` 的 gcc，我直接从阅读源码开始。

### 入口

Nixpkgs 的入口有两个，分别是 `flake.nix` 和 `default.nix`。

由 [flake.nix](https://github.com/linyinfeng/nixpkgs/blob/ace5093e36ab1e95cb9463863491bee90d5a4183/flake.nix#L56) 可见，flake 的 `legacyPackages` 也是导入的 `default.nix`，只是显式传入了 `system` 参数。

```nix
legacyPackages = forAllSystems (system: import ./. { inherit system; });
```

[default.nix](https://github.com/nixos/nixpkgs/blob/ace5093e36ab1e95cb9463863491bee90d5a4183/default.nix) 的逻辑非常简单，判断 nix 的版本，如果不满足要求则 abort，否则导入 `pkgs/top-level/impure.nix`。

[pkgs/top-level/impure.nix](https://github.com/nixos/nixpkgs/blob/ace5093e36ab1e95cb9463863491bee90d5a4183/pkgs/top-level/impure.nix) 的名字有些怪，因为纯的情形也是一样导入该文件。

该文件中有多个不纯的逻辑：

1. 如果传入参数没有属性 `system` 或 `localSystem`，将 `localSystem` 变量设为 `builtins.currentSystem`。而 `builtins.currentSystem` 是不纯的，作用为获取求值平台的 “system”。
2. 如果传入参数没有属性 `config`，从 `NIXPKGS_CONFIG` 环境变量指定的文件，或 `~/.config/nixpkgs/config.nix`，或 `~/.config/nixpkgs/config.nix` 导入配置，设为 `config` 变量。
3. 如果传入参数没有属性 `overlays`，从 `<nixpkgs-overlays>`，或 `~/.config/nixpkgs/overlays.nix`，或 `~/.config/nixpkgs/overlays` 目录句导入 overlays，设为 `overlays` 变量。

去除这些不纯的逻辑，我们只考虑纯的情形，并去除历史遗留的 `system` 参数，整个文件的逻辑实际上仅仅如下：

```nix
{
    config ? {},
    overlays ? [],
    ...
} @ args:
import ./. (args // {
    inherit config overlays;
})
```

可能需要注意的是，

```nix
({ a ? 1, ... } @ args: args) { b = 1; }
```

求值结果为 `{ b = 1; }`，即默认值不会对 `args` 造成影响。

没错，该文件的逻辑仅仅为，为 `args` 加上 `config` 和 `overlays` 的默认值，导入 [pkgs/top-level/default](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/top-level/default.nix)，将加上默认值的 `args` 传递给它。

### pkgs/top-level/default.nix

结束了入口，来到了实际的 nixpkgs 逻辑。该函数做了以下几件事：

1. [system 的细化](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/default.nix#L61-L79)。
   为 `localSystem` 和 `crossSystem` 调用 `lib.systems.elaborate`。

   如果没有传入 `crossSystem`，默认为无交叉编译，即另 `lib.systems.equals crossSystem localSystem` 为真。

   `let` 中的 crossSystem 变量的定义中，`crossSystem0 == null` 一定不成立（其有默认值 `localSystem`，而 `localSystem` 被传入 `lib.systems.elaborate`，如果为 `null`，则一定报错）。因此其逻辑如下：

   ```nix
   { localSystem, crossSystem, ... } @ args:
   let
     crossSystem0 = crossSystem;
     # 注意，此处如果只有一个 `let`，则 `crossSystem` 将引用 `let` 中的定义，导致无限循环
   in let
     localSystem = lib.systems.elaborate args.localSystem;
     crossSystem =
       let system = lib.systems.elaborate crossSystem0; in
       if lib.systems.equals system localSystem
       then localSystem
       else system;
   in ...
   ```

   `crossSystem` 的逻辑为，若细化后的 `crossSystem` 与细化后的 `localSystem` 在 `lib.systems.equals` 意义上等价，则使 `localSystem` 和 `crossSystem` 共享同一个值。

2. [config 的处理](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/default.nix#L84-L101)。
   由于 `config` 可以是一个接受 `pkgs` 的函数，将最终的 `pkgs` 传入 `config`，然后通过 module 系统检查它的类型，获得默认值，并显示警告。

3. [overlays 参数的检查](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/default.nix#L54-L59)。对 overlays 参数的合法性进行检查。

   注意虽然 `checked` 最后的使用方式是 `checked pkgs`，但其并不检查和修改 `pkgs` 的内容。

4. 由 `localSystem`，`crossSystem`，`config`，`overlays`，`crossOverlays` 参数，构造 stdenv 的 stages。

5. `boot stages`，获得完整的包集。

其中最后两步是最重要的，需要分别查看它们的实现。boot 步骤中的 `pkgs/stdenv/booter.nix` 描述了 `stages` 是如何变成最终的包集的，它也描述了 `stages` 的类型，因此先查看 boot。

### boot

由 stdenv 的 `stages` 获得包集 `pkgs`，在 `pkgs/top-level/default.nix` 中逻辑如下：

```nix
nixpkgsFun = newArgs: import ./. (args // newArgs);

allPackages = newArgs: import ./stage.nix ({
  inherit lib nixpkgsFun;
} // newArgs);

boot = import ../stdenv/booter.nix { inherit lib allPackages; };

pkgs = boot stages;
```

### stdenv stages

[stages 变量](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/default.nix#L138-L140) 的定义为，其中 `stdenvStages` 是 `pkgs/top-level/default.nix` 的一个参数，默认值为 `import ../stdenv`，其中 `../stdenv` 即 `pkgs/stdenv/default.nix`。

```nix
stages = stdenvStages {
  inherit lib localSystem crossSystem config overlays crossOverlays;
};
```

虽然 `stdenvStages` 是 `pkgs/top-level/default.nix` 的一个参数，但是搜索整个 `nixpkgs` 可以发现，目前仅有 `pkgs/stdenv/darwin/make-bootstrap-tools.nix` 中传递了该参数。我暂时仅关注 Linux 下的交叉编译，无须考虑 `stdenvStages` 变化的情形。

```console
$ rg stdenvStages
pkgs/top-level/default.nix
39:  stdenvStages ? import ../stdenv
126:  stages = stdenvStages {

pkgs/stdenv/darwin/make-bootstrap-tools.nix
11:      then { stdenvStages = args:
320:    stdenvStages = args: let
```

#### pkgs/stdenv/default.nix

该文件是 `stdenvStages` 函数，它的目的是给出 `stdenv`，但最终返回的是一个阶段列表（list of stages）。在 `boot`（`pkgs/stdenv/booter.nix`）中被使用。

内容较为简单，将功能委派给了几个文件中的函数。如果我们只关心 Linux 和 Linux 的交叉编译，那么它的逻辑大概是这样的：

```nix
{
  lib, localSystem, crossSystem, config, overlays, crossOverlays ? []
} @ args:
let
  stagesCross = import ./cross args;
  stagesLinux = import ./linux args;
  ...
in
if crossSystem != localSystem || crossOverlays != [] then stagesCross
else if config ? replaceStdenv then stagesCustom
else if localSystem.isLinux then stagesLinux
else ...
```

`pkgs/stdenv/linux` 是 linux 的 stdenv 的 bootstrap,与交叉编译关系不大，因此主要阅读 `pkgs/stdenv/cross`。

但在阅读之前，首先至少要搞清楚这个函数最终需要返回什么。为此我们先通过 `pkgs/stdenv/booter.nix`，得知每个 stage 的“类型”，再阅读 `pkgs/stdenv/cross`。

#### stage 的类型

[`pkgs/stdenv/booter.nix``](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix) 的源码开头花了大篇幅的注释来讲解 stage 的设计，对此做一个翻译。

> 本文件定义了一个函数，它的作用是从一系列 stages boot 出一个包集。它具体的机制定义如下；此处我（[@Ericson2314](https://github.com/Ericson2314)）想要介绍该抽象的目的。
>
> 第一个目标是保持各个 stdenv 之间的一致性。无论这个函数做的事是什么，我们让所有的 stdenv 都使用这个函数来 bootstrap，从而保证它们都以差不多的方式工作。「在这个抽象之前，每个 stdenv 都是孤立的，因为它们是由不同的作者在不同的时间编写的。」
>
> 第二个目标是保持每个 stdenv 中 stage 函数的一致性。通过基于上一 stage 书写每个 stage，更容易体现出各个 stage 之间的共通性。「在之前，通常的做法是有一个大的属性集（attribute set），每个属性的值是一个 stage，stage 通过属性的名字来访问其他 stage。」
>
> 第三个目标是可组合性。因为每个 stage 都是基于上一 stage 书写的，stage 列表能够被重排或者，更实际的，增加新的 stages。增加新 stages 被用于交叉编译和定制 stdenv。并且，一些特定的选项只应该默认被应用于最后一个 stage，不论它可能是什么。通过将 stage 包集的创建，推迟到最后的 fold 进行的时刻，我们能够防止这类选项限制可组合性。
>
> 最后第四个目标是 debugging。对于普通的包，它们应该只能从当前 stage 中获得它们的依赖。但是为了 debugging，最好让所有的包都能被访问。我们总是保留之前的 stages。通过 `stdenv.__bootPackages` 属性访问前一个 stage。通常 `__` 开头的属性都具有特殊的限制，不应该在普通的场景中使用。

该文件接下来给出了它接受 `{lib, allPackages}` 参数后，返回的函数的类型。这个返回的函数即 `pkgs/top-level/default` 中的 [`boot` 函数](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/default.nix#L136)。

```txt
[ pkgset -> (args to pkgs/top-level/stage.nix) or ({ __raw = true; } // pkgs) ] -> pkgset
```

（原代码中笔误写成了“args to stage/default.nix”）

> 用中文来说：这个函数接收一个列表返回一个包集，接收的列表中，每个元素都是一个函数，这些函数都接收前一个 stage 的包集。每个这些函数的返回值意义为，如果 `__raw` 不存在或 `__raw = false`，那么返回这个 stage 的包集的参数（最终复杂也最重要的参数是 `stdenv`）；或者，如果 `__raw = true`，返回的就是这个 stage 的包集本身。
>
> Stages 是按这个列表的顺序被使用的，最后一个 stage 对应列表的最后一个元素。换句话说，这个函数使用 `foldr` 而不是 `foldl`。

按：原文说“this does a foldr not foldl”，但实际上最后一个 stage 对应列表的最后一个元素听起来是 `foldl` 才对。实际上这是因为应用之前列表被反转了。

本来到这里，我们已经知道 stage 的类型了，但是看都看了，我决定顺势把 `pkgs/stdenv/booter.nix` 的源码看完。实际上该文件的逻辑非常简单。

首先定义了 [`dfold` 函数](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix#L60-L73)：

```nix
op: lnul: rnul: list:
  let
    len = builtins.length list;
    go = pred: n:
      if n == len
      then rnul pred
      else let
        # Note the cycle -- call-by-need ensures finite fold.
        cur  = op pred (builtins.elemAt list n) succ;
        succ = go cur (n + 1);
      in cur;
    lapp = lnul cur;
    cur = go lapp 0;
  in cur
```

`dfold` 中的 `d` 应该意为 double，这是一个非常特殊的 fold 操作，注意其中的 `cur  = op pred (builtins.elemAt list n) succ`，如果把 `succ` 去掉，则这是一个 `foldl` 类似物（区别仅在于 `lnul` 是个函数）。`op pred (builtins.elemAt list n) succ` 中，`op` 接收 `pred` 上一个 stage 的包集，`(builtins.elemAt list n)` 当前 stage，`succ` 下一个 stage 的函数。

通过注释的展开形式可以更好地理解这个函数：`dfold op lnul rnul [x_0 x_1 x_2 ... x_n-1]` 等价于

```nix
let
  f_-1  = lnul f_0;
  f_0   = op f_-1   x_0  f_1;
  f_1   = op f_0    x_1  f_2;
  f_2   = op f_1    x_2  f_3;
  ...
  f_n   = op f_n-1  x_n  f_n+1;
  f_n+1 = rnul f_n;
in
  f_0
```

可见，这个 fold 的过程实际上是无所谓先后和左右的，每次 `op` 都同时接收上一个结果和下一个结果，返回当前结果，`lnul` 接收列表第 `0` 个元素对应的结果，返回第 `-1` 个元素的结果，`rnul` 接收列表最后一个元素，第 `n` 个元素对应的结果，返回第 `n + 1` 个结果。

最后，整个函数构造出了 `-1, ..., n + 1` 个结果，返回其中的结果 `0`。

为什么是结果 `0` 呢，我们需要的不是最后一个 stage 对应的包集么。原因是因为 stages 在传入 `dfold` 之前[会被反转一次](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix#L85)。所以我们拿到的确实是最后一个 stage 对应的包集。

了解了 `dfold`，我们分别查看它接收的各个参数。整个函数最终返回 `dfold folder postStage (_: {}) withAllowCustomOverrides`,

* `list` 参数：[`withAllowCustomOverrides`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix#L75-L85)。它的构造做了两件事情：

  1. 首先将 stage 函数列表变为逆序。从而最终 stage 变为第一个元素。
  2. 做一个 `imap1`，修改每个 stage 函数，令最终 stage（第一个元素）默认返回 `allowCustomOverrides = true`，令其他 stage 默认返回 `allowCustomOverrides = false`。

     也就是令最终 stage 的包集能进行 custom overrides，其他 stage 的包集不能。此处的 `allowCustomOverrides` 是 [`pkgs/top-level/stage.nix`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix) 的参数。

     这里这个实现有一点不好，即它不论是否有 `__raw == true`，都设置 `allowCustomOverrides`，但该参数只对 `__raw` 无定义或 `__raw = false` 的情形有意义，因此更正确的做法是先判断 `(stageFun prevStage).__raw or false`，如果为 `false` 才添加 `allowCustomOverrides = true/false`，否则直接返回 `(stageFun prevStage)`，即修改如下：

     ```nix
     (index: stageFun: prevStage:
       let result = (stageFun prevStage); in
       if result.__raw or false
       then result
       # So true by default for only the first element because one
       # 1-indexing. Since we reverse the list, this means this is true
       # for the final stage.
       else { allowCustomOverrides = index == 1; } // result)
     ```

     因为 `__raw == true` 时，`allowCustomOverrides` 不会被用到，所以修不修改用起来没有任何区别。

* `op` 参数：[`folder`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix#L87-L116)。这个函数由 `dfold` 的定义，依次接收三个参数 `nextStage`，`stageFun`，和 `prevStage`。注意到由于列表反转了，因此第一个参数是 `nextStage` 而最后一个参数是 `prevStage`。然后该函数构造 `thisStage` 并返回，它的构造如下：

  1. 首先将 `stageFun` 应用 `prevStage`，获得 `args`，它的类型为：`(args to pkgs/top-level/stage.nix) or ({ __raw = true; } // pkgs)`。

  2. 为 `args` 中的 `stdenv` 添加两个用于 debug 的属性 `__bootPackages = prevStage` 和 `__hatPackages = nextStage`。

     `thisStage` 是从 `prevStage` “boot” 出来的，而与 “boot”（靴子）相对的是 “hat”（帽子），真是好冷的笑话。

  3. 若 `args.__raw or false` 为 `true`，则直接返回 `args'`（添加了 debug 信息的 `args`）。

  4. 否则，`args`/`args'` 的类型是 `args to pkgs/top-level/stage.nix`，将它传入 `allPackages` 以获得包集，在传入之前，还需要对 `args'` 做两个修改：

     1. 删除 `args'` 中的 `selfBuild` 属性，该参数被用于构造新的 `adjacentPackages` 属性。
     2. 增加 `adjacentPackages` 属性。

        如果 `args.selfBuild` 为 `true` 或没有这个属性，则 `adjacentPackages` 为 `null`。

        否则构造 `adjacentPackages` 属性集。该属性集包含 `pkgsBuildBuild`，`pkgsBuildHost` 等包集，这些包集的概念我们需要阅读 [`pkgs/top-level/stage.nix`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix) 才能理解。

* `lnul` 参数：[`postStage`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix#L118-L140)。该参数按注释所说，是一个解决交叉编译的编译器的运行时依赖的 hack。它与具体的编译器有关，因此出现在这个文件中其实不好。按 `dfold` 的定义，`postStage` 构造了 `f_-1`，它并不是最终的 stage 包集，而是最终 stage 的 `nextStage`。在我们没有了解 `pkgs/stdenv/cross` 之前，无法读懂该函数。

读到这里，出现了我们还未知的新概念：`adjacentPackages`，和[其中出现的 `buildPackages`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix#L103C38-L103C51)。这说明在进入到 `pkgs/stdenv/cross` 的细节前，我们有必要回到 `pkgs/top-level/default.nix`，将 `boot` 函数的另一半，`allPackages` 理解清楚。

#### pkgs/top-level/stage.nix

回到 `pkgs/top-level/default.nix`，我们来看 `allPackages` 函数是如何构造的。

首先，构造 `nixpkgsFun`，它重新 import 了 `pkgs/top-level/default.nix`，将当前的 `args` 作为默认值，允许传入新的 `newArgs`。

```nix
nixpkgsFun = newArgs: import ./. (args // newArgs);
```

从这里开始已经有点让人十分费解了，`pkgs/top-level/default.nix` 返回的结果是 `checked pkgs`，其中 `pkgs = boot stages`，有完整的 boot 流程。为什么 `nixpkgsFun` 需要再次利用 `pkgs/top-level/default.nix` 呢。暂且压制疑问，继续阅读。

```nix
# Partially apply some arguments for building bootstraping stage pkgs
# sets. Only apply arguments which no stdenv would want to override.
allPackages = newArgs: import ./stage.nix ({
  inherit lib nixpkgsFun;
} // newArgs);
```

导入 `pkgs/top-level/stage.nix`，预先应用 `lib` 和 `nixpkgsFun`。那么一切的谜团应当能在该文件中得到解答。

> 这个文件包含一个单独的 nix 包集的 bootstrapping stage。即，它导入一系列构建不同包的函数，并且用合适的参数调用这些函数。函数的返回值是一个属性集，这个属性集包含 nixpkgs 中的所有包，并且这些包是为特定的平台和特定的 stage 构建的。

该“stage”接收以下参数：

* `lib`：没什么好说的，就是 `<nixpkgs/lib>`。
* `nixpkgsFun`：能以不同参数重新对 nixpkgs 进行求值的函数。
* `adjacentPackages`：`null`，或一个属性集，包含 `pkgsBuildBuild`，`pkgsBuildHost`，`pkgsBuildTarget`，`pkgsHostHost`，`pkgsTargetTarget` 五个包集。其中，`pkgsHostTarget` 被故意略过了，不应包含 `pkgsHostTarget`。

  > 这些包集是相邻 bootstrapping stages 的引用。更加熟悉的 `buildPackages` 和 `targetPackages` 是由这些包集定义的。如果为 `null`，则它们在当前 stage 内部被定义。这允许我们避免复杂的 splicing。`pkgsHostTarget` 被略过，因为他总是当前 stage 的包集。

* `stdenv`：用于构建的标准环境。
* `allowCustomOverrides`：是否允许包被 `config.packageOverrides` 选项 override。
* `noSysDirs`：非 GNU/Linux 的平台目前是不纯的。`libc` 不在 store 中。这个选项如果为 `true`，表示平台是纯的，如果为 `false`，表示平台是不纯的。
* `config`：nixpkgs 的配置属性集。
* `overlays`：nixpkgs 的 overlays。

接收参数后，该函数返回一个巨大的包集，这个包集是一个不动点 `lib.fix toFix`。`toFix` 定义为：

```nix
toFix = lib.foldl' (lib.flip lib.extends) (self: {}) ([
  stdenvBootstrappingAndPlatforms
  stdenvAdapters
  trivialBuilders
  splice
  autoCalledPackages
  allPackages
  otherPackageSets
  aliases
  configOverrides
] ++ overlays ++ [
  stdenvOverrides ]);
```

`lib.flip lib.extends`，这写法很 pointless，让我们看看每部分的类型大概都是什么：

* `lib.foldl': (b -> a -> b) -> b -> [a] -> b`（类型和 `foldl` 一样，名字中的 `'` 表示它是 strict 版本的 `foldl`）
* `lib.flip: (a -> b -> c) -> (b -> a -> c)`
* `lib.extends: (attrs -> attrs -> attrs) -> (attrs -> attrs) -> (attrs -> attrs)`。光看类型有点不明所以，查看[代码](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/lib/fixed-points.nix#L91)还是很好理解的，

  ```nix
  extends = f: rattrs: self: let super = rattrs self; in super // f self super;
  ```

  它实际上应看作是接收两个参数，`f` 和 `rattrs`，`f` 的意义为一个形如 `self: super: { ... }` 的函数，`rattrs` 是一个形如 `self: { ... }` 的函数，它的目的是将 `rattrs self` 作为 `f` 的 `super`，然后返回 `self : super // f self super` 函数，可以看到返回的函数类型与 `rattrs` 一致。

* `lib.flip lib.extends: (attrs -> attrs) -> (attrs -> attrs -> attrs) -> (attrs -> attrs)`。flip 后先接收 `rattrs`，后接收 `f`。
* `self: {}`，最开始的包集是空的。
* 一个列表 `[...]`，其中的每个元素类型都为 `(attrs -> attrs -> attrs)`。

如果你理解 `nixpkgs` 的 `overlays` 的话，这就是 `overlays` 的工作原理，事实上 `overlays` 就直接被拼接到了列表中。我们挨个查看列表中的每一个函数都是如何定义的，做了什么事情。

1. [`stdenvBootstrappingAndPlatforms`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L118-L146)。它做了以下几件事。

   * 根据 `adjacentPackages`，向属性集中增加 `pkgsBuildBuild`..`pkgsTargetTarget`，每个这些相邻包集都被设置了 `recurseForDerivations = false`，以防止遍历包集的程序无限递归。如果 `adjacentPackages` 为 `null`，则所有的这些包集都是 `self`。最后，特例 `pkgsHostTarget` 为 `self // { recurseForDerivations = false; }`。
   * `buildPackages = self.pkgsBuildHost`；`pkgs = self.pkgsHostTarget`；`targetPackages = self.pkgsTargetTarget`。这三个是旧有的包集名称。但今日仍有它的作用。`pkgsXY` 表示这个包集中的包的 host 平台为当前包集的 `X` 平台，target 平台为当前包集的 `Y` 平台。当我们不关心 target 平台时，我们就使用 `buildPackages`，`pkgs`，和 `targetPackages`。
   * `inherit stdenv`，将 `stdenv` 添加到属性集中。

2. [`stdenvAdapters`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L100-L108)。该函数只使用 `self`。引入 [`pkgs/stdenv/adapters.nix`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/adapters.nix) 中定义的 `overrideCC` 等接收 `stdenv` 返回 `stdenv` 的函数，这些函数便于用户修改 `stdenv` 的行为。

   这些函数会被加入到顶层，但在 `stdenvAdapters` 属性中也有一份。

3. [`trivialBuilders`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L110-L116)。该函数只使用 `self`。引入 [`pkgs/build-support/trivial-builders/default.nix`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/build-support/trivial-builders/default.nix) 中定义的 `runCommand` 等函数。

   这些函数只会被加入到顶层。

4. [`splice`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L148)。该函数只使用 `self`。导入 [`pkgs/top-level/splice.nix`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/splice.nix)，额外传入一个 `actuallySplice` 参数，值为 `adjacentPackages != null`，即当包集不是 `selfBuild` 时，就需要做实际的 splice。

   `splice` 使得大部分包都不需要手动指定依赖的 host 和 target 平台。它简化了在 nixpkgs 中进行交叉编译的工作量。我们将在之后再仔细阅读它的内容。

   我们可以提前知道的是，有一些非常重要的常用函数来自于 `splice.nix`：`callPackage`，`callPackages`，`newScope`，等等。

5. [`autoCalledPackages`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L16) 和 [`allPackages`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L150-L154)。分别是新式的按路径自动导入的包和传统的 `all-packages.nix`，他们包含了 nixpkgs 除了 `stdenv` 以外的所有的包。

6. [`otherPackageSets`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L182)。提供了便捷的 `pkgsCross`，`pkgsLLVM`，`pkgsMusl`，`pkgsi686Linux`，`pkgsx86_64Darwin`，和 `pkgsStatic`，所有这些都是通过 `nixpkgsFun` 重新对整个 nixpkgs 进行求值实现的。

   至此 `nixpkgsFun` 的谜团破解，原来只是为了实现这些便捷的属性，需要对整个 nixpkgs 用不同的 `crossSystem` 进行重新求值而已。

7. [`aliases`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L156)。提供了用于保持兼容性的别名，可由 `config.allowAliases` 控制。

8. [`configOverrides`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L171-L173)。当 `allowCustomOverrides` 为真时，应用 `config.packageOverrides`。

   `packageOverrides` 只能接收 `super`，它接受的这个 `super` 非常有讲究。

   * 不同于 `overlays`，`packageOverrides` 仅在最后一个 stage 中被应用。
   * 在最后一个 stage 中 `packageOverrides` 也优先于所有的 `overlays`。

   `packageOverrides` 的这两个特征使它能够具有不同于 `overlays` 的功能。

9. [`overlays`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L68-L70)。用户提供的 overlay 列表。

10. [`stdenvOverrides`](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/top-level/stage.nix#L158-L162)。在 stage 的最后，如果 `stdenv.overrides` 存在，则应用它，否则什么也不做。

    按照注释所说，它的作用时避免 stdenv 的 bootstrap 过程中，一些特定依赖的多个版本同时被使用。它具体是如何做到的，我们需要阅读 `stdenv` 的代码才能知道。

总体来说，这个文件还是非常易于理解的。

##### 相邻包集

现在我们可以回到 `pkgs/stdenv/booter.nix` 中[定义相邻包集的代码](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/booter.nix#L102-L113)。

我们一个属性一个属性地来看：

* `pkgsBuildBuild = prevStage.buildPackages = prevStage.pkgsBuildHost`

  它的定义有点怪，我们先略过。

* `pkgsBuildHost = prevStage = prevStage.pkgsHostTarget`

  很好理解，当前 stage 的 build 平台 就是前一个 stage 的 host 平台，而当前 stage 的 host 平台就是前一个 stage 的 target 平台。因此，host 平台为当前 stage 的 build 平台，target 平台为当前 stage 的 host 平台的包集，就是 `prevStage.pkgsHostTarget`，即 `prevStage`。

* `pkgsBuildTarget`

  若 `with args.stdenv; targetPlatform == hostPlatform` 则 `pkgsBuildTarget = pkgsBuildHost`；
  否则 `pkgsBuildTarget = thisStage = pkgsHostTarget`（并要求 `with args.stdenv; buildPlatform == hostPlatform`）。

  Host 平台为当前 stage 的 build 平台，target 平台为当前 stage 的 target 平台的包集并不总是存在，因为这听起来就很怪，不是 bootstrap 过程中可能出现的东西。所以只有当当前 stage 的 target 平台等于 host 平台，或 build 平台等于 host 平台时，才分别等于 `pkgsBuildHost` 或 `pkgsHostTarget`。

* `pkgsHostHost`

  若 `with args.stdenv; hostPlatform == targetPlatform` 则 `pkgsHostHost = thisStage = pkgsHostTarget`；
  否则 `pkgsHostHost = pkgsBuildHost`（并要求 `with args.stdenv; buildPlatform == hostPlatform`）

  Host 平台为当前 stage 的 host 平台，target 平台也为当前 stage 的 host 平台的包集也并不总是存在，同样只有当当前 stage 的 target 平台等于 host 平台，或 build 平台等于 host 平台时，才分别等于 `pkgsHostTarget` 或 `pkgsBuildHost`。

* `pkgsTargetTarget = nextStage = nextStage.pkgsHostTarget`

  它的定义和 `pkgsBuildBuild` 一样也很怪。

可以看到 `pkgsBuildBuild` 和 `pkgsTargetTarget` 似乎没有遵循我们的直觉。

* 直觉上，`pkgsBuildBuild` 应该是一个 host 平台为当前 stage 的 build 平台，target 平台也为当前 stage 的 build 平台的包集，这看起来应该等于 `prevStage.pkgsHostHost`。
* 同样，直觉上，`pkgsTargetTarget` 应该是一个 host 平台为当前 stage 的 target 平台，target 平台也为当前 stage 的 target 平台的包集，这看起来应该等于 `nextStage.pkgsHostHost`。

为了弄清这件事，只能查看文档了。

根据 `nixpkgs` 的文档 [Bootstrapping](https://nixos.org/manual/nixpkgs/stable/#ssec-bootstrapping) 一节：

> 在每一个 stage，`pkgsBuildHost` 指向前一个 stage，`pkgsBuildBuild` 指向前一个 stage 的前一个 stage，`pkgsHostTarget` 指向当前 stage，`pkgsTargetTarget` 指向下一个 stage。当没有前一个或后一个 stage 时，指向当前 stage。
>
> `pkgsBuildTarget` 和 `pkgsHostHost` 更加复杂，因为满足要求的 stage 不总能在固定的“前一个”和“后一个”的链条中找到。

因此，按照文档，虽然看起来与名字不符，但 `pkgsBuildBuild` 就是前一个 stage 的前一个 stage，而 `pkgsTargetTarget` 就是后一个 stage。在没有更深入的理解前，只能接收它。

### stdenv

至此，我们实际上已经把除了 `stdenv` 本身以外的整个框架阅读完了。接下来我们的目的应该有两个：

1. 理解 `stdenv` 的 bootstrap 和交叉编译。
2. 理解交叉编译中其他的包如何获得正确的依赖。

#### pkgs/stdenv/linux

定义了 Linux 平台的 stdenv 的 stage 函数，从 `bootstrapFiles` 开始，构建最终的 `stdenv`，如注释所说，这个 bootstrap 的目标是：

1. 最终的 `stdenv` 不引用任何 bootstrap 文件。
2. 最终的 `stdenv` 不包含任何 bootstrap 文件。
3. 最终的 `stdenv` 不包含任何由 bootstrap 文件直接生成的文件（汇编器，链接器，编译器）。

Nixpkgs 用非常人性化的方式说明这一点，定义了[四个用于断言的函数](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/linux/default.nix#L103-L109)：

1. `isFromNixpkgs`：只要不满足 `isFromBootstrapFiles`，就满足。
2. `isFromBootstrapFiles`：构建自 bootstrap 文件的 derivation 会被加入 `passthru.isFromBootstrapFiles` 属性，如果该属性为 `true` 则 `isFromBootstrapFiles` 为真。
3. `isBuiltByNixpkgsCompiler`：`isFromNixpkgs` 且 `isFromNixpkgs pkgs.stdenv.cc.cc`，即包本身不由 bootstrap 文件构建，且 `stdenv.cc.cc` 也不由 bootstrap 文件构建。注意，`pkgs.stdenv.cc.cc` 中，`stdenv.cc` 是 `cc` wrapper，`stdenv.cc.cc` 是没被包装的 `cc`。
4. `isBuiltByBootstrapFilesCompiler`：`isFromNixpkgs` 且 `isFromBootstrapFiles pkgs.stdenv.cc.cc`。

在整个 bootstrap 过程中，要构建的东西是六个：

1. `binutils-unwrapped`
2. `localSystem.libc`
3. `gcc-unwrapped`
4. `coreutils`
5. `gnugrep`
6. `patchelf`

他们是 `stdenv` 所需的所有的编译期二进制依赖（其他依赖都是 bash 脚本）。

让我们从顶层开始，直接看各个 stage 函数。

1. [初始空 stage](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/linux/default.nix#L217-L224)。该 stage `__raw = true`，将四个依赖设为 `null`。
2. [stage0](https://github.com/NixOS/nixpkgs/blob/59e3ceebffcaaea038062d5365fc64e0dd39da4f/pkgs/stdenv/linux/default.nix#L226-L271)。

#### pkgs/stdenv/cross
