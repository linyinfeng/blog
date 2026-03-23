+++
title = "莫比乌斯环彩虹无限符号"
# description = ""
date = 2026-03-23 12:13:03+08:00
updated = 2026-03-23 19:02:41+08:00
author = "Yinfeng"
draft = false
[taxonomies]
categories = ["笔记"]
tags = ["3D 建模", "平面设计", "Python", "build123d"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
thumbnail = "render-square-1080p-black.png"
+++

记录一个有趣的 3D 建模和渲染项目：莫比乌斯环构成的彩虹渐变无限符号。

<!-- more -->

## 目标

我想要建模一个由莫比乌斯环构成的无限符号，我希望这个物体：

1. 在俯视图下是一个完美的正圆形。
2. 在前后视图和两个侧视图下都呈现出完美的无限符号（$\infty$）的形状。

为什么需要是正圆形？因为这样我就可以使用从原点开始，径向色相渐变的彩色光为该物体做照明，从而渲染出一个均匀的流光溢彩的无限符号。

{{ image(path="point-lighting.png", alt="径向色相渐变点状光源", caption="径向色相渐变点状光源", width="250")}}

## 建模

我使用 Python 的 [build123d](https://build123d.readthedocs.io) 库来建模。这个库是一个基于 Open CASCADE 内核的 CAD 建模库，可以直接使用代码设计复杂的 3D 模型。

我在中途犯过很多的错误，要建模一个不规则的莫比乌斯环实际上并不容易，本文将直接展示一条正确的建模路径，并且会偶尔提一嘴我之前犯过的错误。

### 预备工作

首先先导入 build123d 和用来调试的 ocp_vscode 库，然后先定义一些参数，一些参数的意义将在后面被提到。

```python
from build123d import *
from ocp_vscode import *
import math

class Config:
    def __init__(self):
        self.radius = 20.0
        self.max_height = self.radius
        self.width = 5.0
        self.thickness = self.width
        self.segments = 360

cfg = Config()
```

### 主路径

我首先选择建模一条主路径，也就是整个物体的中心线。这个路径需要满足前面提到的两个条件，俯视图下是正圆，且测试图看起来是一个无线符号。

#### 第一象限

将主路径这个正圆的圆心放在原点，简单思考就会意识到，这条主路径在四个象限都是相似的。
所以，我只需要建模第一象限的路径，然后通过镜像/旋转等操作就可以得到完整的路径了。

```python
def build_q1_line():
    q1_xy = CenterArc((0, 0), cfg.radius, 0, 90)
    wall_face = sweep(q1_xy, Line((0, 0, 0), (0, 0, cfg.max_height)))
    q1_plane = Plane.XY * Pos(cfg.radius / 2, cfg.radius / 2)  * Rotation(Z=-45) * Rotation(X=45)
    splitted = split(wall_face, bisect_by=q1_plane, keep=Keep.BOTH)
    edges_diff = splitted.edges() - wall_face.edges()
    assert len(edges_diff) == 1
    return edges_diff[0]

q1_line = build_q1_line()
```

我们一步一步来看：

1. 首先我创建了一个第一象限的圆弧 `q1_xy`，这个圆弧是主路径在 XY 平面上的投影。并使用 sweep 将圆弧抬升成一个面 `wall_face`。

   {{ image(path="wall-face.png", alt="第一象限的圆弧面", caption="第一象限的圆弧面", width="500")}}

2. 第二步，我构造了一个斜 45 度向上的 plane，并用这个 plane 切割之前的面。这个 plane 与第一象限的圆弧的两个端点相交。因此切割后，切割线两端的端点一定刚好落在坐标轴上。

   {{ image(path="splitted.png", alt="切割后的圆弧面", caption="切割后的圆弧面", width="500")}}

3. 第三步，只保留这条切割线，这条切割线就是第一象限的主路径了。因为切割后只会多出一条边，因此直接计算切割前后的边的差集就可以得到这条边了。

   {{ image(path="q1-line.png", alt="第一象限的主路径（斜视图）", caption="第一象限的主路径（斜视图）", width="500")}}

   {{ image(path="q1-line-front.png", alt="第一象限的主路径（前视图）", caption="第一象限的主路径（前视图）", width="500")}}

   可以看到，前视图呈现一个 1/4 无限符号。

#### 四象限组合

接下来，通过镜像和旋转操作，拼合出一个完整的圈。

```python
def build_main_path():
    q2_line = mirror(q1_line, Plane.XY).rotate(Axis.Z, 90)
    half_circle = q1_line + q2_line
    return half_circle + half_circle.rotate(Axis.Z, 180)

main_path = build_main_path()
```

1. 第一步，将第一象限路径镜像到下方，然后旋转 90 度到第二象限，并拼接成一个半圆。

   {{ image(path="half-circle.png", alt="第一二象限的主路径", caption="第一二象限的主路径", width="500")}}

2. 第二步，将这个半圆再旋转 180 度，并拼接到原来半圆的后面，就得到了完整的主路径。

   {{ image(path="main-path.png", alt="完整的主路径（斜视图）", caption="完整的主路径（斜视图）", width="500")}}

   <div class="row-container">

   {{ image(path="main-path-front.png", alt="完整的主路径（前视图）", caption="完整的主路径（前视图）", width="250")}}

   {{ image(path="main-path-top.png", alt="完整的主路径（顶视图）", caption="完整的主路径（顶视图）", width="250")}}

   </div>

   可以看到，前视图呈现一个无限符号，顶视图呈现一个正圆形。

### 莫比乌斯环

接下来，我需要在这个主路径的基础上建模出一个莫比乌斯环。也就是说，我需要在主路径的每个位置构造一个横截面，并且让这个横截面沿着主路径进行旋转 180 度的扭转。

你可能会想到，我可以先构造一个横截面，然后让这个截面跟随主路径进行 `sweep`，直接生成一个莫比乌斯环。理论上这是可行的，但是在 build123d 里就不太可行。在 build123d 里，要控制这个截面进行 180 度的旋转，就需要生成一条 binormal 路径作为参考来进行控制。但是，由于主路径和 binormal 路径都非常不规则，内核生成的 binormal 路径和主路径的对应关系是错误的，导致生成的莫比乌斯环会出现宽度和厚度的扭曲，这**不完美**。

我的做法是：

1. 直接计算坐标，用样条生成整个环的边界线，它将形成成一条闭合的 `Wire`。
2. 但是由于莫比乌斯环的特殊性（具体原因其实我不知道），build123d 并无法从这条 `Wire` 执行 `Face.make_surface` 来生成一个表面。
3. 所以我将这条边界线切分为两个部分，变成两个闭合的 `Wire`，每个 `Wire` 都可以执行 `Face.make_surface` 来生成一个面。
4. 最后将这两个面拼接在一起，就得到了完整的莫比乌斯环。

#### 边界线

我分为两部分来生成这条边界线，一次生成一半，然后合并。

```python
def rotating_spline(begin_angle=0.0, distance=cfg.width / 2.0):
    pts = []
    for i in range(cfg.segments + 1):
        position = main_path @ (i / cfg.segments)
        circle_radian = math.radians(360.0 * i / cfg.segments)
        rotation_radian = begin_angle + circle_radian / 2.0
        radial = position.normalized()
        normal = position.cross(Vector(0, 0, 1))
        up = normal.cross(radial).normalized()
        offset = (radial * math.cos(rotation_radian) + up * math.sin(rotation_radian)) * distance
        pts.append((position + offset).center())
    return Spline(pts)

line1 = rotating_spline()
line2 = rotating_spline(math.pi)
```

1. 我用样条生成边界线，边界上的每个点都是在主路径上偏移一个 `offset` 向量得到的。
2. `offset` 是由一个角度 `rotation_radian` 控制的，这个角度从 `begin_angle` 开始，随着主路径的前进而不断旋转，旋转一周后旋转 180 度。
3. 一次生成一圈，第一圈 `rotation_radian` 从 0 度开始，第二圈 `rotation_radian` 从 180 度开始，因为每圈过后 `rotation_radian` 变化 180 度，因此两圈就会首尾相接。

<div class="row-container">

{{ image(path="spline-line1.png", alt="边界线的第一部分", caption="边界线的第一部分", width="250")}}

{{ image(path="spline-line2.png", alt="边界线的第二部分", caption="边界线的第二部分", width="250")}}

</div>

{{ image(path="spline-line1-line2.png", alt="完整的边界线", caption="完整的边界线", width="500") }}

其中一个有意思的点是角度 `rotation_radian` 的参照系。我将这个角度的 0 度设置为原点到主路径的向量 `radial`。也就是说，`rotation_radian` 的值为 0 度时，偏移的方向是直接朝向主路径的径向的。角度的 90 度位置设置为 `up` 向量，`up` 与 Z 轴和 `radial` 向量共面，且 `up` 与 `radial` 垂直。

这里我在写代码时，发现立体几何和线性代数有点还给老师了，不知道该怎么算出 `up` 向量。向 LLM 请教一番后，才想起来法向量这个东西。

1. 计算平面的法向量，可以计算平面上两个向量的叉积，就能得到垂直于这两个向量的第三个向量。
2. 首先算出 Z 轴和 `radial` 构成的平面的法向量 `normal`，然后再计算法向量与 `radial` 的叉积，就得到了 `up` 向量了，`up` 向量一定在该平面上，且与 `radial` 向量垂直。
3. 利用两次右手定则，使得 `up` 朝上方即可。

#### 环面

我将两条边界线 `line1` 和 `line2` 切分成两部分，得到四条线段，然后将这些线段拼接成两个闭合的 `Wire`，为每个 `Wire` 分别执行 `Face.make_surface` 生成一个非平面，最后将这两个面拼接在一起，就得到了完整的莫比乌斯环面。

```
line11, line12 = line1.split(Plane.XZ, keep=Keep.BOTH)
line21, line22 = line2.split(Plane.XZ, keep=Keep.BOTH)
connect_line1 = Line(line11 @ 0, line21 @ 0)
connect_line2 = Line(line11 @ 1, line21 @ 1)
wire1 = Wire([line11, line21, connect_line1, connect_line2])
wire2 = Wire([line12, line22, connect_line1, connect_line2])
face1 = Face.make_surface(wire1)
face2 = Face.make_surface(wire2)
infinity_face = face1 + face2
```

<div class="row-container">

{{ image(path="wire1.png", alt="切分后拼接得到的第一个环", caption="切分后拼接得到的第一个环", width="250")}}

{{ image(path="wire2.png", alt="切分后拼接得到的第二个环", caption="切分后拼接得到的第二个环", width="250")}}

</div>

{{ image(path="infinity-face.png", alt="完整的莫比乌斯环面", caption="完整的莫比乌斯环面", width="500") }}

#### 体积

最后，只要使用 `thicken` 操作将这个面加厚，就得到了一个完整的有体积的莫比乌斯环了。在 `build123d` 中，`thicken` 操作可以作用于非平面。

```python
infinity = thicken(infinity_face, cfg.thickness / 2.0, both=True)
```

<div class="row-container">

{{ image(path="square.png", alt="方形截面的莫比乌斯环（斜视图）", caption="方形截面的莫比乌斯环（斜视图）", width="250")}}

{{ image(path="square-top.png", alt="方形截面的莫比乌斯环（顶视图）", caption="方形截面的莫比乌斯环（顶视图）", width="250")}}

{{ image(path="square-front.png", alt="方形截面的莫比乌斯环（前视图）", caption="方形截面的莫比乌斯环（前视图）", width="250")}}

{{ image(path="square-left.png", alt="方形截面的莫比乌斯环（左视图）", caption="方形截面的莫比乌斯环（左视图）", width="250")}}

</div>

可以看到，两个侧视图展现出了不同的扭转角度，可以渲染出不同的效果。

在最开始我设置的参数中，`thickness` 等于 `width` 的值，这样就得到了一个方形截面的莫比乌斯环了。我还将 `thickness` 的值设置为 `width` 的一半，得到一个矩形截面的莫比乌斯环。

<div class="row-container">

{{ image(path="rectangle-infinity.png", alt="矩形截面的莫比乌斯环", caption="矩形截面的莫比乌斯环", width="250")}}

{{ image(path="rectangle-infinity-top.png", alt="矩形截面的莫比乌斯环（顶视图）", caption="矩形截面的莫比乌斯环（顶视图）", width="250")}}

{{ image(path="rectangle-infinity-front.png", alt="矩形截面的莫比乌斯环（前视图）", caption="矩形截面的莫比乌斯环（前视图）", width="250")}}

{{ image(path="rectangle-infinity-left.png", alt="矩形截面的莫比乌斯环（左视图）", caption="矩形截面的莫比乌斯环（左视图）", width="250")}}

</div>

在矩形截面的版本中，前视图的左侧会略小于右侧，导致视觉不平衡。但左侧截面中，位于前方的部分宽度更窄，所以我利用透视相机，把更窄的这部分放在更近的位置（因此看起来更大），以达到左右视觉对称。

## 渲染

目前我只做了一个比较基础的渲染。直接将模型导入 Blender，设置一系列从原点开始的径向色相渐变光源，就可以渲染出彩虹的效果了。我取巧没有试图通过材质（还没学会）使得这个莫比乌斯环呈现出彩虹效果，而是使用光源间接赋予这个环色彩。

我一共采用了三种光源：

1. 上下各一个点光源照亮模型内侧；
2. 上下各一个面光源照亮模型的上方和下方；
3. 一个圆柱形的光源，照亮模型的外侧。

放置如下，所有被选中（橙色）物体都是光源。

{{ image(path="blender-lighting.png", alt="Blender 中的光源放置", caption="Blender 中的光源放置", width="500")}}

每个光源的配置都大差不差，以面光源为例。使用坐标作为输入，构造一个径向渐变纹理即可。

{{ image(path="blender-lighting-shader.png", alt="面光源的 shader 配置", caption="面光源的 shader 配置", width="500") }}

最后调整好相机位置，模型的材质，以及色彩管理的设置，就可以渲染出最终的效果了。

## 最终效果

那么最后，请看渲染结果。

<div class="row-container">

{{ image(path="render-square-1080p.png", alt="莫比乌斯环彩虹无限符号（方形截面版本）", caption="莫比乌斯环彩虹无限符号（方形截面）", width="300")}}

{{ image(path="render-rectangle-1080p.png", alt="莫比乌斯环彩虹无限符号（矩形截面版本）", caption="莫比乌斯环彩虹无限符号（矩形截面）", width="300")}}

{{ image(path="render-square-front-1080p.png", alt="方形截面的莫比乌斯环（前视图渲染）", caption="莫比乌斯环彩虹无限符号（方形截面，前视图）", width="300")}}

</div>
