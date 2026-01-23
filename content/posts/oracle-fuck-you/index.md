+++
title = "珍爱数据，远离 Oracle Cloud"
description = "Oracle Cloud 免费账户无预警禁用的经历"
date = 2023-02-24 10:46:01+08:00
updated = 2023-02-24 10:46:01+08:00
author = "Yinfeng"
draft = false
[taxonomies]
categories = ["运维日志"]
tags = ["Oracle", "Oracle Cloud", "吐嘈"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
+++

我的 Oracle Cloud 免费账户的权限被禁用了，无任何邮件提醒，不提供数据恢复手段。好在我没有部署任何存储有价值数据的服务到 Oracle Cloud 实例上。现已重部署所有服务到其他机器上。提醒大家珍爱数据，远离 Oracle Cloud。

<!-- more -->

## 使用情况

- Tier：Always Free Tier
- 卡：中行跨境通 Visa
- Region：us-ashburn-1
- 使用时间：2022-09 至 2023-02-23
- 实例：1 台 arm 机器，4C24G，150G 硬盘

  日常运行服务：grafana，influxdb，loki，alertmanager，以及作为 nix build server

  负载较轻，每日凌晨 hydra build 时负载较重

## 事件经过

2023-02-24 晨发现 github 仓库 [linyinfeng/dotfiles](https://github.com/linyinfeng/dotfiles) terraform worflow 报错，查看了 23 日晚 23 点被触发的 workflow 没有报错，因此事件应该发生在 24 日凌晨（东 8 区）。由于帐号在 Oracle 新加坡，不明白为何事件发生在凌晨。

报错内容（[runs/4258439141/jobs7409677425](https://github.com/linyinfeng/dotfiles/actions/runs/4258439141/jobs/7409677425)）：

```txt
╷
│ Error: 401-NotAuthenticated, The required information to complete authentication was not provided or was incorrect.
│ Suggestion: Please retry or contact support for help with service: Identity Compartment
│ Documentation: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_compartment
│ API Reference: https://docs.oracle.com/iaas/api/#/en/identity/20160918/Compartment/GetCompartment
│ Request Target: GET https://identity.us-ashburn-1.oci.oraclecloud.com/20160918/compartments/ocid1.compartment.oc1..aaaaaaaaikp5stvcw3ynsrbxkermuo4uz7atqo2nmmkn6mh4gnmc3ouokssa
│ Provider version: 4.108.1, released on 2023-02-21.
│ Service: Identity Compartment
│ Operation Name: GetCompartment
│ OPC request ID: 1c52a2ed4c66355a2311e9a2c397c49d/D27F3EFEB233947ED8FDBBDB2776B59E/B75CC5B022B3B7A000DEFF6347E1ABC1
│
│
│   with oci_identity_compartment.terraform,
│   on oci.tf line 13, in resource "oci_identity_compartment" "terraform":
│   13: resource "oci_identity_compartment" "terraform" {
│
╵
```

`GetCompartment` 操作 `401`，随即尝试打开机器上部署的 grafana 查看，Cloudflare 提示主机无响应。

登录 Oracle Cloud web 页面（它居然还给我登录）查看 instances 状态，结果为：You don’t have permission to view these resources in this compartment. Try another compartment, or contact your administrator for help.

{{ image(path="instances-page.png", alt="Instances page says: You don’t have permission to view these resources in this compartment. Try another compartment, or contact your administrator for help.", caption="Instances 状态截图")}}

看来我的免费实例是彻底挂了。

## 服务重部署

选择重新部署服务到另一台机器上。

1. 清理 terraform 状态。用 `state list` 获得需要被清理的状态，然后用 `state rm` 将它们全部从 terraform 状态中删除。

   ```txt
   $ terraform state list | grep oci
   $ terraform state rm xxxxx.yyy
   ```

2. 删除 terraform 配置中所有相关的配置。
3. 更改 terraform 配置将四个服务的 CNAME 指向新的机器。
4. 更改 nixos 配置将四个服务的配置加入新机器的配置，得益于编写模块时特意使模块是机器无关的，只需要复制粘贴并引用模块即可。
5. 进行简单的 nixos 配置构建测试。
6. 部署 nixos 配置，应用 terraform 配置。
7. 测试新部署的服务，成功恢复。

得益于 terraform 和 nixos 本次重部署只花了几十分钟，commit [Oracle, Fuck You](https://github.com/linyinfeng/dotfiles/commit/153780cbfcac324c87a7fbc2e0eed4559ebc8f4f) 记录了所有的改动。

```txt
commit 153780cbfcac324c87a7fbc2e0eed4559ebc8f4f
Author: Lin Yinfeng <lin.yinfeng@outlook.com>
Date:   Fri Feb 24 10:22:01 2023 +0800

    Oracle, Fuck You

    Oracle Cloud just disabled my free account *without any notice*, and
    *does not provide any data recovery method*.

    Remove all Oracle OCI state from terraform.  Deploy all services
    previously on the Oracle Ampere A1 machine to rica.
```

## 后续（计划）

计划后续联系一下客服，问问啥情况，不过就算解封了我估计也不会去用了。
