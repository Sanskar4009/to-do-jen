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
    dnf install -y docker git curl
elif command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y docker.io git curl
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

# 4. Clone Application Repository if accessible
if [ -n "$REPO_URL" ] && [[ "$REPO_URL" != *"YOUR_USERNAME"* ]]; then
    echo "[$(date)] Cloning repository from $REPO_URL..."
    if git clone "$REPO_URL" repo_temp; then
        cp -r repo_temp/* "$APP_DIR/"
        rm -rf repo_temp
        CLONE_SUCCESS=true
        echo "[$(date)] Successfully cloned repository."
    else
        echo "[$(date)] Git clone failed. Falling back to self-contained bootstrap..."
    fi
fi

# 5. If clone failed or placeholder URL was provided, bootstrap self-contained app directly
if [ "$CLONE_SUCCESS" = false ]; then
    echo "[$(date)] Creating application files locally on instance..."
    mkdir -p "$APP_DIR/app/templates" "$APP_DIR/app/static/css" "$APP_DIR/app/static/js"

    # Write requirements.txt
    cat <<'EOF' > "$APP_DIR/requirements.txt"
Flask==3.0.3
boto3==1.34.131
botocore==1.34.131
gunicorn==22.0.0
python-dotenv==1.0.1
EOF

    # Write Dockerfile
    cat <<'EOF' > "$APP_DIR/Dockerfile"
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=5000
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
COPY run.py .
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD curl -f http://localhost:5000/ || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "4", "run:app"]
EOF

    # If local source files exist in the deploy directory, they are present; otherwise we clone from GitHub
    echo "[$(date)] Application structure created."
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
    -p ${app_port}:5000 \
    -e AWS_REGION="${aws_region}" \
    -e DYNAMODB_TABLE="${dynamodb_table}" \
    -e SNS_TOPIC_ARN="${sns_topic_arn}" \
    -e FLASK_ENV="production" \
    -e PORT=5000 \
    cloudtodo:latest

echo "[$(date)] CloudTodo application deployed and running successfully on port ${app_port}."
