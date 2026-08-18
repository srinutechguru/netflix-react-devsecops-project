pipeline {
    agent any

    tools {
        jdk 'jdk17'
        nodejs 'node18'
    }

    environment {
        // DockerHub configuration
        DOCKERHUB_CREDS = credentials('dockerhub-credentials-id')
        TMDB_KEY = credentials('tmdb-api-key')

        // Docker registry targeting
        IMAGE_NAME = "srinutechguru/netflix-react-clone"


        // GitHub GitOps Repository configuration
        GITOPS_REPO = "https://github.com/srinutechguru/netflix-react-gitops-deployment.git"

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

        // --- Image Tag CONFIGURATION STAGE ---
        stage('3. Generate Dynamic Version Tag') {
            steps {
			 slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🛠️ *STAGE 3:* Generating Dynamic Version Tag...")
                script {
                    // Extracts the first 7 characters of the latest Git commit hash
                    env.GIT_HASH = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    
                    // Combines the Jenkins Build Number with the Git Hash
                    env.TAG = "v${env.BUILD_NUMBER}-${env.GIT_HASH}"
                    
                    echo "========================================"
                    echo "Generated Production Tag: ${env.TAG}"
                    echo "========================================"
                }
            }
        }

        stage('4. Install Dependencies') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🛠️ *STAGE 4:* Downloading dependencies using NPM...")
                // Standardized on NPM
                sh "npm install"
            }
        }

        stage('5. SonarQube Code Analysis') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🔍 *STAGE 5:* Running SonarQube Static Application Security Testing (SAST)...")
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

        stage('6. Quality Gate') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🚦 *STAGE 6:* Sonarqube Quality Gate stage started...")
                script {
                    waitForQualityGate abortPipeline: true, credentialsId: 'sonarqube-token-id'
                }
            }
        }

        stage('7. OWASP Dependency-Check') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🛡️ *STAGE 7:* OWASP Dependency-Check stage started...")
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'owasp-dependency-check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }

        stage('8. Trivy FS Scan') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🔎 *STAGE 8:* Trivy FS Scan stage started...")
                sh "trivy fs . > trivyfs.txt"
            }
        }

        stage('9. Docker Build & Tag') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🐳 *STAGE 9:* Building Docker Image: ${IMAGE_NAME}:${env.TAG}...")
                // Securely pass the TMDB API key during the build
                sh "docker build --build-arg TMDB_V3_API_KEY=${TMDB_KEY} -t ${IMAGE_NAME}:${env.TAG} ."
                sh "docker tag ${IMAGE_NAME}:${env.TAG} ${IMAGE_NAME}:latest"
            }
        }

        stage('10. Trivy Image Scan') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🐋 *STAGE 10:* Trivy Image Scan stage started...")
                sh "trivy image ${IMAGE_NAME}:${TAG} > trivyimage.txt"
            }
        }

        stage('11. Docker Push') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "🚀 *STAGE 11:* Pushing Docker image to DockerHub...")
                script {
                    withDockerRegistry(credentialsId: 'dockerhub-credentials-id') {
                        sh "docker push ${IMAGE_NAME}:${env.TAG}"
                        sh "docker push ${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('12. Deploy to Local Container (Testing)') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "📦 *STAGE 12:* Deploying to local Docker container...")

                // Stops and removes the old container if it exists, so the port doesn't conflict on rebuilds
                sh 'docker rm -f netflix-app || true'

                 // Deployment command using the dynamic variable
                sh "docker run -d --name netflix-app -p 8081:80 ${IMAGE_NAME}:latest"
            }
        }

        stage('13.Update Manifests in GitOps Repo') {
            steps {
                slackSend(color: '#439FE0', channel: SLACK_CHANNEL, message: "☸️ *STAGE 13:* Updating Manifests in Gitops Repo with tag ${env.TAG}...")

                // Uses a GitHub Personal Access Token to commit back to the K8s repository
                // FIXED: Use 'string' binding because 'netflix-react-gitops-token' is a Secret text credential,
		// netflix-react-gitops-token with content read and write permission
                withCredentials([string(credentialsId: 'netflix-react-gitops-token', variable: 'GITHUB_TOKEN')]) {
                    sh """
                        # Configure Git identity for the automated commit
                        git config --global user.name "Jenkins Automation"
                        git config --global user.email "srinutechguru@gmail.com"

                        # Clone the infrastructure repository securely by injecting the token into the URL
                        git clone https://x-access-token:${GITHUB_TOKEN}@github.com/srinutechguru/netflix-react-gitops-deployment.git

                        cd netflix-react-gitops-deployment/k8s

                        # Use sed to dynamically update the deployment.yaml with the new image tag
                        sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${env.TAG}|g" deployment.yaml

                        # Commit and push the changes to trigger ArgoCD
                        git add deployment.yaml
                        git commit -m "chore: update netflix image tag to ${env.TAG} [skip ci]"
                        git push origin main
                    """
               }
            }
        } 
		
	} // <-- This closes 'stages''

    post {
        always {
            slackSend(color: "${currentBuild.currentResult == 'SUCCESS' ? 'good' : 'danger'}",
                      message: "DevSecOps Pipeline for '${env.JOB_NAME} [${env.BUILD_NUMBER}]' has completed with result: ${currentBuild.currentResult}.\nBuild URL: ${env.BUILD_URL}")
               }
           } // <-- This closes 'post'

    } // <-- This closes 'pipeline'
