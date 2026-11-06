# LiveTalking

完整的 LiveTalking + AMD ROCm 7.2.1 + Docker 部署手册，从宿主机准备、启动 Docker、下载源码、安装依赖、下载模型、准备数字人 Avatar，到启动 WebRTC 服务，全部按顺序执行。

这次特别注意以下几点：

1. 保留已经验证成功的 ROCm 7.2.1、PyTorch 2.9.1。
2. 使用你之前确认的两个 MIOpen 环境变量，不修改名称。
3. 不安装 CUDA 版本的 PyTorch。
4. 模型、代码和数据全部持久化到宿主机。
5. 第一阶段先使用 Wav2Lip 跑通完整实时视频链路，再考虑 MuseTalk。

# 一、最终部署结构

Ubuntu 24.04.5 + AMD MS-S1 Max 395

gfx1151 · AMD GPU

Docker：digital-human

ROCm 7.2.1 · PyTorch 2.9.1

LiveTalking

- Wav2Lip 推理
- 人脸检测
- 音频驱动口型
- WebRTC 音视频服务

浏览器客户端

摄像头 / 麦克风 / 实时数字人

宿主机目录规划：

```
/opt/livetalking/
├── repo/                  # LiveTalking 源码
├── models/                # 模型文件
├── data/
│   └── avatars/           # 数字人 Avatar
└── logs/                  # 日志
```

# 二、宿主机准备

以下命令都在 Ubuntu 宿主机执行，不是在 Docker 容器内执行。

## 2.1 检查 GPU 设备

```
ls -l /dev/kfd
ls -l /dev/dri/
```

应该能看到：

```
/dev/kfd
/dev/dri/renderD128
```

检查 Docker：

```
docker --version
docker info | grep -i "Server Version"
```

## 2.2 创建目录

```
sudo mkdir -p /opt/livetalking/{repo,models,data/avatars,downloads,logs}

sudo chown -R $USER:$USER /opt/livetalking
```

目录作用：

| 目录           | 用途             |
| ------------ | -------------- |
| repo         | LiveTalking 源码 |
| models       | Wav2Lip 权重     |
| data/avatars | 数字人素材          |
| downloads    | 下载的原始模型文件      |
| logs         | 服务运行日志         |

## 2.3 下载 LiveTalking 源码

```
cd /opt/livetalking

git clone https://github.com/lipku/LiveTalking.git repo
```

如果之前已经克隆过，不要重复执行，直接进入：

```
cd /opt/livetalking/repo

git status
```

建议先使用官方 main 分支，不要同时修改多个版本。

# 三、启动 ROCm Docker

## 3.1 下载基础镜像

```
docker pull rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1
```

## 3.2 设置 AMD GPU 权限

在宿主机执行：

```
getent group render
getent group video
```

记录 `render` 的组 ID。下面使用变量自动获取：

```
RENDER_GID=$(getent group render | cut -d: -f3)

echo "RENDER_GID=$RENDER_GID"
```

如果没有获取到组 ID，先不要启动容器。

## 3.3 启动容器

之前的 `digital-human` 容器如果只是测试用的空容器，可以删除后重建：

```
docker rm -f digital-human 2>/dev/null || true
```

执行启动命令：

```
docker run -d \
  --name digital-human \
  --restart unless-stopped \
  --network host \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  --group-add="$RENDER_GID" \
  --ipc=host \
  -p 8010:8010 \
  -p 7880:7880 \
  -p 7881:7881 \
  -e MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F2X3=0 \
  -e MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F3X2=0 \
  -e HF_HOME=/root/.cache/huggingface \
  -v ~/digital-human/workspace:/workspace \
  -v ~/digital-human/models:/models \
  -v ~/digital-human/cache:/root/.cache \
  -v /opt/livetalking:/workspace/LiveTalking \
  rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1 \
  sleep infinity
```

这里有一个重要的调整：使用 `--network host`，而不是 Docker 默认 bridge 网络。

原因是 LiveTalking 使用 WebRTC，需要 UDP 通信。Host 网络可以避免 Docker 动态 UDP 端口映射带来的额外复杂度。

同时，保留你确认的两个环境变量：

```
MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F2X3=0
MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F3X2=0
```

这次不再修改。

## 3.4 检查容器状态

```
docker ps
```

进入容器：

```
docker exec -it digital-human bash
```

检查环境变量：

```
env | grep MIOPEN_DEBUG
```

预期：

```
MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F2X3=0
MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F3X2=0
```

## 3.5 检查 PyTorch

容器内执行：

