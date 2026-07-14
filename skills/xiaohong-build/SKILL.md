---
name: xiaohong-build
description: |
  Build xiaohong (OpenHarmony mini system for WS63 chip) firmware on Huawei Cloud ECS with full automation. Provisions on-demand ECS instance, installs build dependencies, downloads source code, configures RISC-V toolchain, and compiles firmware (.fwpkg). Use this skill when users want to build or compile xiaohong, set up OpenHarmony mini system build environment, or create cloud build machine for WS63 chip development. Trigger conditions: "编译xiaohong", "构建xiaohong", "build xiaohong", "compile xiaohong", "OpenHarmony编译", "WS63开发", "liteos_m编译", "mini系统构建", "xiaohong固件", "xiaohong firmware", "WS63固件编译".
tags: [huawei-cloud, ecs, xiaohong, openharmony, build, compile, firmware, ws63, liteos-m, risc-v]
---

# xiaohong Build Skill

## Overview

This skill automates the complete process of compiling xiaohong (OpenHarmony mini system for WS63 chip) on a Huawei Cloud on-demand ECS instance. It covers the full lifecycle: provisioning ECS, setting up the build environment, compiling firmware, and optional cleanup.

**Applicable Scenarios**:

- Building xiaohong firmware on Huawei Cloud ECS
- Setting up OpenHarmony mini system build environment
- Creating cloud build machine for WS63 chip development
- Producing `.fwpkg` firmware packages for flashing

## Prerequisites

### 1. Huawei Cloud CLI Tool Installed

Required check: Huawei Cloud CLI (hcloud / KooCLI) >= 3.2.0

```bash
# Check if installed
hcloud version
```

If not installed, refer to [cli-installation-guide.md](references/cli-installation-guide.md) for KooCLI installation.

### 2. Huawei Cloud Credentials Configured

- Valid Huawei Cloud credentials (AK/SK mode)

```bash
# View configuration
hcloud configure list
```

If Huawei Cloud credentials are not configured, prompt the user to configure:

```bash
hcloud configure set --cli-mode=AKSK --access-key=<Your AK> --secret-key=<Your SK> --region=cn-north-4
```

- **Security Rules**:
  - 🚫 Do not directly enter AK/SK values in plain text.
  - 🚫 Never expose AK/SK values.
  - ✅ Only use `hcloud configure list` to check credential status.

### 3. Terraform Installed

Required for provisioning ECS instance:

```bash
terraform version
```

If not installed, use the `huawei-cloud-terraform-installer` skill to install Terraform with Huawei Cloud mirror support.

### 4. SSH Access

The skill uses SSH to execute commands on the created ECS instance. Ensure `ssh` and `scp` are available locally.

## Core Workflow

### Step 1: Provision ECS Instance

Create an on-demand ECS instance using Terraform with the following recommended configuration:

| Parameter | Value | Description |
|-----------|-------|-------------|
| Region | cn-north-4 | Huawei Cloud North China-Beijing 4 |
| Flavor | m7.large.8 | 2 vCPU, 16GB RAM (minimum for build) |
| Image | Ubuntu 22.04 server 64bit | Required OS for xiaohong build |
| Disk | 200GB GPSSD | System disk (source code ~7.6GB + build output) |
| Password | User-provided | ECS login password |

```bash
# Provision using the provided Terraform configuration
cd references/terraform
terraform init
terraform apply -auto-approve

# Get the public IP
terraform output public_ip
```

> **Coupon Support**: On-demand ECS instances support coupon payment. Check available coupons before provisioning:
> ```bash
> hcloud BSS v2 show-user-coupon-info --cli-region=cn-north-4
> ```

### Step 2: Configure DNS

Huawei Cloud ECS requires internal DNS servers for domain resolution. This must be done before any network operations:

```bash
ssh root@<ECS_IP> 'bash -c "echo -e \"nameserver 100.125.1.250\nnameserver 100.125.21.250\" > /etc/resolv.conf"'
ssh root@<ECS_IP> 'chattr +i /etc/resolv.conf'
```

