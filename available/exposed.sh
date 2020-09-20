#! /bin/bash/
exec_mode=docker-full
config_file='configs/exposed_config.json'
output_dir='/tmp/apache-exposed/'
verbose=false
docker_mount_point='/etc/httpd/conf.d/'
docker_volume_name='apache-exposed-volume'
docker_network_name='apache-rp-network'
docker_container_bind='80:80'
docker_container_name='apache-exposed'
docker_image_name='apache_ds'
docker_context='.'
docker_container_exposed=true
docker_target='proxy_point'
