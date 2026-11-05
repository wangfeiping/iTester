# 环境检测

建议先执行一次完整的环境检测，重点确认 ROCm 7.x、PyTorch、gfx1151、GPU 运算能力、内存及 Docker 环境。

下面这段脚本不会修改系统，只读取环境信息。

### 1. 创建检测脚本

文件名：`check_ai_environment.sh`

```

#!/usr/bin/env bash

echo "======================================"
echo " AMD AI Environment Diagnostic"
echo "======================================"

echo
echo "===== 1. OS & Kernel ====="
cat /etc/os-release | grep -E 'PRETTY_NAME|VERSION_ID'
uname -r

echo
echo "===== 2. CPU ====="
lscpu | grep -E 'Model name|Architecture|CPU\(s\)'

echo
echo "===== 3. Memory ====="
free -h

echo
echo "===== 4. GPU Devices ====="
lspci | grep -Ei 'VGA|Display|3D'

echo
echo "===== 5. GPU Device Nodes ====="
ls -l /dev/kfd /dev/dri/renderD* 2>/dev/null

echo
echo "===== 6. ROCm Installation ====="
if command -v rocminfo >/dev/null 2>&1; then
    rocminfo 2>/dev/null | grep -E 'Name:|Marketing Name:|gfx[0-9]+' | head -30
else
    echo "rocminfo not found"
fi

echo
echo "===== 7. HIP Version ====="
if command -v hipconfig >/dev/null 2>&1; then
    hipconfig --version
    hipconfig --full 2>/dev/null | grep -E 'HIP_PATH|ROCM_PATH|HIP_COMPILER'
else
    echo "hipconfig not found"
fi

echo
echo "===== 8. ROCm Packages ====="
dpkg -l 2>/dev/null | grep -E 'rocm|hip-runtime|hsa-rocr|amdgpu' | grep '^ii' | head -40

echo
echo "===== 9. PyTorch ====="
python3 - <<'PY'
try:
    import torch

    print("PyTorch:", torch.__version__)
    print("HIP:", torch.version.hip)
    print("CUDA API available:", torch.cuda.is_available())

    if torch.cuda.is_available():
        print("GPU:", torch.cuda.get_device_name(0))
        print("GPU count:", torch.cuda.device_count())
        print("Architecture:", torch.cuda.get_device_capability(0))

        print("\nTesting FP16 matrix multiplication...")
        a = torch.randn(2048, 2048, device="cuda", dtype=torch.float16)
        b = torch.randn(2048, 2048, device="cuda", dtype=torch.float16)
        c = a @ b
        torch.cuda.synchronize()

        print("FP16 test: PASS")
        print("Output:", c.shape)

        print("\nTesting FP32 matrix multiplication...")
        a = torch.randn(1024, 1024, device="cuda", dtype=torch.float32)
        b = torch.randn(1024, 1024, device="cuda", dtype=torch.float32)
        c = a @ b
        torch.cuda.synchronize()

        print("FP32 test: PASS")
    else:
        print("GPU unavailable to PyTorch")

except Exception as e:
    print("PYTORCH ERROR:", repr(e))
PY

echo
echo "===== 10. Python & Packages ====="
python3 --version
python3 -m pip show torch torchvision torchaudio 2>/dev/null | grep -E '^(Name|Version):'

echo
echo "===== 11. Docker ====="
if command -v docker >/dev/null 2>&1; then
    docker --version
    docker compose version
else
    echo "Docker not installed"
fi

echo
echo "===== 12. GPU Process / Monitoring ====="
if command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi
elif command -v amd-smi >/dev/null 2>&1; then
    amd-smi
else
    echo "GPU monitoring tool not found"
fi

echo
echo "======================================"
echo " Diagnostic completed"
echo "======================================"

```

### 2. 执行

```
chmod +x check_ai_environment.sh
./check_ai_environment.sh 2>&1 | tee ai_environment_report.txt
```

### 3. 我重点关注的检测结果

| 检查项                         | 预期结果       |
| --------------------------- | ---------- |
| GPU Architecture            | gfx1151    |
| ROCm                        | 7.2.x      |
| PyTorch                     | 2.9.1 ROCm |
| `torch.cuda.is_available()` | True       |
| FP16 矩阵运算                   | PASS       |
| FP32 矩阵运算                   | PASS       |
| `/dev/kfd`                  | 存在         |
| `/dev/dri/renderD128`       | 存在         |

注意：PyTorch 在 ROCm 下仍然使用 `torch.cuda` 这个接口名称，这是正常的。

特别重要： 这次不只是检查版本号，而是实际执行 FP16、FP32 GPU 矩阵运算。之前你的环境曾经出现过 `invalid device function`，所以实际运算成功比版本号更有意义。

把生成的 `ai_environment_report.txt` 发给我，我会据此判断：

1. ROCm 与 gfx1151 是否完全匹配。
2. PyTorch 是否真正调用 AMD GPU。
3. 是否具备运行 Wav2Lip、MuseTalk 的基础条件。
4. 是否需要进一步调整 Python、ROCm 或 PyTorch 环境。

# 

我看完检测报告了。结论非常明确：

GPU 环境尚未配置完成

&#x20;你的硬件和 ROCm 驱动已经识别 gfx1151，但当前 Python 中的 PyTorch 是 NVIDIA CUDA 版本，完全没有使用 AMD GPU。



