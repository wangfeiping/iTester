# iTester

Linux iOS 应用开发调试方案

* 无需购买 Mac 主机；
* 不需要在 linux 中安装 Xcode；
* 可以反复修改代码、提交构建、下载 IPA、安装到 iPhone；
* 形成一个完整的开发测试迭代循环。

## 环境框架

```text
Ubuntu → Github → Codemagic → iPhone

Ubuntu 24.04

1. 开发

VS Code
Flutter / React Native
App 源代码

2. 代码版本管理

Git . GitHub

3. 编译，签名

Codemagic / MacinCloud （云端 macOS，部分云服务有免费额度）
Xcode · iOS SDK

4. 下载、安装、测试

iPhone 真机
USB · iloader · 安装 · 测试
```

## 步骤

```text
ChatGPT

>>> 以个人独立开发测试为目标搭建环境，尽可能减少账户注册或Apple 开发着会员等费用。

预算：0

本地：
  Flutter / VS Code    0
  普通 Apple ID         0
  Ubuntu 设备通信工具    0
  Apple Developer 年费  0
云端
  Mac                  0
```

# 基础开发环境准本

* 似乎不再需要记录细节，只记录大概的步骤，其他的问AI即可。

当前 Ubuntu 环境

系统识别正常

| 项目            | 当前版本             |
| ------------- | ---------------- |
| Ubuntu        | 26.04.1 LTS      |
| Codename      | resolute         |
| Linux Kernel  | 7.0.0-42-generic |
| CPU 架构        | x86_64           |
| Git           | 2.53.0           |

| 组件                  | 当前版本        | 判断             |
| ------------------- | ----------- | -------------- |
| Flutter             | 3.35.3      | 可以使用，建议后续升级    |
| Dart                | 3.9.2       | 与当前 Flutter 匹配 |
| VS Code             | 1.140.0     | 正常             |
| Android SDK         | API 35 / 36 | 保留             |
| Android Build Tools | 35.0.0      | 保留             |
| Java (Flutter)      | JDK 17      | 当前可用           |
| Java (Shell)        | JDK 21      | 存在版本不一致        |
| Git                 | 2.53.0      | 正常             |
| libimobiledevice    | 1.4.0       | 已安装            |
| usbmuxd             | 1.1.1       | 已安装            |

## 一、第一轮：检查已有 Flutter 和 Android 环境

### 1. 执行环境检查

### 2. 额外检查 Flutter SDK 是否存在于常见目录

## 二、第二轮：检查和安装 iPhone 通信工具

### 1. 安装 Linux 设备通信依赖

### 2. 启动 USB 通信服务

### 3. 安装 iloader

## 三、SideStore 的免费签名限制

## 四、后续完整开发操作命令

* 创建项目
* 开发或生成代码
* 编译，签名
* 安装，测试
    1. Ubuntu 下载云端构建产物。
    2. 通过 USB 将 IPA 传输到 iPhone，或在 iPhone 上通过 SideStore 导入。
    3. SideStore 使用你的 Apple ID 签名。
    4. 安装并启动 App。
    5. 测试完成后继续修改代码。

# 安装iphone app 安装工具链

很好！这说明最关键的第一阶段已经成功：Ubuntu + USB + iloader + iPhone + SideStore 安装链路全部打通，而且没有遇到签名安装错误。

现在先不要急着安装 Flutter 应用。我们先验证 SideStore 能否在 iPhone 上正常启动，以及免费 Apple ID 的 7 天续签机制是否可用。

## 第一步：在 iPhone 上完成 SideStore 初次启动

1. 打开 iPhone 的「设置」。
2. 进入「通用」→「VPN 与设备管理」。
3. 找到对应的开发者 App，点击信任。
4. 如果系统提示开启开发者模式，进入「隐私与安全性」→「开发者模式」，开启并按提示重启。
5. 回到桌面，启动 SideStore。

注意：如果已经信任并开启开发者模式，就不必重复操作。

## 第二步：安装并配置 LocalDevVPN

SideStore 需要通过本地 VPN 通道完成应用刷新。它不是普通的网络代理，不会像传统 VPN 那样把你的互联网流量转发到其他服务器。

