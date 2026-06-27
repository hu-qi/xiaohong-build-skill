terraform {
  required_version = ">= 1.0.0"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = ">= 1.50.0"
    }
  }
}

variable "region" {
  description = "Huawei Cloud region"
  type        = string
  default     = "cn-north-4"
}

variable "flavor_id" {
  description = "ECS flavor ID"
  type        = string
  default     = "m7.large.8"
}

variable "image_name" {
  description = "ECS image name"
  type        = string
  default     = "Ubuntu 22.04 server 64bit"
}

variable "disk_size" {
  description = "System disk size in GB"
  type        = number
  default     = 200
}

variable "disk_type" {
  description = "System disk type"
  type        = string
  default     = "GPSSD"
}

variable "admin_password" {
  description = "ECS admin password"
  type        = string
  default     = "Xiaohong@2026!"
  sensitive   = true
}

variable "vpc_id" {
  description = "Existing VPC ID (leave empty to create new)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Existing Subnet ID (leave empty to create new)"
  type        = string
  default     = ""
}

variable "security_group_id" {
  description = "Existing Security Group ID (leave empty to create new)"
  type        = string
  default     = ""
}

provider "huaweicloud" {
  region = var.region
}

data "huaweicloud_images_image_v2" "ubuntu" {
  name        = var.image_name
  image_type  = "ECS"
  most_recent = true
}

# Use existing VPC or create new
data "huaweicloud_vpc_v1" "existing" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

resource "huaweicloud_vpc_v1" "new" {
  count = var.vpc_id == "" ? 1 : 0
  name  = "xiaohong-build-vpc"
  cidr  = "192.168.0.0/16"
}

locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : huaweicloud_vpc_v1.new[0].id
}

# Use existing Subnet or create new
data "huaweicloud_vpc_subnet_v1" "existing" {
  count   = var.subnet_id != "" ? 1 : 0
  id      = var.subnet_id
}

resource "huaweicloud_vpc_subnet_v1" "new" {
  count      = var.subnet_id == "" ? 1 : 0
  name       = "xiaohong-build-subnet"
  vpc_id     = local.vpc_id
  cidr       = "192.168.0.0/24"
  gateway_ip = "192.168.0.1"
}

locals {
  subnet_id = var.subnet_id != "" ? var.subnet_id : huaweicloud_vpc_subnet_v1.new[0].id
}

# Use existing Security Group or create new
data "huaweicloud_networking_secgroup_v2" "existing" {
  count = var.security_group_id != "" ? 1 : 0
  id    = var.security_group_id
}

resource "huaweicloud_networking_secgroup_v2" "new" {
  count = var.security_group_id == "" ? 1 : 0
  name  = "xiaohong-build-sg"
}

resource "huaweicloud_networking_secgroup_rule_v2" "ssh" {
  count             = var.security_group_id == "" ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup_v2.new[0].id
}

resource "huaweicloud_networking_secgroup_rule_v2" "dns_tcp" {
  count             = var.security_group_id == "" ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup_v2.new[0].id
}

resource "huaweicloud_networking_secgroup_rule_v2" "dns_udp" {
  count             = var.security_group_id == "" ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup_v2.new[0].id
}

locals {
  security_group_id = var.security_group_id != "" ? var.security_group_id : huaweicloud_networking_secgroup_v2.new[0].id
}

# ECS Instance
resource "huaweicloud_compute_instance_v2" "xiaohong_build" {
  name              = "xiaohong-build"
  image_id          = data.huaweicloud_images_image_v2.ubuntu.id
  flavor_id         = var.flavor_id
  admin_pass        = var.admin_password
  security_groups   = [local.security_group_id]

  network {
    uuid = local.subnet_id
  }

  block_device {
    volume_type    = var.disk_type
    volume_size    = var.disk_size
    boot_index     = 0
    delete_on_termination = true
  }

  metadata = {
    admin_pass = var.admin_password
  }
}

# Elastic IP
resource "huaweicloud_vpc_eip_v1" "xiaohong_build" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "xiaohong-build-bandwidth"
    size        = 5
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "huaweicloud_compute_floatingip_associate_v2" "xiaohong_build" {
  floating_ip = huaweicloud_vpc_eip_v1.xiaohong_build.publicip[0].ip_address
  instance_id = huaweicloud_compute_instance_v2.xiaohong_build.id
}

output "public_ip" {
  description = "ECS public IP address"
  value       = huaweicloud_vpc_eip_v1.xiaohong_build.publicip[0].ip_address
}

output "instance_id" {
  description = "ECS instance ID"
  value       = huaweicloud_compute_instance_v2.xiaohong_build.id
}

output "private_ip" {
  description = "ECS private IP address"
  value       = huaweicloud_compute_instance_v2.xiaohong_build.access_ip_v4
}
