# xiaohong Build Troubleshooting Guide

## Common Issues and Solutions

### 1. RISC-V Cross Compiler Not Found

**Error:**
```
ccache: error: Could not find compiler "riscv32-linux-musl-gcc" in PATH
```

**Cause:** The RISC-V toolchain is bundled inside the HiSilicon SDK directory and is not in the system PATH by default.

**Solution:**
```bash
export PATH=$PATH:~/xiaohong/device/soc/hisilicon/ws63v100/sdkv106/tools/bin/compiler/riscv/cc_riscv32_musl_105/cc_riscv32_musl/bin
```

Add to `~/.bashrc` for persistence:
```bash
echo 'export PATH=$PATH:~/xiaohong/device/soc/hisilicon/ws63v100/sdkv106/tools/bin/compiler/riscv/cc_riscv32_musl_105/cc_riscv32_musl/bin' >> ~/.bashrc
```

### 2. DNS Resolution Failure

**Error:**
```
Temporary failure in name resolution
```

**Cause:** Huawei Cloud ECS instances use DHCP which may configure DNS servers that cannot resolve external domains.

**Solution:**
Configure Huawei Cloud internal DNS servers and lock the file:
```bash
echo -e "nameserver 100.125.1.250\nnameserver 100.125.21.250" > /etc/resolv.conf
chattr +i /etc/resolv.conf
```

**Important:** The `chattr +i` command prevents DHCP or cloud-init from overwriting the DNS configuration on reboot or network restart.

### 3. Missing Clang/GN/Ninja Compiler

**Error:**
```
ccache: error: execute_noreturn of ../../../prebuilts/clang/ohos/linux-x86_64/llvm/bin/clang failed: No such file or directory
```

or

```
There is no gn executable file at /root/xiaohong/prebuilts/build-tools/linux-x86/bin/gn
```

**Cause:** The prebuilt build tools (clang, gn, ninja) are not included in the git repository and must be downloaded separately.

**Solution:**
```bash
cd ~/xiaohong
bash build/prebuilts_download.sh
```

### 4. hb set Requires Interactive TTY

**Error:**
```
AssertionError (prompt_toolkit requires TTY)
```

**Cause:** The `hb set` command uses prompt_toolkit which requires an interactive terminal. This fails in automated/SSH environments without a TTY.

**Solution:**
Bypass `hb set` by writing `out/ohos_config.json` directly:

```python
import json, os
root = os.path.expanduser("~/xiaohong")
config = {
    "root_path": root,
    "board": "xiaohong",
    "kernel": "liteos_m",
    "product": "xiaohong",
    "product_path": f"{root}/vendor/atomgit/xiaohong",
    "device_path": f"{root}/device/board/atomgit/xiaohong/liteos_m",
    "device_company": "atomgit",
    "os_level": "mini",
    "version": "3.0",
    "patch_cache": None,
    "product_json": f"{root}/vendor/atomgit/xiaohong/config.json",
    "component_type": "",
    "product_config_path": f"{root}/vendor/atomgit/xiaohong",
    "target_cpu": None,
    "target_os": None,
    "out_path": f"{root}/out/xiaohong/xiaohong",
    "subsystem_config_json": "build/subsystem_config.json",
    "device_config_path": f"{root}/device/board/atomgit/xiaohong/liteos_m",
    "support_cpu": None,
    "precise_branch": None,
    "compile_config": None,
    "log_mode": "normal",
}
os.makedirs(f"{root}/out", exist_ok=True)
with open(f"{root}/out/ohos_config.json", "w") as f:
    json.dump(config, f, indent=2)
```

### 5. Failed to Init Compile Config

**Error:**
```
OHOSException: Failed to init compile config
Solution: Please run command 'hb set' to init OHOS development environment
```

**Cause:** This means `out/ohos_config.json` is missing or invalid.

**Solution:** Either run `hb set` interactively (requires TTY), or write `ohos_config.json` manually as described in issue #4.

### 6. Security Group Blocks DNS for Background Processes

**Error:** Background processes (like `prebuilts_download.sh`) fail with DNS errors even though interactive SSH commands work fine.

**Cause:** The security group may allow TCP traffic but block UDP port 53 (DNS), which background processes need.

**Solution:** Add an inbound rule to the ECS security group:
- Protocol: **UDP**
- Port: **53**
- Source: **0.0.0.0/0**

### 7. ohos-build Installation Fails

**Error:**
```
error: externally-managed-environment
```

**Cause:** Ubuntu 23.04+ uses PEP 668 externally managed Python environment.

**Solution:**
```bash
pip3 install ohos-build==1.0.0 --break-system-packages
```

## Build Environment Requirements

| Component | Requirement | Notes |
|-----------|-------------|-------|
| OS | Ubuntu 22.04 | Required for toolchain compatibility |
| RAM | 16GB+ | Build will OOM with less |
| Disk | 200GB+ | Source ~7.6GB + prebuilts + build output |
| CPU | 2+ vCPU | More cores = faster build |
| Python | 3.x | For ohos-build and scripts |
| ohos-build | 1.0.0 | OpenHarmony build tool |
| ccache | 4.x | Speeds up rebuilds |

## Build Configuration Reference

| Setting | Value |
|---------|-------|
| Product | xiaohong |
| Board | xiaohong |
| Kernel | liteos_m |
| OS Level | mini |
| Architecture | rv32imfc (RISC-V) |
| Toolchain | riscv32-linux-musl-gcc 7.3.0 |
| Compiler | gcc |
| Source Branch | OpenHarmony-6.1.0.31-Release |
