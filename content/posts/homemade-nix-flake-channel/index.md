+++
title = "土制 Nix Flake Channel"
# description = ""
date = 2026-01-24 17:10:00+08:00
updated = 2026-01-24 17:10:00+08:00
author = "Yinfeng"
draft = false
[taxonomies]
categories = ["笔记", "运维日志"]
tags = ["Nix", "Hydra"]
[extra]
license_image = "license-buttons/l/by-nc-sa/4.0/88x31.png"
license_image_alt = "CC BY-NC-SA 4.0"
license = "This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/)"
thumbnail = "hydra-and-flakes.png"
+++

这是 Nix 土制系列的第二篇文章，继[土制 Nix S3 Binary Cache](@/posts/homemade-nix-s3-cache/index.md)之后，继续介绍我的 Nix channel 方案。即使是 all-in flake 的用法，channel 这个概念仍然非常有用，甚至在某些场景下更重要了，因为它表明了可用性。

<!-- more -->

{{ image(path="hydra-and-flakes.png", alt="一条 hydra 正在构建 flakes", caption="Hydra 构建 flakes 的珍贵影像（由 Nano Banana Pro 生成）") }}

## 问题

我的所有设施都是自动更新的，因为我不希望为“更新”这件事投入精力。我希望我能做到：

1. 只在机器的配置损坏时才需要干预；
2. 即使一台机器的配置损坏，也不影响其他机器的自动更新，也就是说我可以任意决定损坏后多久才干预；
3. 如果是上游导致的损坏，即使我不干预，只要上游完成了修复，一段时间后也能通过自动更新，自动恢复正常。

这几点使得我平时无须在意任何更新相关的事情，只有出问题时才需要看一看，并且即使出现问题，我也可以拖着不修，甚至一段时间后可能自愈。

满足这几点的自动更新配置可能如下：

1. 通过 GitHub Actions 定期更新 flake 的 lock file；
2. 通过 Hydra 定期构建机器的配置，并且在成功后自动部署。

但是 2 对我来说不现实，因为我的服务器遍布全球，hydra 机器在国内，链接到各地服务器不稳定。我更希望服务器自己从 cache 拉取更新，而不是 hydra 主动部署更新。

通常情况下，这可能意味着需要这样配置：

```nix
{
  system.autoUpgrade = {
    enable = true;
    flake = "github:linyinfeng/dotfiles";
    allowReboot = true;
    dates = "04:00";
    randomizedDelaySec = "30min";
  };
}
```

但是这样做的问题是，服务器如何知道自己的配置在 hydra 上是否构建成功呢？如果没有，服务器就会去构建一个必定构建失败的配置，非常不合理。

如果能为每个服务器做一个更新用的 channel 的话，问题就可以得到解决。

对于每一个服务器，都有一个 branch `nixos-tested-${hostName}`，一旦 hydra 构建成功某个配置，就把 branch 向前设置到这个配置的 commit。
每晚服务器都自动更新到这个 branch，这样就能保证它只会更新到 hydra 构建成功（所以有 cache）的配置。

```nix
{ config, ... }:
let
  inherit (config.networking) hostName;
in
{
  system.autoUpgrade = {
    # ...
    flake = "github:linyinfeng/dotfiles/nixos-tested-${hostName}";
    # ...
  };
}
```

## 实现