```
python - <<'PY'
import torch

print("PyTorch:", torch.__version__)
print("HIP:", torch.version.hip)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))

    x = torch.randn(1, 3, 256, 256, device="cuda")
    conv = torch.nn.Conv2d(3, 16, 3).cuda()

    y = conv(x)
    torch.cuda.synchronize()

    print("Conv2d:", y.shape)
    print("GPU TEST: PASS")
PY
```

必须先确认 GPU TEST: PASS，再继续安装。

# 四、安装 LiveTalking 运行依赖

仍然在 Docker 容器内执行。

## 4.1 安装 Ubuntu 依赖

```
apt update

apt install -y \
  git \
  wget \
  curl \
  ffmpeg \
  libgl1 \
  libglib2.0-0 \
  libsm6 \
  libxext6 \
  libxrender1 \
  libgomp1 \
  build-essential \
  pkg-config
```

## 4.2 进入源码目录

```
cd /workspace/LiveTalking/repo
```

检查目录：

```
ls
```

应该可以看到：

```
app.py
requirements.txt
models/
data/
wav2lip/
```

## 4.3 安装 Python 依赖

先更新 pip：

```
python -m pip install --upgrade pip setuptools wheel
```

然后安装官方依赖：

```
python -m pip install -r requirements.txt
```

特别注意：不要执行以下 CUDA 安装命令：

```
pip install torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu128
```

LiveTalking 官方 README 的安装示例是 CUDA 12.8 环境，而我们使用的是 AMD ROCm 环境。官方 requirements.txt 本身没有要求安装 CUDA 版 PyTorch，所以只安装项目依赖即可。

[image](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com\&sz=32)

GitHub+1



## 4.4 验证 Python 依赖

```
python - <<'PY'
import torch
import cv2
import numpy
import scipy
import librosa
import transformers
import diffusers
import aiortc
import flask

print("Torch:", torch.__version__)
print("HIP:", torch.version.hip)
print("GPU:", torch.cuda.is_available())
print("OpenCV:", cv2.__version__)
print("NumPy:", numpy.__version__)
print("SciPy:", scipy.__version__)
print("Librosa:", librosa.__version__)
print("Transformers:", transformers.__version__)
print("Diffusers:", diffusers.__version__)
print("aiortc:", aiortc.__version__)

assert torch.__version__.startswith("2.9.1")
assert torch.cuda.is_available()

print("DEPENDENCY TEST: PASS")
PY
```

如果这里报错，先不要继续下载模型，优先解决依赖兼容问题。

# 五、下载 Wav2Lip 模型

这是本次部署的重要环节。

官方提供了两个模型下载渠道：

