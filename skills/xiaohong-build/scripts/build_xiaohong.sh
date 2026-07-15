#!/bin/bash
#
# xiaohong automated build script.
# Provisions a Huawei Cloud ECS instance, sets up the build environment,
# compiles xiaohong firmware, and optionally cleans up.
#
# Usage:
#   ./build_xiaohong.sh [--skip-provision] [--skip-cleanup] [--host IP]
#

set -euo pipefail

# Default configuration
REGION="${REGION:-cn-north-4}"
FLAVOR="${FLAVOR:-m7.large.8}"
DISK_SIZE="${DISK_SIZE:-200}"
DISK_TYPE="${DISK_TYPE:-GPSSD}"
SOURCE_BRANCH="${SOURCE_BRANCH:-OpenHarmony-6.1.0.31-Release}"
SOURCE_URL="${SOURCE_URL:-https://git.atomgit.com/atomgit/xiaohong.git}"
DNS_SERVERS="${DNS_SERVERS:-100.125.1.250 100.125.21.250}"
RISCV_TOOLCHAIN="device/soc/hisilicon/ws63v100/sdkv106/tools/bin/compiler/riscv/cc_riscv32_musl_105/cc_riscv32_musl/bin"
ECS_PASSWORD="${ECS_PASSWORD:-Xiaohong@2026!}"

SKIP_PROVISION=false
SKIP_CLEANUP=false
HOST=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-provision) SKIP_PROVISION=true; shift ;;
        --skip-cleanup) SKIP_CLEANUP=true; shift ;;
        --host) HOST="$2"; shift 2 ;;
        --password) ECS_PASSWORD="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

ssh_exec() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@${HOST}" "$1"
}

# Step 1: Provision ECS
if [ "$SKIP_PROVISION" = false ]; then
    echo ""
    echo "=== Step 1: Provisioning ECS Instance ==="
    cd "${SKILL_DIR}/references/terraform"
    terraform init
    terraform apply -auto-approve
    HOST=$(terraform output -raw public_ip)
    echo "[INFO] ECS Public IP: ${HOST}"
    echo "[INFO] Waiting 30s for instance to be ready..."
    sleep 30
fi

if [ -z "$HOST" ]; then
    echo "[ERROR] No host IP available. Use --host or remove --skip-provision"
    exit 1
fi

echo "[INFO] Target host: ${HOST}"

# Step 2: Configure DNS
echo ""
echo "=== Step 2: Configuring DNS ==="
DNS1=$(echo "$DNS_SERVERS" | awk '{print $1}')
DNS2=$(echo "$DNS_SERVERS" | awk '{print $2}')
ssh_exec "bash -c 'echo -e \"nameserver ${DNS1}\nnameserver ${DNS2}\" > /etc/resolv.conf'"
ssh_exec "chattr +i /etc/resolv.conf 2>/dev/null || true"

# Step 3: Install dependencies
echo ""
echo "=== Step 3: Installing Build Dependencies ==="
ssh_exec "apt-get update && apt-get install -y \
    build-essential gcc g++ make cmake \
    python3 python3-pip \
    git curl wget \
    ccache \
    libssl-dev \
    flex bison \
    ruby \
    openjdk-11-jdk \
    expect"
ssh_exec "pip3 install ohos-build==1.0.0 2>/dev/null || pip3 install ohos-build==1.0.0"

# Step 4: Download source code
echo ""
echo "=== Step 4: Downloading xiaohong Source Code ==="
ssh_exec "test -d ~/xiaohong || git clone --depth=1 -b ${SOURCE_BRANCH} ${SOURCE_URL} ~/xiaohong"

# Step 5: Download prebuilts
echo ""
echo "=== Step 5: Downloading Prebuilt Tools ==="
ssh_exec "cd ~/xiaohong && bash build/prebuilts_download.sh"

# Step 6: Configure RISC-V toolchain
echo ""
echo "=== Step 6: Setting Up RISC-V Toolchain ==="
ssh_exec "grep -q 'cc_riscv32_musl_105' ~/.bashrc || echo 'export PATH=\$PATH:~/xiaohong/${RISCV_TOOLCHAIN}' >> ~/.bashrc"
ssh_exec "export PATH=\$PATH:~/xiaohong/${RISCV_TOOLCHAIN} && ~/xiaohong/${RISCV_TOOLCHAIN}/riscv32-linux-musl-gcc --version"

# Step 7: Configure build target
echo ""
echo "=== Step 7: Writing Build Configuration ==="
ssh_exec "cd ~/xiaohong && python3 -c \"
import json, os
root = os.path.expanduser('~/xiaohong')
config = {
    'root_path': root,
    'board': 'xiaohong',
    'kernel': 'liteos_m',
    'product': 'xiaohong',
    'product_path': f'{root}/vendor/atomgit/xiaohong',
    'device_path': f'{root}/device/board/atomgit/xiaohong/liteos_m',
    'device_company': 'atomgit',
    'os_level': 'mini',
    'version': '3.0',
    'patch_cache': None,
    'product_json': f'{root}/vendor/atomgit/xiaohong/config.json',
    'component_type': '',
    'product_config_path': f'{root}/vendor/atomgit/xiaohong',
    'target_cpu': None,
    'target_os': None,
    'out_path': f'{root}/out/xiaohong/xiaohong',
    'subsystem_config_json': 'build/subsystem_config.json',
    'device_config_path': f'{root}/device/board/atomgit/xiaohong/liteos_m',
    'support_cpu': None,
    'precise_branch': None,
    'compile_config': None,
    'log_mode': 'normal',
}
os.makedirs(f'{root}/out', exist_ok=True)
with open(f'{root}/out/ohos_config.json', 'w') as f:
    json.dump(config, f, indent=2)
\""

# Step 8: Build firmware
echo ""
echo "=== Step 8: Building Firmware ==="
ssh_exec "cd ~/xiaohong && export PATH=\$PATH:~/xiaohong/${RISCV_TOOLCHAIN} && hb build -f"

# Step 9: Fetch firmware
echo ""
echo "=== Step 9: Fetching Firmware ==="
mkdir -p ./xiaohong-firmware
scp -o StrictHostKeyChecking=no "root@${HOST}:~/xiaohong/out/xiaohong/xiaohong/ws63-liteos-app/*.fwpkg" ./xiaohong-firmware/
echo "[INFO] Firmware saved to ./xiaohong-firmware/"
ls -la ./xiaohong-firmware/

# Step 10: Cleanup
if [ "$SKIP_CLEANUP" = false ] && [ "$SKIP_PROVISION" = false ]; then
    echo ""
    echo "=== Step 10: Destroying ECS Instance ==="
    cd "${SKILL_DIR}/references/terraform"
    terraform destroy -auto-approve
fi

echo ""
echo "[SUCCESS] Build completed! Firmware files are in ./xiaohong-firmware/"
