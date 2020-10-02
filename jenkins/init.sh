
installJenkins() {
    version=$(cat /etc/*release* | grep ID_LIKE)
    case $version in
        *debian*)
            sudo apt install default-jdk
            wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
            sudo sh -c ‘echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list’
            sudo apt install jenkins
            ;;
        *centos*)
            sudo yum install java-1.8.0-openjdk.x86_64
            sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
            sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
            sudo yum install jenkins
            ;;
        *)
            echo "$version is not supported."
    esac
}


installJenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
# modify /etc/sudoers to allow jenkins to use docker and systemctl for docker
# jenkins ALL=NOPASSWD:/usr/bin/docker, /bin/systemctl start docker, /bin/systemctl status docker