[夸克网盘 - Windows官方下载 | 微软应用商店 | Microsoft Store](https://images.openai.com/static-rsc-4/Cvl4HvVmP6i8Vq9ChjFCIwu3QUcUGS89zP8K3bwYzbS59Qu0MJrNoIPmsbwNV7_X9uZZFAcJnn3woKkbOi_71jPMw0sn2KVl6Yp5zw0nX2QwT7uOiSut-bJEg8S7-XMyIAfnw6lnwwI9LOPHgMBokBmYYMGpH_xEV7bBT-7pJXg?purpose=inline)

夸克网盘

官方推荐模型资源

[打开模型下载页面](https://pan.quark.cn/s/83a750323ef0?utm_source=chatgpt.com)

[Google Drive: Login – hier geht's zur Google-Cloud](https://images.openai.com/static-rsc-4/uxJtLmRxmrL2VqEqQn0BU2HaRIWxgCaUM9jPlheFD478w2RyU7PNiFJx-Gl-NV6gmSoUIGLtOtXqImgw4iODFMvfnU-Lt2eP0CzmxPxfmsnnNb_XEWLS_LO9VydbIWJRCvDm9rImZcnLzyMhnuDr-jdqjPyGHdWQxIHsz_vFkLs?purpose=inline)

Google Drive

官方备用下载渠道

[打开 Google Drive](https://drive.google.com/drive/folders/1FOC_MD6wdogyyX_7V1d4NDIO7P9NlSAJ?utm_source=chatgpt.com)

官方 Wav2Lip 使用说明要求准备以下三个文件。

[image](https://www.google.com/s2/favicons?domain=https://doc.livetalking.ai\&sz=32)

LiveTalking+1



## 5.1 需要下载的文件

| 文件名                         | 用途             |
| --------------------------- | -------------- |
| `wav2lip256.pth`            | Wav2Lip 口型生成模型 |
| `s3fd.pth`                  | 人脸检测模型         |
| `wav2lip256_avatar1.tar.gz` | 预处理后的数字人素材     |

建议全部下载到宿主机：

```
/opt/livetalking/downloads/
```

下载完成后：

```
ls -lh /opt/livetalking/downloads/
```

## 5.2 安装 Wav2Lip 主模型

宿主机执行：

```
cp /opt/livetalking/downloads/wav2lip256.pth \
   /opt/livetalking/models/wav2lip.pth
```

注意文件名需要从：

```
wav2lip256.pth
```

改成：

```
wav2lip.pth
```

## 5.3 安装人脸检测模型

宿主机执行：

```
mkdir -p /opt/livetalking/repo/wav2lip/face_detection/detection/sfd
```

复制模型：

```
cp /opt/livetalking/downloads/s3fd.pth \
   /opt/livetalking/repo/wav2lip/face_detection/detection/sfd/s3fd.pth
```

## 5.4 解压 Avatar 数字人素材

执行：

```
mkdir -p /opt/livetalking/repo/data/avatars
```

查看压缩包内容：

```
tar -tzf /opt/livetalking/downloads/wav2lip256_avatar1.tar.gz | head -30
```

解压：

```
tar -xzf /opt/livetalking/downloads/wav2lip256_avatar1.tar.gz \
  -C /opt/livetalking/repo/data/avatars/
```

检查：

```
find /opt/livetalking/repo/data/avatars \
  -maxdepth 3 -type f | head -30
```

最终需要保证目录中能够找到：

```
data/avatars/wav2lip256_avatar1/
```

如果压缩包解压后出现额外嵌套目录，需要调整目录层级，使 Avatar 文件夹直接位于 `data/avatars/` 下面。

## 5.5 检查三个模型是否齐全

```
ls -lh /opt/livetalking/models/wav2lip.pth

ls -lh /opt/livetalking/repo/wav2lip/face_detection/detection/sfd/s3fd.pth

ls -lah /opt/livetalking/repo/data/avatars/wav2lip256_avatar1/
```

三个位置都正确，才进入下一阶段。

注意：模型目录有一个路径需要统一。 LiveTalking 实际读取的是源码目录下的 `models/`，因此主模型应该放在：

```
/opt/livetalking/repo/models/wav2lip.pth
```

而不是 `/opt/livetalking/models/`。请按下面修正后的命令操作：

```
mkdir -p /opt/livetalking/repo/models

cp /opt/livetalking/downloads/wav2lip256.pth \
   /opt/livetalking/repo/models/wav2lip.pth
```

之前创建的 `/opt/livetalking/models` 可以暂时保留，不影响运行。

# 六、启动 LiveTalking 服务

模型和依赖准备完成后，回到 Docker 容器。

## 6.1 进入容器

宿主机执行：

```
docker exec -it digital-human bash
```

进入源码目录：

```
cd /workspace/LiveTalking/repo
```

检查模型：

```
ls -lh models/wav2lip.pth

ls -lh wav2lip/face_detection/detection/sfd/s3fd.pth

ls -lah data/avatars/wav2lip256_avatar1/
```

## 6.2 启动 Wav2Lip

执行官方启动命令：

```
python app.py \
  --transport webrtc \
  --model wav2lip \
  --avatar_id wav2lip256_avatar1
```

参数解释：

| 参数                               | 作用              |
| -------------------------------- | --------------- |
| `--transport webrtc`             | 使用 WebRTC 传输    |
| `--model wav2lip`                | 使用 Wav2Lip 口型模型 |
| `--avatar_id wav2lip256_avatar1` | 指定数字人素材         |

首次启动时，重点观察是否出现：

- 模型加载成功
- 人脸检测模型加载成功
- Avatar 加载成功
- Flask 服务监听 8010
- WebRTC 初始化成功

如果出现 Python Traceback，先不要反复重启，把完整错误发给我。

## 6.3 浏览器访问

在宿主机执行：

```
ip -4 route get 1.1.1.1
```

找到输出中的 `src` 后面的 IP 地址。

例如：

```
src 192.168.1.100
```

浏览器访问：

```
http://192.168.1.100:8010/index.html
```

也可以直接在服务器本机访问：

```
http://127.0.0.1:8010/index.html
```

页面打开后：

1. 点击 Start 或开始连接。
2. 等待 WebRTC 建立连接。
3. 确认数字人视频正常显示。
4. 在文本输入框输入一段文字。
5. 提交，观察数字人是否同步说话。

官方快速启动说明也是通过 TCP 8010 页面访问，并通过文本驱动数字人。

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



# 七、网络和防火墙配置

由于我们采用了 `--network host`，不需要额外配置 Docker 端口映射。

LiveTalking 默认使用：

| 协议  | 端口          | 用途               |
| --- | ----------- | ---------------- |
| TCP | 8010        | Web 页面及 HTTP API |
| UDP | WebRTC 动态端口 | 音视频传输            |

先检查 UFW：

```
sudo ufw status
```

如果防火墙启用，至少允许：

```
sudo ufw allow 8010/tcp
```

官方文档提到 WebRTC 服务需要 UDP 通信，文档给出的开放范围为 UDP 1–65536（实际有效端口最大为 65535）。

[image](https://www.google.com/s2/favicons?domain=https://doc.livetalking.ai\&sz=32)

LiveTalking+1



我的建议是先在同一个局域网内测试，不要直接向公网开放全部 UDP 端口。如果需要外网访问，再根据 NAT、实际 ICE 候选地址和 TURN 中继需求配置网络。

# 八、后台运行和日志管理

确认前台运行正常后，再改为后台运行。

先在容器内按 `Ctrl+C` 停止前台服务。

退出容器：

```
exit
```

宿主机执行：

```
docker exec -d digital-human bash -lc \
  'cd /workspace/LiveTalking/repo && python app.py --transport webrtc --model wav2lip --avatar_id wav2lip256_avatar1 >> /workspace/LiveTalking/logs/livetalking.log 2>&1'
```

查看日志：

```
tail -f /opt/livetalking/logs/livetalking.log
```

查看容器：

```
docker ps
```

停止数字人服务（不停止容器）：

```
docker exec digital-human pkill -f 'python app.py'
```

停止整个容器：

```
docker stop digital-human
```

重新启动容器：

```
docker start digital-human
```

由于容器配置了 `sleep infinity`，容器重启后不会自动启动 Python 服务。后续我们可以再增加 systemd 服务，实现完整的开机自动启动。

# 九、部署完成后的验证清单

建议按下面顺序逐项确认：

部署检查进度

# 0/11

Docker 容器正常运行

ROCm 7.2.1 正常识别 AMD GPU

PyTorch 2.9.1 GPU 运算成功

两个 MIOpen 环境变量正确

LiveTalking Python 依赖安装成功

wav2lip.pth 主模型加载成功

s3fd.pth 人脸检测模型加载成功

Avatar 素材加载成功

TCP 8010 页面可以访问

WebRTC 视频连接成功

文本驱动数字人说话成功

## 十、常见问题排查

| 现象                                  | 优先检查                   |
| ----------------------------------- | ---------------------- |
| `torch.cuda.is_available() = False` | ROCm 设备映射及容器环境         |
| `invalid device function`           | PyTorch 是否仍然支持 gfx1151 |
| `MIOpen` 算法报错                       | 两个环境变量是否正确             |
| 找不到 `wav2lip.pth`                   | 模型目录及文件名称              |
| 找不到 `s3fd.pth`                      | 人脸检测模型存放路径             |
| Avatar 加载失败                         | 解压后的目录层级               |
| 网页能打开但没有视频                          | WebRTC UDP、ICE 和网络配置   |
| 有视频但不能说话                            | TTS 服务及其网络连接           |

## 十一、官方资源

- [LiveTalking GitHub 源码](https://github.com/lipku/LiveTalking?utm_source=chatgpt.com)
- [官方快速启动文档](https://doc.livetalking.ai/docs/quickstart/?utm_source=chatgpt.com)
- [模型与传输配置说明](https://doc.livetalking.ai/docs/usage/?utm_source=chatgpt.com)
- [API 文档](https://doc.livetalking.ai/docs/api/?utm_source=chatgpt.com)

## 十二、下一步：性能优化

我建议先不急于安装 MuseTalk。

先在 AMD MS-S1 Max 395 上跑通 Wav2Lip，重点采集三个指标：

1. `inferfps`：GPU 口型推理帧率。
2. `finalfps`：最终视频输出帧率。
3. 音频到视频的实际延迟。

官方以 `inferfps` 和 `finalfps` 均达到 25 FPS 作为实时运行参考。

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub



之后再考虑：

- MuseTalk 高质量口型模型。
- 云端 TTS 实时语音输入。
- Pipecat 实时音视频对话。
- ZeroClaw / OpenClaw Agent 控制数字人。

我建议你现在先执行到第四部分（Python 依赖安装），暂时不要急着下载模型。

把下面这条命令的输出发给我：

```
python -c "import torch, cv2, aiortc, diffusers; print('Torch:',torch.__version__); print('HIP:',torch.version.hip); print('GPU:',torch.cuda.is_available()); print('GPU Name:',torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')"
```

我会先确认 AMD GPU 和 LiveTalking 依赖没有冲突，再继续模型部署。这样可以避免花时间下载模型后才发现底层环境存在问题。

后续还可以增加容器异常和推理帧率监控：

🖥️监控 LiveTalking 运行状态轻点设置