[image](https://www.google.com/s2/favicons?domain=https://docs.sidestore.io\&sz=32)

SideStore Docs+1



1. 在 iPhone 的 App Store 搜索并安装 LocalDevVPN。
2. 打开 LocalDevVPN，点击 `Connect`。
3. 如果 iOS 弹出添加 VPN 配置的请求，选择允许。
4. 确认 iPhone 已连接 Wi-Fi。

然后打开 SideStore：

1. 使用与 iloader 登录时相同的 Apple ID 登录（注意大小写）。
2. 进入 `My Apps`。
3. 找到 SideStore 右侧的 `7 DAYS`。
4. 点击它，完成首次刷新。
5. 如果出现创建或撤销签名证书的提示，按提示选择 `Yes` 或 `Refresh Now`。

这是 SideStore 官方安装文档规定的首次初始化流程。

[image](https://www.google.com/s2/favicons?domain=https://docs.sidestore.io\&sz=32)

SideStore Docs+1



## 第三步：特别关注 iOS 27.0.1 兼容性

你的系统版本比较新。目前查到：

- SideStore 官方安装文档包含 iOS 18 及以上版本的安装流程。
- iloader 文档目前明确列出的具体流程覆盖到 iOS 26.2。
- 已有 iOS 27 用户报告过配对文件失效、SideStore 刷新异常等问题。

  [image](https://www.google.com/s2/favicons?domain=https://docs.sidestore.io\&sz=32)

  SideStore Docs+3



因此，我们以实际测试结果为准，先使用 Stable 版本，不建议切换 Nightly。

## 完成后请告诉我两个结果

1. SideStore 是否能正常打开并登录？
2. 点击 `7 DAYS` 后，是否成功刷新为 7 天？

如果失败，请把错误提示原文或截图发给我。

SideStore 成功刷新后，我们就进入下一阶段：从 Ubuntu 开发 Flutter 应用，在 Codemagic 云端编译 iOS IPA，再通过 iloader / SideStore 安装到 iPhone 真机。 这样就能基本实现不购买 Mac、不购买 Apple Developer Program 的开发测试流程。

## Error  

SideStore 无法登录，报错码：-80045

这个错误已经找到比较明确的排查方向了。`-80045` 是近期 SideStore 社区集中报告的 Apple ID 登录问题，并不意味着你的 Apple ID 密码错误，也不代表 iPhone 配对失败。

尤其是你的环境为 iOS 27.0.1、iloader 2.4.1，这与近期社区报告的故障环境非常接近。问题很可能与 SideStore 使用的 Anisette 身份认证信息或服务器配置有关。

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+2



## 1. 首先尝试社区验证过的解决方法

在 iPhone 上打开 SideStore：

Settings → User Customizations

找到以下设置：

1. `Disable On-Device Anisette`：开启。
2. 返回 Settings，进入 `Anisette Servers`。
3. 找到 `Available Servers`。
4. 选择第五个选项：`SideStore (new)`。
5. 关闭 `Enable Auto Rotation`。

然后再次进入：

Settings → User Customizations

找到 `Reset adi.pb`：

- 执行 Reset。
- 如果出现 `Keep Headers` 选项，取消勾选。
- 确认重置。

最后完全关闭 SideStore，再重新打开并尝试登录。

这套配置是 SideStore 社区在 2026 年 10 月针对 `-80045` 分享的解决方法。

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



## 2. 如果仍然失败

还有一种配置可以尝试：

进入：

`Settings → User Customizations → Anisette Client Configuration`

将 Client Info 设置为：

```
<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>
```

User Agent 设置为：

```
akd/1.0 CFNetwork/808.1.4
```

保存 Overrides，然后重新尝试登录。

这也是社区针对 `-80045` 报错提供的另一种临时解决方法。

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



## 3. 我建议暂时不要反复尝试登录

如果 Apple 返回认证错误，频繁重复登录、请求短信验证码，可能触发临时安全限制。先完成配置，再进行一次测试。

## 先确认两个信息

1\. 你安装的 SideStore 版本是多少？

2\. -80045 出现在哪个阶段？

输入账号密码后立即报错

进入双重认证时报错

输入验证码后报错

提交

我想先确认这两个信息，再决定是否需要升级 SideStore。目前不建议卸载重装，也不需要重新配对 iPhone。

# iPhone 真机更新功能测试

Ubuntu → iPhone 真机测试环境已经完成了最重要的基础验证：
项目	状态
Ubuntu USB 识别 iPhone	成功
usbmuxd / libimobiledevice	成功
iloader 2.4.1	成功
SideStore 安装	成功
Apple ID 登录	成功
7 天签名刷新	成功

这也验证了此前的 Anisette 配置调整适用于你当前这台设备。
下一阶段：验证 Flutter IPA 真机安装
我建议按照这个顺序继续：
1. 在 Ubuntu 上创建一个最小 Flutter 测试项目。
2. 将项目推送到 GitHub。
3. 配置 Codemagic，使用 macOS 云端环境编译，固定 Flutter 3.35.3 版本。
4. 执行无签名编译：
flutter build ipa --no-codesign --release


5. 下载 IPA 到 Ubuntu。
6. 使用 iloader 导入 IPA，完成免费 Apple ID 签名并安装到 iPhone。
7. 验证 App 启动、USB 日志和重新安装流程。
这里有一个重要目标： 后续日常开发全部在 Ubuntu 的 VS Code 中完成，只有 iOS 编译交给云端 macOS，不需要购买 Mac。

另外，免费签名通常有 7 天有效期，建议保留 SideStore 作为续签工具。
📱每周提醒刷新 SideStore轻点设置

下一步我建议直接开始创建 Flutter iOS 测试项目，并配置 Codemagic。

# Codemagic

默认工作流直接编译，生成Runner.app.zip 并下载。

目录结构看起来是正确的：已经出现 `Runner.app`，并且包含 Flutter 和 iOS 的资源目录。

很好！这说明 Codemagic 已经成功完成了 iOS 云端编译。`Runner.app.zip`（30.52 MB）就是我们需要的 iOS 应用构建产物，只是它目前是 `.app` 格式的压缩包，还不是可以直接导入 iloader 的 IPA。

下一步不需要重新编译。我们先把它下载到 Ubuntu，检查目录结构，再封装成 IPA。

## 1. 在 Ubuntu 下载构建产物

在 Ubuntu 终端执行：

```
mkdir -p ~/Downloads/iTester-ios
cd ~/Downloads/iTester-ios

curl -L \
  "https://api.codemagic.io/artifacts/ad115c69-f963-4f99-a8ba-700e67efd78c/3d0911d7-f8c6-427b-8844-fbbba9f41b39/Runner.app.zip" \
  -o Runner.app.zip
```

检查文件：

```
ls -lh Runner.app.zip
file Runner.app.zip
```

## 2. 解压并检查结构

```
unzip -q Runner.app.zip -d extracted

find extracted -maxdepth 3 -type d | head -30
```

我们需要确认压缩包里面是否存在：

```
Runner.app/
    Info.plist
    Runner
    Frameworks/
    ...
```

## 3. 暂时不要直接修改签名或打包

请先执行下面的检查命令：

```
find extracted -name Info.plist
```

以及：

```
find extracted -name embedded.mobileprovision
```

这两项分别用于确认：

- `Info.plist`：应用程序的基本信息，包括 Bundle Identifier。
- `embedded.mobileprovision`：是否已经包含签名配置文件。

把这三个命令的输出发给我：

```
ls -lh Runner.app.zip
find extracted -maxdepth 3 -type d | head -30
find extracted -name embedded.mobileprovision
```

## 4. 接下来的目标

1. 将 Runner.app 正确封装为 `iTester.ipa`。
2. 检查 Bundle ID 和现有签名状态。
3. 使用 iloader 重新签名。
4. 安装到 iPhone 27.0.1 并验证启动。

这里有个关键点：Codemagic 负责编译，iloader 负责免费 Apple ID 签名和安装。 我们先确认 `.app` 的实际结构，避免打包出一个无法安装的 IPA。

## 1. 先检查压缩包是否完整

请执行：

```
cd ~/Downloads/iTester-ios

echo "===== ZIP FILE ====="
file Runner.app.zip

echo "===== ZIP CONTENT ====="
unzip -l Runner.app.zip

echo "===== EXTRACTED SIZE ====="
du -sh extracted/Runner.app

echo "===== APP FILES ====="
ls -lah extracted/Runner.app | head -30
```

## 2. 检查应用签名信息

```
find extracted/Runner.app -name Info.plist
find extracted/Runner.app -name embedded.mobileprovision
```

如果存在 `Info.plist`，再执行：

```
/usr/libexec/PlistBuddy \
  -c "Print :CFBundleIdentifier" \
  extracted/Runner.app/Info.plist
```

## 3. 为什么要先检查？

正常的 Flutter iOS Release App 通常包含：

- `Runner`：应用可执行文件。
- `Frameworks/Flutter.framework`：Flutter 引擎。
- `Frameworks/App.framework`：Flutter 应用代码。
- `Info.plist`：应用配置。
- `embedded.mobileprovision`：可能存在，也可能不存在，取决于构建签名方式。

30.52 MB 是合理的构建产物大小，但 254 字节不是。

先把上述检查结果发给我，我们确认实际文件完整性后，再进行 IPA 封装和 iloader 签名，避免浪费一次安装测试。

明白了，`Runner.app.zip` 实际大小是 31,997,554 字节（约 30.52 MB），与 Codemagic 显示的大小一致。

之前看到的 254 字节应该是下载过程中尚未完成时的文件状态，或者当时查看的不是最终下载文件。现在可以继续了。

## 1. 检查解压后的 App

执行：

```
cd ~/Downloads/iTester-ios

du -sh extracted/Runner.app

ls -lh extracted/Runner.app/Runner

find extracted/Runner.app -name Info.plist
find extracted/Runner.app -name embedded.mobileprovision
```

## 2. 获取 Bundle ID

```
/usr/libexec/PlistBuddy \
  -c "Print :CFBundleIdentifier" \
  extracted/Runner.app/Info.plist
```

## 3. 检查签名状态

Ubuntu 暂时没有 macOS 的 `codesign` 工具，可以先检查签名目录：

```
ls -ld extracted/Runner.app/_CodeSignature 2>/dev/null || echo "No _CodeSignature"
```

把这几个命令的输出发给我。

接下来我们就可以：

1. 将 `Runner.app` 封装为标准 IPA。
2. 使用 iloader 导入。
3. 通过免费 Apple ID 重新签名。
4. 安装到 iPhone 并验证 Flutter 应用是否启动。

目前不需要重新进行 Codemagic 编译。

这是正常的。`/usr/libexec/PlistBuddy` 是 macOS 上的工具，Ubuntu 没有这个命令。我们可以直接使用 Python 自带的 `plistlib` 读取 iOS 的 `Info.plist`，不需要额外安装软件。

另外，当前解压后的 `Runner.app` 为 96 MB，而 ZIP 为约 30.52 MB，说明资源经过压缩，大小差异本身没有问题。

## 1. 在 Ubuntu 读取 Bundle ID

执行：

```
cd ~/Downloads/iTester-ios

python3 - <<'PY'
import plistlib

path = "extracted/Runner.app/Info.plist"

with open(path, "rb") as f:
    info = plistlib.load(f)

for key in [
    "CFBundleIdentifier",
    "CFBundleName",
    "CFBundleExecutable",
    "CFBundleVersion",
    "CFBundleShortVersionString"
]:
    print(f"{key}: {info.get(key)}")
PY
```

## 2. 检查 App 是否包含签名

执行：

```
ls -ld extracted/Runner.app/_CodeSignature 2>/dev/null \
  || echo "No _CodeSignature"

find extracted/Runner.app -name embedded.mobileprovision
```

没有 `embedded.mobileprovision` 是符合我们预期的：这次是云端无签名构建，后续交给 iloader 处理。

## 3. 封装成标准 IPA

如果前面的检查没有发现异常，执行：

```
cd ~/Downloads/iTester-ios

mkdir -p Payload

cp -a extracted/Runner.app Payload/

zip -qry iTester.ipa Payload

unzip -t iTester.ipa
ls -lh iTester.ipa
```

标准 IPA 结构应该是：

```
iTester.ipa
└── Payload/
    └── Runner.app/
        ├── Info.plist
        ├── Runner
        └── Frameworks/
```

## 4. 使用 iloader 安装

打开 Ubuntu 上的 iloader：

1. 选择你的 iPhone。
2. 找到导入 IPA 或 Install IPA 功能。
3. 选择 `~/Downloads/iTester-ios/iTester.ipa`。
4. 按提示使用已经验证成功的 Apple ID 签名。
5. 等待安装完成。

先把第 1 步读取到的 Bundle ID 发给我。 我们还需要确认它是否与你之前使用的 App ID 冲突，再进行正式签名安装。

# 安装

很好，检查结果符合预期。你的 `Runner.app` 是一个未签名的 Flutter iOS 应用，可以进入 IPA 封装阶段。

目前确认的信息：

| 项目                         | 结果                        |
| -------------------------- | ------------------------- |
| Bundle ID                  | `com.wangfeiping.itester` |
| App 名称                     | `itester`                 |
| Executable                 | `Runner`                  |
| App 版本                     | `1.0.0`                   |
| Build Number               | `1`                       |
| `_CodeSignature`           | 不存在                       |
| `embedded.mobileprovision` | 不存在                       |

这正是我们希望得到的云端无签名构建产物。

## 1. 封装标准 IPA

在 Ubuntu 执行：

```
cd ~/Downloads/iTester-ios

mkdir -p Payload
cp -a extracted/Runner.app Payload/

zip -qry iTester.ipa Payload

unzip -t iTester.ipa
ls -lh iTester.ipa
```

检查 IPA 内部结构：

```
unzip -l iTester.ipa | head -30
```

应该以 `Payload/Runner.app/` 开头。

## 2. 使用 iloader 导入 IPA

打开 iloader，连接已经配对的 iPhone：

1. 选择你的 iPhone。
2. 找到 `Import IPA` 或类似的 IPA 安装入口。
3. 选择：

```
/home/mil2er/Downloads/iTester-ios/iTester.ipa
```

4. 使用之前已经验证成功的 Apple ID。
5. 等待 iloader 完成签名和安装。

注意：Bundle ID 是 `com.wangfeiping.itester`。如果 iloader 提示 App ID 已存在，先不要删除证书或修改 Bundle ID，把提示发给我。

## 3. 安装成功后的验证

在 iPhone 桌面找到 `itester`，尝试启动。

如果无法启动，我们再检查设备日志和签名状态。

下一步请先完成 IPA 封装和 iloader 导入。 这次测试成功后，你就已经打通了从 Ubuntu Flutter 开发到 iPhone 真机运行的完整链路。
