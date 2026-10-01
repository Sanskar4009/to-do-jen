#!/bin/bash
# ============================================================
# CloudTodo EC2 Bootstrap Script (cloud-init)
# ============================================================

set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "[$(date)] Starting CloudTodo EC2 Initialization..."

# 1. Update Operating System packages
echo "[$(date)] Updating operating system packages..."
if command -v dnf &>/dev/null; then
    dnf update -y
    dnf install -y docker git tar gzip awscli
elif command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y docker.io git tar gzip awscli
fi

# 2. Start and enable Docker service
echo "[$(date)] Starting and enabling Docker daemon..."
systemctl start docker
systemctl enable docker

# Add default users to docker group
usermod -a -G docker ec2-user || true
usermod -a -G docker ubuntu || true

# 3. Setup Application Directory
APP_DIR="/opt/cloudtodo"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

REPO_URL="${app_repository_url}"
CLONE_SUCCESS=false

# 4. Clone Application Repository if a valid custom URL is provided
if [ -n "$REPO_URL" ] && [[ "$REPO_URL" != *"YOUR_USERNAME"* ]]; then
    echo "[$(date)] Cloning repository from $REPO_URL..."
    if git clone "$REPO_URL" repo_temp; then
        cp -r repo_temp/* "$APP_DIR/"
        rm -rf repo_temp
        CLONE_SUCCESS=true
        echo "[$(date)] Successfully cloned repository."
    fi
fi

# 5. Fallback: Download application package from S3
if [ "$CLONE_SUCCESS" = false ]; then
    echo "[$(date)] Downloading application package from S3 (${s3_bucket})..."
    aws s3 cp "s3://${s3_bucket}/app.tar.gz" "$APP_DIR/app.tar.gz" --region "${aws_region}"
    tar -xzf "$APP_DIR/app.tar.gz" -C "$APP_DIR/"
    rm -f "$APP_DIR/app.tar.gz"
    echo "[$(date)] Application package extracted successfully."
fi

# 6. Build and launch Docker Container
echo "[$(date)] Building Docker container image..."
cd "$APP_DIR"
docker build -t cloudtodo:latest .

# Stop any previously running container
docker stop cloudtodo-app 2>/dev/null || true
docker rm cloudtodo-app 2>/dev/null || true

# 7. Run Docker Container with dynamic environment variables
echo "[$(date)] Launching CloudTodo container..."
docker run -d \
    --name cloudtodo-app \
    --restart unless-stopped \
    -p 80:5000 \
    -p ${app_port}:5000 \
    -e AWS_REGION="${aws_region}" \
    -e DYNAMODB_TABLE="${dynamodb_table}" \
    -e SNS_TOPIC_ARN="${sns_topic_arn}" \
    -e FLASK_ENV="production" \
    -e PORT=5000 \
    cloudtodo:latest

echo "[$(date)] CloudTodo application deployed and running successfully on port ${app_port}."
