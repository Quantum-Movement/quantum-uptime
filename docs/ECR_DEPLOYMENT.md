# ECR Deployment Guide

This guide explains how to build and push the Quantmove Uptime Docker image to AWS ECR.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Docker installed and running
- Access to the ECR repository

## ECR Repository Naming Convention

| Environment | ECR Repository Name |
|-------------|---------------------|
| Production  | `production-qt-uptime` |
| Staging     | `staging-qt-uptime` |

## Build and Push to ECR

### 1. Set Environment Variables

```bash
# Set your AWS account and region
export AWS_ACCOUNT_ID="your-account-id"
export AWS_REGION="us-west-2"
export ENVIRONMENT="production"  # or "staging"
export ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENVIRONMENT}-qt-uptime"
```

### 2. Authenticate with ECR

```bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

### 3. Build the Docker Image

```bash
# Build the image
docker build -f docker/dockerfile -t quantmove-uptime:latest --target release .
```

### 4. Tag and Push to ECR

```bash
# Tag with ECR repository
docker tag quantmove-uptime:latest ${ECR_REPO}:latest

# Optional: Tag with version
docker tag quantmove-uptime:latest ${ECR_REPO}:$(git describe --tags --always)

# Push to ECR
docker push ${ECR_REPO}:latest
```

## Complete Example Script

```bash
#!/bin/bash
set -e

# Configuration
AWS_ACCOUNT_ID="694260482182"
AWS_REGION="us-west-2"
ENVIRONMENT="production"
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENVIRONMENT}-qt-uptime"
VERSION=$(git describe --tags --always 2>/dev/null || echo "latest")

echo "Building Quantmove Uptime for ${ENVIRONMENT}..."
echo "ECR Repository: ${ECR_REPO}"
echo "Version: ${VERSION}"

# Authenticate
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build
docker build -f docker/dockerfile -t quantmove-uptime:${VERSION} --target release .

# Tag
docker tag quantmove-uptime:${VERSION} ${ECR_REPO}:${VERSION}
docker tag quantmove-uptime:${VERSION} ${ECR_REPO}:latest

# Push
docker push ${ECR_REPO}:${VERSION}
docker push ${ECR_REPO}:latest

echo "Successfully pushed to ECR!"
echo "Image: ${ECR_REPO}:${VERSION}"
```

## Update Running EC2 Instance

After pushing a new image to ECR, update the running EC2 instance:

```bash
# 1. Connect to EC2 via SSM
aws ssm start-session --target <instance-id>

# 2. Authenticate with ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# 3. Pull the new image
docker pull <account-id>.dkr.ecr.us-west-2.amazonaws.com/production-qt-uptime:latest

# 4. Restart the service
sudo systemctl restart quantmove-uptime.service

# 5. Verify
sudo systemctl status quantmove-uptime.service
curl http://localhost:3001/api/ping
```

## CI/CD Integration

For GitHub Actions, see the workflow file at `.github/workflows/qt-uptime.yml`.

## Troubleshooting

### Authentication Failed

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Re-authenticate with ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com
```

### Image Not Found

```bash
# Check if repository exists
aws ecr describe-repositories --repository-names production-qt-uptime

# Create repository if needed
aws ecr create-repository --repository-name production-qt-uptime
```

### Permission Denied

Ensure your IAM role/user has the following permissions:
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