代码可以在[这里](https://github.com/linyinfeng/dotfiles/blob/214c35a60579d5fb2f33307a320e7d09f765aa5a/nixos/profiles/services/hydra/_channel.nix)找到。

Hydra 有一个插件叫作 `RunCommand`，Hydra 的[文档](https://nixos.org/hydra/manual/)有单独一节介绍了这个插件。

该插件支持静态和动态两种配置，静态命令配置在 Hydra 配置中，而动态命令可以在特定的 Hydra job 构建完成后，调用构建产物。

因为我需要对所有的 job 都上传 cache，并对部分 job 做 channel 更新，所以我选择了静态命令。

```nix
services.hydra.extraConfig = lib.mkAfter ''
  <runcommand>
    command = "${lib.getExe hydraHook}"
  </runcommand>
'';
```

命令定义在 `hydraHook` 中,.定义如下：

```nix
hydraHook = pkgs.writeShellApplication {
  name = "hydra-hook";
  runtimeInputs = with pkgs; [
    jq
    systemd
    getFlakeCommit
    channelUpdate
  ];
  text = ''
    echo "--- begin event ---"
    cat "$HYDRA_JSON" | jq
    echo "--- end event ---"

    # ...
  '';
};
```

其中省略部分在后面介绍。这个命令分为几部分，我们一步步来看。

首先 Hydra 会将事件信息以 JSON 格式传递给命令，存储在 `$HYDRA_JSON` 文件中。首先把这个文件打印出来，方便调试。

然后判断这是否是一个构建成功的事件，如果不是，就退出。

```bash
if [ "$(jq '.event == "buildFinished" and .buildStatus == 0' "$HYDRA_JSON")"  != "true" ]; then
  echo "not a successful buildFinished event, exit."
  exit 0
fi
```

如果构建成功，就将构建好的包上传到我的[土制 Nix S3 Binary Cache](@/posts/homemade-nix-s3-cache/index.md)中，我将上传逻辑包装在了一个 `copy-cache-li7g-com@.service` 服务中，所以脚本中是对每一个输出调用 `systemctl start`。

```bash
echo "copying outputs to cache..."
jq --raw-output '.outputs[].path' "$HYDRA_JSON" | while read -r out; do
  echo "copying to cache: $out..."
  systemctl start "copy-cache-li7g-com@$(systemd-escape "$out").service"
  echo "done."
done
```

Hydra 的权限不能调用 `systemctl`，添加 polkit 规则允许 Hydra 用户调用这个服务（不要使用 sudo）：

```nix
security.polkit.extraConfig = ''
  polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        RegExp('copy-cache-li7g-com@.+\.service').test(action.lookup("unit")) === true &&
        subject.isInGroup("hydra")) {
      return polkit.Result.YES;
    }
  });
'';
```

接下来判断这个 job 需不需要更新 channel。在我的 [dotfiles](https://github.com/linyinfeng/dotfiles) 中，凡是以 `nixos-` 开头的 `hydraJobs` 都需要更新 channel。

```bash
if [ "$(jq --from-file "${dotfilesChannelJobFilter}" "$HYDRA_JSON")" = "true" ]; then
  echo "dotfiles channel job detected, update channel..."
  host="$(jq --raw-output '.job | capture("^nixos-(?<host>[^/]*)\\.(.*)$").host' "$HYDRA_JSON")"
  branch="nixos-tested-$host"
  commit="$(get-flake-commit)"
  channel-update "linyinfeng" "dotfiles" "$branch" "$commit"
fi
```

其中 `jq` 的参数 `dotfilesChannelJobFilter` 因为内容太复杂了，如果写在 bash 里又需要考虑多一层的 escape，所以定义到单独文件中了：

```nix
dotfilesChannelJobFilter = pkgs.writeTextFile {
  name = "nixos-job-filter.jq";
  text = ''
    .project == "dotfiles" and
    .jobset == "main" and
    (.job | test("^nixos-([^/]*)\\.(.*)$"))
  '';
};
```

意思就是判断 job 是否是 `dotfiles:main:nixos-<host>.<system>` 这种格式。

随后，还是利用 `jq` 从 job 名称中提取出 host 名称，构造 branch 名称 `nixos-tested-<host>`。并调用另一个脚本 `get-flake-commit` 获得 flake 的 commit，这个信息 `$HYDRA_JSON` 中没有，得从 hydra 的数据库中查询：

```nix
getFlakeCommit = pkgs.writeShellApplication {
  name = "get-flake-commit";
  runtimeInputs = with pkgs; [
    jq
    postgresql
    ripgrep
  ];
  text = ''
    build_id=$(jq '.build' "$HYDRA_JSON")
    flake_url=$(psql --tuples-only --username=hydra --dbname=hydra --command="
        SELECT flake FROM jobsetevals
        WHERE id = (SELECT eval FROM jobsetevalmembers
                    WHERE build = $build_id
                    LIMIT 1)
        ORDER BY id DESC
        LIMIT 1
      ")
    echo "$flake_url" | rg --only-matching '/(\w{40})(\?.*)?$' --replace '$1'
  '';
};
```

（这个脚本的最后一步从 `$flake_url` 匹配出 commit hash 我随手调了个 ripgrep，直接用 bash 也完全可以。）

最后调用 `channel-update` 脚本做分支的更新：

```nix
channelUpdate = pkgs.writeShellApplication {
  name = "channel-update";
  runtimeInputs = with pkgs; [
    jq
    git
    util-linux
  ];
  text = ''
    owner="$1"
    repo="$2"
    branch="$3"
    commit="$4"
    token=$(cat "$CREDENTIALS_DIRECTORY/github-token")

    echo "updating $owner/$repo/$branch to $commit..."

    cd /var/tmp
    mkdir --parents "hydra-channel-update/$owner/$repo"
    cd "hydra-channel-update/$owner/$repo"

    (
      echo "waiting for repository lock..."
      flock 200
      echo "enter critical section"

      if [ ! -d "repo.git" ]; then
        git clone "https://github.com/$owner/$repo.git" --filter=tree:0 --bare repo.git
      fi

      function repo-git {
        git -C repo.git "$@"
      }

      repo-git remote set-url origin "https://-:$token@github.com/$owner/$repo.git"
      repo-git fetch --all
      if repo-git merge-base --is-ancestor "$commit" "$branch"; then
        echo "commit $commit is already in branch $branch, skip."
        exit 0
      fi
      repo-git push origin "$commit:$branch"

      echo "leave critical section"
    ) 200>lock
  '';
};
```

这个脚本会做这么几件事：

1. 确保在 `/var/tmp/hydra-channel-update/<owner>/<repo>/repo.git` 是目标仓库的 bare clone；
2. 设置 GitHub token 确保 push 权限；
3. 对仓库进行 `fetch --all`，这里不 fetch 具体分支是因为目标分支可能不存在，懒得写错误处理；
4. 判断 commit 是否已经在分支上了（并且分支存在），如果是就跳过；
5. 否则就把 commit push 到目标分支。

极端条件下，有可能会发生竞态条件，导致部分脚本运行失败，所以用 `flock` 做了锁，确保同一时间只有一个脚本在操作这个仓库。

Token 通过 systemd 的 `LoadCredential` 功能提供，并通过 sops-nix 分发到目标主机上：

```nix
systemd.services.hydra-notify.serviceConfig.LoadCredential = [
  "github-token:${config.sops.secrets."github_token_nano".path}"
];
```

## 结语

整件事情还是挺简单的，唯一比较 tricky 的地方是 flake commit 得从 hydra 的数据库中查出来。不过整体来说，复杂度还在 bash 脚本可接受的范围内。

另外从这个例子就可以看出 Nix 打包的便捷性，只要有需要，就可以用几行代码随手打成包，比如 `dotfilesChannelJobFilter`；此外用 Nix 的 `writeShellApplication` 来打包一些 bash 脚本的能力是非常方便且强大的，Nix 能极其容易地描述 bash 脚本对外部程序的依赖，以及 bash 脚本之间的依赖。总结就是，把 bash 带到了不属于它的高度（大雾
