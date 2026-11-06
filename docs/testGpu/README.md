

```shell
docker pull rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1

docker run -it \
  --name digital-human \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  -e MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F2X3=0 \
  -e MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F3X2=0 \
  rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1 \
  bash
```

```shell
#workspace LiveTalking、MuseTalk 等源码
#models    数字人模型权重
#cache     HuggingFace 等模型缓存
mkdir -p ~/digital-human/{workspace,models,cache}

docker run -it \
  --name digital-human \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
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
  rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1 \
  bash

docker start -ai digital-human
#or
docker exec -it digital-human bash
```

```shell
cat > docker_test.py <<'EOF'

import torch
import torch.nn as nn
import torch.nn.functional as F
import time

device = "cuda"

print("GPU:", torch.cuda.get_device_name(0))

# 1. CNN convolution
model = nn.Sequential(
    nn.Conv2d(3, 32, 3, padding=1),
    nn.ReLU(),
    nn.Conv2d(32, 64, 3, padding=1),
    nn.ReLU(),
).to(device).half()

x = torch.randn(1, 3, 256, 256, device=device).half()

# 2. Interpolation
y = F.interpolate(x, size=(128, 128), mode="bilinear",
                  align_corners=False)

# 3. CNN inference benchmark
for _ in range(5):
    out = model(x)

torch.cuda.synchronize()
start = time.time()

for _ in range(100):
    out = model(x)

torch.cuda.synchronize()
elapsed = time.time() - start

print("CNN output:", out.shape)
print("Interpolation:", y.shape)
print("CNN average time:", round(elapsed * 1000 / 100, 2), "ms")
print("CNN FPS:", round(100 / elapsed, 2))

# 4. Audio-like tensor operations
audio_features = torch.randn(
    1, 80, 200,
    device=device,
    dtype=torch.float16
)

linear = nn.Linear(200, 256).to(device).half()
result = linear(audio_features)

torch.cuda.synchronize()

print("Audio feature test:", result.shape)
print("All tests completed.")
EOF
```

python3 docker_test.py

## error

内核名称包含：
miopenSp3AsmConvFury_v2_4_1_gfx11_1536vgprs_fp16_fp16acc_f2x3_c16_stride1


其中 Fury、fp16、f2x3 都与该问题吻合。
1. 先尝试禁用问题内核
在当前 ROCm Docker 容器中执行：
export MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F2X3=0
export MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F3X2=0

python3 test.py


这两个变量分别禁用 Winograd Fury 的 F(2,3) 和 F(3,2) 算法，是目前针对 gfx1151 Linux 问题报告中给出的规避方法。
MIOpen 3.6.3 Documentation+1


注意： 这不是关闭 GPU 加速，而是让 MIOpen 避开存在问题的卷积算法，尝试选择其他卷积实现。性能可能有所下降。

# 环境检测

从输出看，你当前的 `digital-human` 容器配置很简单：

- 镜像：ROCm 7.2.1 + PyTorch 2.9.1
- GPU 设备：`/dev/kfd`、`/dev/dri` 已正确映射
- 数据卷：没有挂载宿主机目录
- 容器状态：`Exited (0)`，正常退出，不是崩溃

这里有一个需要注意的问题：当前容器没有挂载目录，如果在容器内部安装 LiveTalking、下载模型，之后删除容器，这些数据也会丢失。

我建议先保留这个容器作为 GPU 测试环境，再创建一个带持久化目录的数字人开发容器。

## 1. 创建宿主机工作目录

在 Ubuntu 宿主机执行：

```
mkdir -p ~/digital-human/{workspace,models,cache}
```

目录用途：

| 目录          | 用途                       |
| ----------- | ------------------------ |
| `workspace` | LiveTalking、MuseTalk 等源码 |
| `models`    | 数字人模型权重                  |
| `cache`     | HuggingFace 等模型缓存        |

## 2. 创建持久化容器

先删除刚才已经退出的测试容器（不会影响宿主机文件）：

```
docker rm digital-human
```

然后执行：

```
docker run -it \
  --name digital-human \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
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
  rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1 \
  bash
```

这样以后即使删除容器，源码、模型和缓存仍然保存在宿主机。

## 3. 后续启动和进入容器

第一次创建后退出容器：

```
exit
```

以后启动：

```
docker start -ai digital-human
```

如果容器已经在运行，也可以：

```
docker exec -it digital-human bash
```

## 4. 验证配置

进入容器执行：

```
env | grep MIOPEN
```

应该看到：

```
MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F2X3=0
MIOPEN_DEBUG_AMD_WINOGRAD_FURY_RXS_F3X2=0
```

再执行：

```
python3 -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

下一步我建议先部署 LiveTalking，而不是同时安装三个数字人框架。 先验证 LiveTalking 的音频输入、视频生成和 WebRTC 输出，再逐步接入 MuseTalk。

另外，LiveTalking 的原始依赖可能包含 CUDA 专用组件。我们会保留当前 ROCm PyTorch，不直接执行会覆盖它的通用安装命令。