好消息是：目前不需要重装 Ubuntu，也不需要重新安装整个 ROCm 驱动。我们主要需要处理 Python 和 PyTorch 的运行环境。

## 一、当前环境诊断

硬件识别

正常

- AMD Ryzen AI Max+ 395
- Radeon 8060S
- gfx1151
- 109 GiB 系统内存
- `/dev/kfd` 和 `/dev/dri/renderD128` 均存在

  ROCm 驱动

  已安装
- ROCm 6.4.2
- HIP 6.4
- rocminfo 能够识别 GPU

  PyTorch

  需要修复
- 当前：PyTorch 2.12.0+cu130
- CUDA API 不可用
- HIP = None
- GPU available = False

  Docker

  正常
- Docker 29.8.0
- Docker Compose 5.5.1

### 有三个值得注意的问题

1. ROCm 6.4.2 已经能够识别 gfx1151，但识别设备不等于所有深度学习算子都能运行。
2. Python 3.13.13 对部分数字人开源项目的依赖兼容性不够理想。
3. 你的 PyTorch 是 CUDA 130 编译版本，不是 ROCm 版本。即使系统安装了 ROCm，也无法让这个 PyTorch 自动使用 AMD GPU。

## 二、推荐修复路线：先用 Docker 隔离测试

我建议暂时不要升级宿主机 ROCm，也不要卸载现有 PyTorch。

AMD 官方针对 Ryzen AI Max+ 395 提供了 ROCm 7.2.1 + PyTorch 2.9.1 + Python 3.12 的生产支持组合，且要求 Linux 内核至少为 6.14-1018。你的 6.17 内核满足这个版本要求。官方还提供了预装 PyTorch 的 Docker 镜像。

[image](https://www.google.com/s2/favicons?domain=https://rocm.docs.amd.com\&sz=32)

Use ROCm on Radeon and Ryzen+1



这正好适合我们现在的目标：先验证单路数字人推理，不破坏现有 ComfyUI、Ollama 和其他 Python 环境。

### 推荐测试环境

| 组件            | 测试版本       |
| ------------- | ---------- |
| 宿主机 ROCm      | 暂时保持 6.4.2 |
| Docker 内 ROCm | 7.2.1      |
| PyTorch       | 2.9.1      |
| Python        | 3.12       |
| GPU           | gfx1151    |

注意：容器测试是否成功，还取决于宿主机 AMD 内核驱动与容器 ROCm 用户态组件的兼容性。

## 三、第一步：拉取 AMD 官方镜像

执行：

```
docker pull rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1
```

然后启动容器：

```
docker run -it --rm \
  --name rocm-pytorch-test \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --ipc=host \
  --shm-size=8g \
  --security-opt seccomp=unconfined \
  --cap-add=SYS_PTRACE \
  rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1 \
  bash
```

这是 AMD 官方提供的 Docker 部署方式。

[image](https://www.google.com/s2/favicons?domain=https://rocm.docs.amd.com\&sz=32)

Use ROCm on Radeon and Ryzen



如果容器出现 `/dev/kfd permission denied`，再检查宿主机的 `render` 和 `video` 用户组权限，不要直接修改设备权限。

## 四、第二步：在容器内测试 GPU

进入容器后，执行：

```
python3 - <<'PY'
import torch

print("PyTorch:", torch.__version__)
print("HIP:", torch.version.hip)
print("GPU available:", torch.cuda.is_available())

assert torch.version.hip is not None, "Not a ROCm PyTorch build"
assert torch.cuda.is_available(), "AMD GPU unavailable"

print("GPU:", torch.cuda.get_device_name(0))

props = torch.cuda.get_device_properties(0)
print("GPU properties:", props)
print("VRAM reported:", round(props.total_memory / 1024**3, 2), "GiB")

# AMD 官方对 Ryzen APU 组合验证的重点数据类型是 FP16
print("\nTesting FP16 GPU computation...")

a = torch.randn(2048, 2048, device="cuda", dtype=torch.float16)
b = torch.randn(2048, 2048, device="cuda", dtype=torch.float16)

for i in range(10):
    c = torch.matmul(a, b)

torch.cuda.synchronize()

print("FP16: PASS")
print("Result shape:", c.shape)
print("Result device:", c.device)
print("Result dtype:", c.dtype)

print("\nAll GPU tests passed!")
PY
```

预期结果：

```
PyTorch: 2.9.1...
HIP: 7.2.1
GPU available: True
GPU: AMD Radeon Graphics

FP16: PASS
Result shape: torch.Size([2048, 2048])
Result device: cuda:0
Result dtype: torch.float16

All GPU tests passed!
```

其中 `HIP` 的具体显示格式可能有所不同。

## 五、测试通过后的下一步

如果上面的测试成功，我们就可以开始部署数字人模型。

我的建议是按以下顺序：

1. Wav2Lip：验证 GPU 推理和口型生成。
2. LiveTalking：验证实时视频生成和 WebRTC 输出。
3. MuseTalk：测试更高质量的数字人。
4. Pipecat：接入实时语音交互。

先不要升级宿主机 ROCm 7.2.1，也不要安装其他模型依赖。

请先把 Docker 镜像拉取结果和 FP16 测试结果发给我。我们先确认 gfx1151 能否在容器内真正执行 AI 推理，再决定后续部署方案。
