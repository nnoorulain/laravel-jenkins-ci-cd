pipeline {
    agent any
    options {
        skipDefaultCheckout()
        disableConcurrentBuilds()
        timeout(time: 15, unit: 'MINUTES')
    }
    triggers {
        pollSCM('H/2 * * * *')
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Install dependencies') {
            steps {
                bat 'composer install --no-interaction --prefer-dist --no-progress'
            }
        }
        stage('Prepare tests') {
            steps {
                bat '''
                    copy /Y .env.example .env
                    if errorlevel 1 exit /b 1
                    php artisan key:generate --no-interaction
                '''
            }
        }
        stage('Run tests') {
            steps {
                bat 'php artisan test'
            }
        }
        stage('Prepare release') {
            steps {
                bat 'powershell -NoProfile -File ci/release.ps1 Prepare'
            }
        }
        stage('Deploy') {
            steps {
                bat 'powershell -NoProfile -File ci/release.ps1 Activate'
            }
        }
        stage('Health check') {
            steps {
                bat 'powershell -NoProfile -File ci/release.ps1 Verify'
            }
        }
    }
    post {
        success {
            echo 'The tested release is running locally.'
        }
        failure {
            echo 'Open the failed stage log for details.'
        }
        unsuccessful {
            bat 'powershell -NoProfile -File ci/release.ps1 Recover'
        }
    }
}
