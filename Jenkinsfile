pipeline {
    agent any
    
    tools {
        jdk 'jdk21'
        nodejs 'node18' // Upgraded to Node 18 to fix the compatibility error
    }
    
    environment {
        // DockerHub configuration
        DOCKERHUB_CREDS = credentials('dockerhub-credentials-id') 
        TMDB_KEY = credentials('tmdb-api-key') 
        IMAGE_NAME = "srinutechguru/netflix--react-clone" 
        TAG = "v${env.BUILD_NUMBER}" 
        
        EKS_CLUSTER_NAME = "eks-cluster" 
        AWS_REGION = "us-east-1" 
        
        // GitHub GitOps Repository configuration
        GITHUB_CREDS = credentials('github-token-id')
        GITOPS_REPO = "https://github.com/srinutechguru/netflix-react-devsecops-project.git"
        
        // Slack Configuration
        SLACK_CHANNEL = "dev"
    }
    
    stages {
        stage('1. Clean Workspace') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🧹 *STAGE 1:* Cleaning the Workspace...")
                cleanWs()
            }
        }
        
        stage('2. Checkout Code') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "📥 *STAGE 2:* Pulling source code from GitHub...")
                git branch: 'main', url: 'https://github.com/srinutechguru/netflix-react-devsecops-project.git'
            }
        }
        
        stage('3. Install Dependencies') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🛠️ *STAGE 3:* Downloading dependencies using NPM...")
                // Standardized on NPM
                sh "npm install"
            }
        }
                
        stage('4. SonarQube Code Analysis') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🔍 *STAGE 4:* Running SonarQube Static Application Security Testing (SAST)...")
                script {
                    def scannerHome = tool 'Sonar-Scanner'
                    withSonarQubeEnv('sonarqube-server') {
                        sh "${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=Netflix-React-Clone \
                            -Dsonar.sources=src/"
                    }
                }
            }
        }
        
        stage('5. Quality Gate') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🚦 *STAGE 5:* Sonarqube Quality Gate stage started...")
                script {
                    waitForQualityGate abortPipeline: true, credentialsId: 'sonarqube-token-id'
                }
            }
        }
        
        stage('6. OWASP Dependency-Check') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🛡️ *STAGE 6:* OWASP Dependency-Check stage started...")
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'owasp-dependency-check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        
        stage('7. Trivy FS Scan') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🔎 *STAGE 7:* Trivy FS Scan stage started...")
                sh "trivy fs . > trivyfs.txt"
            }
        }
              
        stage('8. Docker Build & Tag') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🐳 *STAGE 8:* Building Docker Image: ${IMAGE_NAME}:${TAG}...")
                // Securely pass the TMDB API key during the build
                sh "docker build --build-arg TMDB_V3_API_KEY=${TMDB_KEY} -t ${IMAGE_NAME}:${TAG} ."
                sh "docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:latest"
            }
        }
        
        stage('9. Trivy Image Scan') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🐋 *STAGE 9:* Trivy Image Scan stage started...")
                sh "trivy image ${IMAGE_NAME}:${TAG} > trivyimage.txt" 
            }
        }
        
        stage('10. Docker Push') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🚀 *STAGE 10:* Pushing Docker image to DockerHub...")
                script {
                    withDockerRegistry(credentialsId: 'dockerhub-credentials-id', toolName: 'docker-latest') {   
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                        sh "docker push ${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('11. Deploy to container') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "📦 *STAGE 11:* Deploying to local Docker container...")
                // Stops and removes the old container if it exists, so the port doesn't conflict on rebuilds
                sh 'docker rm -f netflix-app || true'
                // Added your requested deployment command using the dynamic variable
                sh "docker run -d --name netflix-app -p 8081:80 ${IMAGE_NAME}:latest"
            }
        }
        
        stage('12. Deploy to AWS EKS') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "☸️ *STAGE 12:* Deploying to AWS EKS...")
                
                withCredentials([string(credentialsId: 'tmdb-api-key', variable: 'SECURE_TMDB_KEY')]) {
                    sh """
                    # 1. Authorize Kubectl to communicate with the existing EKS cluster
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                    
                    # 2. Update the Kubernetes manifests
                    kubectl apply -f k8s/namespace.yaml

                    # Securely update the K8s Secret with the actual TMDB key
                    ENCODED_KEY=\$(echo -n "\$SECURE_TMDB_KEY" | base64)
                    sed -i "s|tmdb-key: \\"\\"|tmdb-key: \\"\$ENCODED_KEY\\"|g" k8s/deployment.yaml
                    
                    # Replace the dynamic placeholder with the exact new image tag
                    sed -i "s|image: .*|image: ${IMAGE_NAME}:${TAG}|g" k8s/deployment.yaml
                    
                    # Apply updated manifests to the namespace
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    """  
                }
            }
        }
    }
        
    post {
        always {
            slackSend(color: "${currentBuild.currentResult == 'SUCCESS' ? 'good' : 'danger'}", 
                      message: "DevSecOps Pipeline for '${env.JOB_NAME} [${env.BUILD_NUMBER}]' has completed with result: ${currentBuild.currentResult}.\nBuild URL: ${env.BUILD_URL}")
        }
    }
}pipeline {
    agent any
    
    tools {
        jdk 'jdk21'
        nodejs 'node18' // Upgraded to Node 18 to fix the compatibility error
    }
    
    environment {
        // DockerHub configuration
        DOCKERHUB_CREDS = credentials('dockerhub-credentials-id') 
        TMDB_KEY = credentials('tmdb-api-key') 
        IMAGE_NAME = "srinutechguru/netflix--react-clone" 
        TAG = "v${env.BUILD_NUMBER}" 
        
        EKS_CLUSTER_NAME = "eks-cluster" 
        AWS_REGION = "us-east-1" 
        
        // GitHub GitOps Repository configuration
        GITHUB_CREDS = credentials('github-token-id')
        GITOPS_REPO = "https://github.com/srinutechguru/netflix-react-devsecops-project.git"
        
        // Slack Configuration
        SLACK_CHANNEL = "dev"
    }
    
    stages {
        stage('1. Clean Workspace') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🧹 *STAGE 1:* Cleaning the Workspace...")
                cleanWs()
            }
        }
        
        stage('2. Checkout Code') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "📥 *STAGE 2:* Pulling source code from GitHub...")
                git branch: 'main', url: 'https://github.com/srinutechguru/netflix-react-devsecops-project.git'
            }
        }
        
        stage('3. Install Dependencies') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🛠️ *STAGE 3:* Downloading dependencies using NPM...")
                // Standardized on NPM
                sh "npm install"
            }
        }
                
        stage('4. SonarQube Code Analysis') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🔍 *STAGE 4:* Running SonarQube Static Application Security Testing (SAST)...")
                script {
                    def scannerHome = tool 'Sonar-Scanner'
                    withSonarQubeEnv('sonarqube-server') {
                        sh "${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=Netflix-React-Clone \
                            -Dsonar.sources=src/"
                    }
                }
            }
        }
        
        stage('5. Quality Gate') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🚦 *STAGE 5:* Sonarqube Quality Gate stage started...")
                script {
                    waitForQualityGate abortPipeline: true, credentialsId: 'sonarqube-token-id'
                }
            }
        }
        
        stage('6. OWASP Dependency-Check') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🛡️ *STAGE 6:* OWASP Dependency-Check stage started...")
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'owasp-dependency-check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        
        stage('7. Trivy FS Scan') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🔎 *STAGE 7:* Trivy FS Scan stage started...")
                sh "trivy fs . > trivyfs.txt"
            }
        }
              
        stage('8. Docker Build & Tag') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🐳 *STAGE 8:* Building Docker Image: ${IMAGE_NAME}:${TAG}...")
                // Securely pass the TMDB API key during the build
                sh "docker build --build-arg TMDB_V3_API_KEY=${TMDB_KEY} -t ${IMAGE_NAME}:${TAG} ."
                sh "docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:latest"
            }
        }
        
        stage('9. Trivy Image Scan') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🐋 *STAGE 9:* Trivy Image Scan stage started...")
                sh "trivy image ${IMAGE_NAME}:${TAG} > trivyimage.txt" 
            }
        }
        
        stage('10. Docker Push') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🚀 *STAGE 10:* Pushing Docker image to DockerHub...")
                script {
                    withDockerRegistry(credentialsId: 'dockerhub-credentials-id', toolName: 'docker-latest') {   
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                        sh "docker push ${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('11. Deploy to container') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "📦 *STAGE 11:* Deploying to local Docker container...")
                // Stops and removes the old container if it exists, so the port doesn't conflict on rebuilds
                sh 'docker rm -f netflix-app || true'
                // Added your requested deployment command using the dynamic variable
                sh "docker run -d --name netflix-app -p 8081:80 ${IMAGE_NAME}:latest"
            }
        }
        
        stage('12. Deploy to AWS EKS') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "☸️ *STAGE 12:* Deploying to AWS EKS...")
                
                withCredentials([string(credentialsId: 'tmdb-api-key', variable: 'SECURE_TMDB_KEY')]) {
                    sh """
                    # 1. Authorize Kubectl to communicate with the existing EKS cluster
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                    
                    # 2. Update the Kubernetes manifests
                    kubectl apply -f k8s/namespace.yaml

                    # Securely update the K8s Secret with the actual TMDB key
                    ENCODED_KEY=\$(echo -n "\$SECURE_TMDB_KEY" | base64)
                    sed -i "s|tmdb-key: \\"\\"|tmdb-key: \\"\$ENCODED_KEY\\"|g" k8s/deployment.yaml
                    
                    # Replace the dynamic placeholder with the exact new image tag
                    sed -i "s|image: .*|image: ${IMAGE_NAME}:${TAG}|g" k8s/deployment.yaml
                    
                    # Apply updated manifests to the namespace
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    """  
                }
            }
        }
    }
        
    post {
        always {
            slackSend(color: "${currentBuild.currentResult == 'SUCCESS' ? 'good' : 'danger'}", 
                      message: "DevSecOps Pipeline for '${env.JOB_NAME} [${env.BUILD_NUMBER}]' has completed with result: ${currentBuild.currentResult}.\nBuild URL: ${env.BUILD_URL}")
        }
    }
}
