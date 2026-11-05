

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
