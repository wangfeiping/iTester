
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
