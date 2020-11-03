properties([
    parameters([
        choice(
            name: 'ACTIVITY',
            choices: ["None", "docker-init", "docker-build", "docker-stop", "docker-update-replicas"],
            description: 'Activity to perform.'
        ),
        choice(
            name: 'UPDATE_CHECKBOXES',
            choices: ["Yes", "No"],
            description: 'Update checkboxes with available configuration.'
        ),
        booleanParam(
            name: 'SHOW_SERVICES_STATE',
            defaultValue: true,
            description: 'Enable services ls after all.'
        ),
        checkboxParameter(
            name: 'AVAILABLE_CONFIGURATION',
            format: 'YAML',
            protocol: 'FILE_PATH',
            uri: "/var/lib/jenkins/workspace/${env.JOB_BASE_NAME}/jenkins/checkboxes.yaml"
        ),
        checkboxParameter(
            name: 'AVAILABLE_SERVICES',
            format: 'YAML',
            protocol: 'FILE_PATH',
            uri: "/var/lib/jenkins/workspace/${env.JOB_BASE_NAME}/jenkins/services.yaml"
        ),
        string(
            name: 'REPLICAS',
            defaultValue: '1',
            description: 'Number of replicas for selected service.'
        )
    ])
])

pipeline {
    agent any
    environment {
        isDockerUp = """${sh(
            returnStdout: true,
            script: 'sudo systemctl is-active docker | grep -q "inactive" && echo -n "false" || echo -n "true"'
        )}"""
    }
    stages {
        stage('Build/Stop docker service.') {
            when {
                expression {
                    env.isDockerUp == 'true' && params.ACTIVITY ==~ /docker-(build|stop|init)/
                }
            }
            steps {
                script {
                    def configs = params.AVAILABLE_CONFIGURATION.split(',')
                    for (config in configs) {
                        sh "./enable.sh ${config}"
                    }
                    sh "./server_install.sh -m ${params.ACTIVITY}"
                    for (config in configs) {
                        sh "./disable.sh ${config}"
                    }
                }
            }
        }
        stage('Update docker service.') {
            when {
                expression {
                    env.isDockerUp == 'true' && params.ACTIVITY ==~ /docker-update-replicas/
                }
            }
            steps {
                script {
                    def configs = params.AVAILABLE_SERVICES.split(',')
                    for (config in configs) {
                        sh "./server_install.sh -j -m ${params.ACTIVITY} -sn ${config} -sr ${params.REPLICAS}"
                    }
                }
            }    
        }
        stage('Update available checkboxes.') {
            when {
                expression { params.UPDATE_CHECKBOXES == 'Yes' }
            }
            steps {
                sh "$WORKSPACE/jenkins/updateCheckBoxes.sh"
            }
        }
        stage('Show services state.') {
            when {
                expression { env.isDockerUp == 'true' && params.SHOW_SERVICES_STATE }
            }
            steps {
                sh 'sudo docker service ls'
            }
        }
        stage('Collect artifacts.') {
            steps {
                archiveArtifacts artifacts: 'jenkins/checkboxes.yaml', followSymlinks: false
            }
        }
    }
}
