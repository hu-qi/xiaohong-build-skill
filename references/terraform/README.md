# xiaohong Build ECS Terraform Configuration

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | cn-north-4 | Huawei Cloud region |
| `flavor_id` | m7.large.8 | ECS flavor (2 vCPU, 16GB RAM) |
| `image_name` | Ubuntu 22.04 server 64bit | OS image |
| `disk_size` | 200 | System disk size in GB |
| `disk_type` | GPSSD | System disk type |
| `admin_password` | Xiaohong@2026! | ECS admin password |
| `vpc_id` | (empty) | Existing VPC ID (creates new if empty) |
| `subnet_id` | (empty) | Existing Subnet ID (creates new if empty) |
| `security_group_id` | (empty) | Existing Security Group ID (creates new if empty) |

## Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | ECS public IP address |
| `instance_id` | ECS instance ID |
| `private_ip` | ECS private IP address |

## Usage

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply (create ECS)
terraform apply -auto-approve

# Get public IP
terraform output public_ip

# Destroy (delete ECS)
terraform destroy -auto-approve
```

## Using Existing Network

To use an existing VPC, subnet, and security group:

```bash
terraform apply \
  -var="vpc_id=your-vpc-id" \
  -var="subnet_id=your-subnet-id" \
  -var="security_group_id=your-sg-id"
```
