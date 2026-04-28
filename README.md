# mpv-config

这是一个面向个人 dotfiles 的 mpv 配置仓库。根目录里的
`mpv.conf`、`input.conf`、`fonts.conf` 仍然保留给当前 Windows
便携版 mpv 使用；跨平台安装使用 `base/`、`platform/` 和安装脚本。

## 目录结构

```text
base/
  mpv.conf          # 通用 mpv 设置
  input.conf        # 通用快捷键
platform/
  windows/
    mpv.conf        # Windows 专有设置，例如 gpu-api=d3d11
    fonts.conf      # Windows portable fontconfig
  linux/
    mpv.conf        # Linux 专有设置，当前保持为空层
setup.ps1           # PowerShell 安装脚本
setup.sh            # Bash 安装脚本
```

安装脚本不会简单用 `platform/<name>/mpv.conf` 覆盖公共配置。它会把
`base/mpv.conf` 和 `platform/<name>/mpv.conf` 追加合成为最终的
`mpv.conf`，`input.conf` 也使用同样的规则。

## 安装

Linux:

```bash
bash setup.sh --force
```

默认安装到 `${XDG_CONFIG_HOME:-$HOME/.config}/mpv`。

Windows PowerShell:

```powershell
.\setup.ps1 -Force
```

默认安装到 `%APPDATA%\mpv`。如果你想安装到当前便携版目录，可以显式传入：

```powershell
.\setup.ps1 -Platform windows -Dest . -Force
```

安装前预览：

```bash
bash setup.sh --dry-run
```

```powershell
.\setup.ps1 -DryRun
```

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-layout.ps1
```

验证会检查：

- 根目录便携版配置仍保留 Windows 专用设置。
- `base/` 不包含 Windows 专用 `gpu-api=d3d11`。
- Windows 安装结果包含公共配置和 Windows 差异层。
- Linux 安装结果包含公共配置，但不会带入 Direct3D 设置或 Windows `fonts.conf`。
