#! /bin/bash/
exec_mode=docker-full
config_file='configs/hiden_config.json'
output_dir='/tmp/apache-hiden/'
verbose=false
docker_mount_point='/etc/httpd/conf.d/'
docker_volume_name='apache-hiden-volume'
# docker_container_bind='8090:80'
docker_container_name='apache-hiden'
docker_image_name='apache_ds'
docker_context='.'
docker_container_exposed=false