> **Important**: `chattr +i` locks `/etc/resolv.conf` to prevent DHCP or cloud-init from overwriting DNS configuration.

### Step 3: Install Build Dependencies

```bash
ssh root@<ECS_IP> 'apt-get update && apt-get install -y \
    build-essential gcc g++ make cmake \
    python3 python3-pip \
    git curl wget \
    ccache \
    libssl-dev \
    flex bison \
    ruby \
    openjdk-11-jdk \
    expect'

ssh root@<ECS_IP> 'pip3 install ohos-build==1.0.0'
```

### Step 4: Download Source Code

```bash
ssh root@<ECS_IP> 'git clone --depth=1 -b OpenHarmony-6.1.0.31-Release \
    https://git.atomgit.com/atomgit/xiaohong.git ~/xiaohong'
```

Source code size: ~7.6GB, branch: `OpenHarmony-6.1.0.31-Release`

### Step 5: Download Prebuilt Tools

Download clang, gn, ninja and other build tools:

```bash
ssh root@<ECS_IP> 'cd ~/xiaohong && bash build/prebuilts_download.sh'
```

### Step 6: Configure RISC-V Toolchain

The RISC-V cross compiler (`riscv32-linux-musl-gcc`) is bundled inside the HiSilicon SDK. It must be added to PATH:

```bash
TOOLCHAIN=~/xiaohong/device/soc/hisilicon/ws63v100/sdkv106/tools/bin/compiler/riscv/cc_riscv32_musl_105/cc_riscv32_musl/bin
ssh root@<ECS_IP> "echo 'export PATH=\$PATH:${TOOLCHAIN}' >> ~/.bashrc"
```

Verify:

```bash
ssh root@<ECS_IP> "${TOOLCHAIN}/riscv32-linux-musl-gcc --version"
```

### Step 7: Configure Build Target

The `hb set` command requires an interactive TTY which is not available in automated environments. Bypass it by writing `ohos_config.json` directly:

```bash
ssh root@<ECS_IP> 'python3 -c "
import json, os
root = os.path.expanduser(\"~/xiaohong\")
config = {
    \"root_path\": root,
    \"board\": \"xiaohong\",
    \"kernel\": \"liteos_m\",
    \"product\": \"xiaohong\",
    \"product_path\": f\"{root}/vendor/atomgit/xiaohong\",
    \"device_path\": f\"{root}/device/board/atomgit/xiaohong/liteos_m\",
    \"device_company\": \"atomgit\",
    \"os_level\": \"mini\",
    \"version\": \"3.0\",
    \"patch_cache\": None,
    \"product_json\": f\"{root}/vendor/atomgit/xiaohong/config.json\",
    \"component_type\": \"\",
    \"product_config_path\": f\"{root}/vendor/atomgit/xiaohong\",
    \"target_cpu\": None,
    \"target_os\": None,
    \"out_path\": f\"{root}/out/xiaohong/xiaohong\",
    \"subsystem_config_json\": \"build/subsystem_config.json\",
    \"device_config_path\": f\"{root}/device/board/atomgit/xiaohong/liteos_m\",
    \"support_cpu\": None,
    \"precise_branch\": None,
    \"compile_config\": None,
    \"log_mode\": \"normal\",
}
os.makedirs(f\"{root}/out\", exist_ok=True)
with open(f\"{root}/out/ohos_config.json\", \"w\") as f:
    json.dump(config, f, indent=2)
"'
```

### Step 8: Build Firmware

```bash
ssh root@<ECS_IP> 'cd ~/xiaohong && export PATH=$PATH:~/xiaohong/device/soc/hisilicon/ws63v100/sdkv106/tools/bin/compiler/riscv/cc_riscv32_musl_105/cc_riscv32_musl/bin && hb build -f'
```

Expected build time: ~3-5 minutes (with ccache)

### Step 9: Fetch Firmware

After successful compilation, firmware files are located at:

```
~/xiaohong/out/xiaohong/xiaohong/ws63-liteos-app/
├── ws63-liteos-app_all.fwpkg        # Full firmware package (~1.95MB)
└── ws63-liteos-app_load_only.fwpkg  # Load-only firmware package (~1.82MB)
```

