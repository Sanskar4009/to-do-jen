pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        PYTHONUNBUFFERED = '1'
        AWS_DEFAULT_REGION = 'us-east-1'
        DOCKER_IMAGE_NAME = 'cloudtodo'
        // Retrieve AWS credentials securely from Jenkins Credentials Manager
        AWS_CREDENTIALS = credentials('aws-credentials-id')
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo 'Checking out source repository...'
                checkout scm
            }
        }

        stage('2. Setup Python & Dependencies') {
            steps {
                echo 'Setting up Python virtual environment and installing packages...'
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements-dev.txt
                '''
            }
        }

        stage('3. Run Tests (pytest)') {
            steps {
                echo 'Running unit and integration tests with pytest...'
                sh '''
                    . .venv/bin/activate
                    pytest tests/ -v --junitxml=reports/test-results.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/test-results.xml'
                }
            }
        }

        stage('4. Terraform Lint & Format') {
            steps {
                echo 'Verifying Terraform formatting...'
                sh '''
                    terraform -chdir=terraform fmt -check
                '''
            }
        }

        stage('5. Terraform Validation') {
            steps {
                echo 'Validating Terraform configuration syntax...'
                sh '''
                    terraform -chdir=terraform init -backend=false
                    terraform -chdir=terraform validate
                '''
            }
        }

        stage('6. Docker Build') {
            steps {
                echo 'Building production Docker image...'
                sh '''
                    docker build -t ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} -t ${DOCKER_IMAGE_NAME}:latest .
                '''
            }
        }

        stage('7. Docker Validation & Smoke Test') {
            steps {
                echo 'Performing container smoke test...'
                sh '''
                    # Run container in test mode
                    docker run -d --name smoke-test-${BUILD_NUMBER} -p 5001:5000 \
                        -e SECRET_KEY="smoke-test-secret" \
                        -e AWS_REGION="us-east-1" \
                        -e DYNAMODB_TABLE="test-table" \
                        ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}

                    # Wait for container startup
                    sleep 5

                    # Verify application responds
                    curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/ | grep -E "200|302"

                    # Teardown smoke test container
                    docker stop smoke-test-${BUILD_NUMBER}
                    docker rm smoke-test-${BUILD_NUMBER}
                '''
            }
        }

        stage('8. Deploy to AWS Infrastructure') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying to AWS using Terraform...'
                // Automated or gated deployment using Jenkins credentials
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        cd terraform
                        if [ ! -f terraform.tfvars ]; then
                            cp terraform.tfvars.example terraform.tfvars
                        fi
                        terraform init -upgrade
                        terraform apply -auto-approve
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution finished. Cleaning up temporary artifacts...'
            cleanWs deleteDirs: true, notFailBuild: true
        }
        success {
            echo 'CloudTodo CI/CD Pipeline completed successfully!'
        }
        failure {
            echo 'CloudTodo CI/CD Pipeline failed. Please check build logs above.'
        }
    }
}
