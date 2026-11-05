
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

