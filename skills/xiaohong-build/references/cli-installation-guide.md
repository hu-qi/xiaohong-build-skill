# KooCLI Installation Guide

## Overview

Huawei Cloud KooCLI (hcloud) is the command-line tool for managing Huawei Cloud resources. This guide covers installation on common platforms.

## Installation

### Linux (x86_64 / ARM64)

```bash
# Download and install
curl -sSL https://hwcloudcli.obs.cn-north-1.myhuaweicloud.com/cli/latest/hcloud_install.sh -o hcloud_install.sh
bash hcloud_install.sh -y

# Verify
hcloud version
```

### macOS

```bash
# Using Homebrew
brew install hcloud

# Or manual install
curl -sSL https://hwcloudcli.obs.cn-north-1.myhuaweicloud.com/cli/latest/hcloud_install.sh -o hcloud_install.sh
bash hcloud_install.sh -y

# Verify
hcloud version
```

### Windows

```powershell
# Download installer
Invoke-WebRequest -Uri "https://hwcloudcli.obs.cn-north-1.myhuaweicloud.com/cli/latest/hcloud_install.ps1" -OutFile "hcloud_install.ps1"
.\hcloud_install.ps1

# Verify
hcloud version
```

## Configuration

### Interactive Mode

```bash
hcloud configure init
```

### AK/SK Mode (Non-Interactive)

```bash
hcloud configure set --cli-mode=AKSK --access-key=<AK> --secret-key=<SK> --region=cn-north-4
```

### Verify Configuration

```bash
hcloud configure list
```

## Version Requirements

- Minimum version: **3.2.0**
- Recommended version: **latest**

## Troubleshooting

### "hcloud: command not found"

Add KooCLI to PATH:
```bash
echo 'export PATH=$PATH:~/hcloud/cli' >> ~/.bashrc
source ~/.bashrc
```

### SSL Certificate Errors

Set the CA bundle:
```bash
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
```
