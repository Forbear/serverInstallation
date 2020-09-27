#! /bin/bash/
exec_mode=docker-full
config_file='configs/default_config.json'
output_dir='/tmp/apache-rp-conf/'
verbose=false
docker_mount_point='/etc/httpd/conf.d/'
docker_volume_name='apache-configuration'
docker_container_bind='8080:80'
docker_container_name='apache-docker'
docker_image_name='apache_ds'
docker_context='.'
docker_container_exposed=true