```bash
# Download firmware to local machine
scp root@<ECS_IP>:~/xiaohong/out/xiaohong/xiaohong/ws63-liteos-app/*.fwpkg ./
```

### Step 10: Destroy ECS (Optional)

```bash
cd references/terraform
terraform destroy -auto-approve
```

## One-Click Build Script

For fully automated build, use the provided script:

```bash
# Full automated build (provision + setup + compile + fetch + cleanup)
./scripts/build_xiaohong.sh

# Skip provisioning (use existing ECS)
./scripts/build_xiaohong.sh --skip-provision --host <ECS_IP>

# Skip cleanup (keep ECS running)
./scripts/build_xiaohong.sh --skip-cleanup
```

## Parameter Confirmation

### Required Parameters

- **ECS Password**: Login password for the created ECS instance (must comply with Huawei Cloud password policy: 8-26 characters, at least 3 of uppercase, lowercase, digits, special characters)

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `REGION` | cn-north-4 | Huawei Cloud region |
| `FLAVOR` | m7.large.8 | ECS flavor (2 vCPU, 16GB RAM) |
| `DISK_SIZE` | 200 | System disk size in GB |
| `DISK_TYPE` | GPSSD | System disk type |
| `SOURCE_BRANCH` | OpenHarmony-6.1.0.31-Release | xiaohong source branch |
| `SOURCE_URL` | https://git.atomgit.com/atomgit/xiaohong.git | xiaohong source repository |

## Key Learnings

This skill encapsulates solutions for several non-trivial issues encountered during the build:

1. **RISC-V Toolchain** — The `riscv32-linux-musl-gcc` compiler is bundled inside the HiSilicon SDK at `device/soc/hisilicon/ws63v100/sdkv106/tools/bin/compiler/riscv/cc_riscv32_musl_105/cc_riscv32_musl/bin/` and must be added to PATH
2. **DNS Resolution** — Huawei Cloud ECS requires internal DNS servers (`100.125.1.250`, `100.125.21.250`) and `/etc/resolv.conf` must be locked with `chattr +i` to prevent overwrite
3. **Prebuilts Download** — `build/prebuilts_download.sh` must be run to download clang, gn, ninja and other build tools
4. **hb set Configuration** — The `hb set` command requires an interactive TTY; we bypass it by writing `out/ohos_config.json` directly
5. **Security Group** — UDP port 53 must be open in the security group for DNS resolution in background processes

## Best Practices

1. **Flavor Selection**: Use `m7.large.8` (0.725 CNY/h) as the minimum cost option for 16GB RAM
2. **On-Demand Mode**: Use on-demand billing to avoid long-running charges; destroy after build
3. **Coupon Usage**: On-demand instances support coupon payment — check coupons before provisioning
4. **ccache**: Build with ccache enabled for faster rebuilds (~19% hit rate observed)
5. **Shallow Clone**: Use `--depth=1` for git clone to save time and disk space
6. **DNS Lock**: Always lock `/etc/resolv.conf` after configuring DNS to prevent silent failures

## Notes

1. **Build Time**: First build takes ~3-5 minutes; subsequent builds with ccache are faster
2. **Disk Space**: Source code (~7.6GB) + prebuilts + build output requires ~50GB minimum; 200GB recommended
3. **Memory**: 16GB RAM is the minimum; builds may fail with less memory
4. **Security**: Do not hard-code AK/SK or passwords in scripts; use environment variables or configuration files
5. **Cleanup**: Always destroy the ECS instance after build to avoid ongoing charges
6. **Firmware**: The `.fwpkg` files are ready for flashing to WS63 chip via the appropriate burning tool

## Reference Documentation

| Document | Description |
|----------|-------------|
| [Terraform Configuration](references/terraform/) | ECS provisioning Terraform configs |
| [Troubleshooting Guide](references/troubleshooting.md) | Common build issues and solutions |
| [KooCLI Installation Guide](references/cli-installation-guide.md) | KooCLI installation guide |
