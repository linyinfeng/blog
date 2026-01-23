+++
title = "如何用 LaTeX 画 SVG 矢量图"
description = "使用 dvisvgm 生成 SVG 矢量图"
date = 2026-01-23 23:32:25+08:00
updated = 2026-01-23 23:57:39+08:00
author = "Yinfeng"
draft = false
[taxonomies]
categories = ["笔记"]
tags = ["TeX", "LaTeX", "TikZ", "dvisvgm", "冷知识"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

眼尖的你一定已经发现了，本博客的 logo 其实是一个圈里面写了一个 `\mathfrak{Y}`，其实它是用 [TikZ](https://tikz.dev/) 画的。
我们可以使用 [dvisvgm](https://dvisvgm.de/) 生成高质量的 SVG 在各种地方使用。

<!-- more -->

## $\TeX$ 的输出机制

一般来说，$\TeX$ 的输出可以被看成两个步骤：

1. $\TeX$ 做排版后，输出一个 `.dvi`（device independent file）文件。DVI 文件本身的指令能力不强，只能排版文字和黑白框。但是 DVI 有一个机制叫作 specials，在 $\TeX$ 中对应 `\special`。Specials 允许在 DVI 文件中嵌入一些特定设备相关的指令，比如插入图片、颜色、超链接等。
2. 一个其他的程序（比如 `dvipdfm`、`dvisvgm` 等）读取 DVI 文件，并根据其中的指令生成最终的输出文件，比如 PDF、SVG 等。

可以看到，DVI 的“设备无关”其实挺局限的，因为它依赖程序来解释设备相关的 special 指令。

## 使用 dvisvgm 生成 SVG

所以我们要做的就是两步：

1. 指示 $\TeX$ 生成 `dvisvgm` 能够理解的 DVI。

   $\LaTeX$ 的 `graphics` 包有一个复杂的机制选择驱动程序（driver），用来生成不同设备的输出。TikZ 也是基于这个机制来选择驱动的。对于 TikZ 来说，支持的驱动程序可以在[这里](https://tikz.dev/drivers)找到。

   我们只需要在 $\LaTeX$ 文档的 `\documentclass` 中指定全局 `dvisvgm` 选项即可。

   ```latex
   \documentclass[dvisvgm]{standalone}
   ```

   调用任意 $\LaTeX$ 程序（比如 `lualatex`、`xelatex`、`latex` 等）生成 DVI 文件。

   ```bash
   latex image.tex
   xelatex --no-pdf image.tex
   lualatex --output-format=dvi image.tex
   ```

   生成 `image.dvi` 文件。
   如果是 `xelatex` 将生成 `image.xdv`（扩展 DVI 文件），`dvisvgm` 也支持。

2. 使用 `dvisvgm` 将 DVI 转换为 SVG。

   ```bash
   dvisvgm image.dvi
   ```

## 字体嵌入问题

默认情况下可能会发现 `dvisvgm` 生成的 SVG 里面字体显示不正确。这是因为默认情况下，`dvisvgm` 会使用几乎没有什么浏览器支持的 SVG `<font>` 元素将字体嵌入图片。

{{ image(path="with-svg-font.svg", alt="一张只能在极少数浏览器中正确显示的 SVG 图片", caption="使用 SVG 字体的本站 logo", width="200")}}

解决方法有多种：

1. 我们可以使用现代的 WOFF/WOFF2 字体格式，将字体嵌入 SVG。使用 `--font-format=woff/woff2` 选项。（其实 dvisvgm 还支持嵌入 TTF，但这听起来很不浏览器。）

   ```bash
   dvisvgm --font-format=woff2 image.dvi
   ```

   这样生成的 SVG 可以在大多数现代浏览器中正确显示。

   {{ image(path="with-woff-font.svg", alt="一张可以在大多数现代浏览器中正确显示的 SVG 图片", caption="使用 WOFF 字体的本站 logo", width="200")}}

   但是在非浏览器，比如一些图片查看器中，可能仍然无法正确显示字体。

2. 或者，我们可以让 `dvisvgm` 将字体转换为路径，这样就彻底不依赖字体支持了。使用 `--no-fonts` 选项即可。

   ```bash
   dvisvgm --no-fonts image.dvi
   ```

   代价是如果文字很多那么文件将会变得大，文字信息也会从 SVG 中被彻底去除，无法从图片中选择字体。

## 本站的 logo

最后，本站的 logo 定义如下：

```latex
\documentclass[dvisvgm]{standalone}

\usepackage{tikz}
\usepackage{amsfonts}

\begin{document}

\begin{tikzpicture}[every node/.style={inner sep=0,outer sep=0}]
    \fill [black] (0, 0) circle (20cm);
    \node [color=white, scale=100] at (0, 0) {$\mathfrak{Y}$};
\end{tikzpicture}

\end{document}
```

（当时我不知道怎么想的就画了一个直径 40cm 的巨大 logo。）

由 Nix 调用 $\TeX$ 和 [ImageMagick](https://imagemagick.org) 构建生成（代码可见[本站源码](https://github.com/linyinfeng/blog/blob/b6f1d0dd8fba8d38fc45488f8461580ebaae7d47/nix/favicon.nix)）。

## 参考

- [PGF/TikZ - Supported Formats](https://tikz.dev/drivers)
- [Device independent file format](https://en.wikipedia.org/wiki/Device_independent_file_format)
- [dvisvgm Manual](https://dvisvgm.de/Manpage/)
