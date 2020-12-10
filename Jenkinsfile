properties([
    parameters([
        choice(
            name: 'ACTIVITY',
            choices: ["None", "docker-init", "docker-stop", "docker-update-replicas", "up-ELK"],
            description: 'Activity to perform.'
        ),
        booleanParam(
            name: 'UPDATE_CHECKBOXES',
            defaultValue: true,
            description: 'Update checkboxes with available configuration.'
        ),
        booleanParam(
            name: 'SHOW_SERVICES_STATE',
            defaultValue: true,
            description: 'Enable services ls after all.'
        ),
        booleanParam(
            name: 'RUN_SONAR',
            defaultValue: false,
            description: 'Enable sonarqube service-check.'
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
        SECRET_SONAR_TOKEN = credentials('sonarToken')
        SECRET_SONAR_PASSWD = credentials('sonarAdminPassword')
        NEXUS_VERSION = "nexus3"
        NEXUS_PROTOCOL = "http"
        NEXUS_URL = "127.0.0.1:8081"
        NEXUS_REPOSITORY = "serverInstall_repo"
        NEXUS_CREDENTIAL_ID = "nexusJenkinsUser"
    }
    stages {
        stage('Build/Stop docker service.') {
            when {
                expression {
                    env.isDockerUp == 'true' && params.ACTIVITY ==~ /docker-(stop|init)/
                }
            }
            steps {
                script {
                    def configs = params.AVAILABLE_CONFIGURATION.split(',')
                    for (config in configs) {
                        sh "./enable.sh ${config}"
                        if (config.contains("sonar")) {
                            sh """./server_install.sh \
                                -ej "{ "sonar": { "external_02": "SONAR_JDBC_PASSWORD=${env.SECRET_SONAR_PASSWD}" } }"
                            """
                        } else {
                            sh "./server_install.sh"
                        }
                        sh "./disable.sh ${config}"
                    }
                }
            }
        }
        stage('Up ELK stack.') {
            when { expression { params.ACTIVITY == 'up-ELK' } }
            steps {
                script {
                    def elk_arr = ["elasticsearch.json", "logstash.json", "kibana.json", "filebeat.json"]
                    for (component in elk_arr) {
                        sh "./enable.sh ${component}"
                        sh "./server_install.sh"
                        sh "./disable.sh ${component}"
                        sh "sleep 3"
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
                    if (configs.size() > 1) {
                        for (config in configs) {
                            sh "./server_install.sh -j -m ${params.ACTIVITY} -sn ${config} -sr ${params.REPLICAS}"
                        }
                    } else {
                        sh "./server_install.sh -j -m ${params.ACTIVITY} -sn ${configs} -sr ${params.REPLICAS}"
                    }
                }
            }    
        }
        stage('Update available checkboxes.') {
            when {
                expression { params.UPDATE_CHECKBOXES }
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
        stage('Sonar') {
            when {
                expression { params.RUN_SONAR }
            }
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withSonarQubeEnv {
                        sh """${scannerHome}/bin/sonar-scanner -X \
                            -Dsonar.projectKey=serverInstall \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=${env.SONAR_HOST_URL} \
                            -Dsonar.login=${env.SECRET_SONAR_TOKEN}
                        """
                    }
                }
            }
        }
        stage('Collect artifacts.') {
            steps {
                nexusArtifactUploader (
                    nexusVersion: NEXUS_VERSION,
                    protocol: NEXUS_PROTOCOL,
                    nexusUrl: NEXUS_URL,
                    version: BUILD_NUMBER,
                    groupId: "test",
                    repository: NEXUS_REPOSITORY,
                    credentialsId: NEXUS_CREDENTIAL_ID,
                    artifacts:[
                        [artifactId: "artifactId",
                        classifier: "debug",
                        file: "server_install.sh",
                        type: "shell"]
                    ]
                )
            }
        }
    }
}
