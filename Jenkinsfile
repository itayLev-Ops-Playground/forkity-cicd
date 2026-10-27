pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        // Compose requires this value to be present during config/build.
        // The CI pipeline does not start or connect to PostgreSQL.
        POSTGRES_DB = 'forkity_ci'
        POSTGRES_USER = 'forkity_ci'
        POSTGRES_PASSWORD = 'ci-only-unused-password'
        FORKITY_PORT = '8080'
    }

    stages {
        stage('Verify Jenkins agent') {
            steps {
                sh 'bash scripts/verify-jenkins-ubuntu24.sh'
            }
        }

        stage('Install dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Build frontend') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Validate Compose') {
            steps {
                sh 'docker compose config --quiet'
            }
        }

        stage('Build container images') {
            steps {
                sh 'docker compose build'
            }
        }
    }
}
