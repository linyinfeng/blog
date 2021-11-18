+++
title = "Git plumbling 命令"
description = ""
date = 2021-09-16 23:40:53+08:00
updated = 2021-09-16 23:40:53+08:00
author = "Lin Yinfeng"
draft = true
[taxonomies]
categories = ["笔记"]
tags = ["版本管理", "Git"]
[extra]
license_image = "![Creative Commons License](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png)"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

近日发现 git 的文档中有一个名为 [gitcore-tutorial](https://git-scm.com/docs/gitcore-tutorial) 的教程。这个教程解释了如何使用一些“核心” git 命令在 git 仓库上工作，学习后我认为这个教程非常有用。

在 git 的[命令列表](https://git-scm.com/docs/git#_git_commands)中，命令被分为两类。一类是高层的，“porcelain”（精美的）命令；一类是底层的，“plumbling”（管道的）命令。
这个教程中所谓的“核心” git 命令指的便是这些 plumbling 命令。

虽然大部分用户很少有机会直接去使用这些 plumbling 命令，但了解这些命令，有助于我们更好地理解 git 的原理，进而提升我们使用任何命令的水平。

<!-- more -->

## TODO
