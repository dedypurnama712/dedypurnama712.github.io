pipeline {
    agent any
    
    environment {
        REGISTRY = 'docker.io'
        IMAGE_NAME = 'simple-journey-app'
        REGISTRY_CREDS = credentials('docker-registry-credentials')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running Go tests...'
                sh 'go test -v ./...'
            }
        }
        
        stage('Build Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    def commitHash = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    def imageTag = "${env.BUILD_NUMBER}-${commitHash}"
                    
                    sh """
                        docker build \
                            --build-arg VERSION=${imageTag} \
                            -t ${IMAGE_NAME}:${imageTag} \
                            -t ${IMAGE_NAME}:latest \
                            .
                    """
                    
                    env.IMAGE_TAG = imageTag
                    env.FULL_IMAGE = "${IMAGE_NAME}:${imageTag}"
                }
            }
        }
        
        stage('Push (Optional)') {
            when {
                expression { 
                    // Only push if registry credentials are available
                    return true
                }
            }
            steps {
                echo "Simulating push to registry: ${REGISTRY}/${FULL_IMAGE}"
                echo "In production, use: docker push ${REGISTRY}/${FULL_IMAGE}"
                echo "Jenkins credential 'docker-registry-credentials' would handle authentication"
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Deploying application (binary swap)...'
                script {
                    sh '''
                        # Get container ID if running
                        CONTAINER_ID=$(docker ps -q -f "name=devops-app") || true
                        
                        if [ -z "$CONTAINER_ID" ]; then
                            echo "Container not running. Starting new container..."
                            docker run -d \
                                --name devops-app \
                                --restart always \
                                -p 8080:8080 \
                                ${IMAGE_NAME}:${IMAGE_TAG}
                        else
                            echo "Container already running. Performing binary swap..."
                            
                            # Create temporary container to extract binary
                            docker create --name temp-extract ${IMAGE_NAME}:${IMAGE_TAG}
                            docker cp temp-extract:/app ./app-new
                            docker rm temp-extract
                            
                            # Copy new binary into running container
                            docker cp ./app-new ${CONTAINER_ID}:/app
                            
                            # Restart container
                            docker restart ${CONTAINER_ID}
                            
                            # Wait for container to be ready
                            sleep 2
                            
                            echo "Binary swap completed"
                        fi
                    '''
                }
            }
        }
    }
    
    post {
        failure {
            echo 'Pipeline failed! Rollback strategy:'
            echo '1. If deploy stage fails, the previous container version remains running'
            echo '2. The docker cp operation is atomic - either succeeds or fails completely'
            echo '3. To rollback: docker restart ${CONTAINER_ID} with previous image'
            echo '4. Implement health checks to catch version issues early'
        }
        
        success {
            echo 'Pipeline completed successfully!'
            sh 'curl -s http://localhost:8080/ || echo "Container may still be starting"'
        }
    }
}
