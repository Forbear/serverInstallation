#! /bin/bash/
exec_mode=docker-build
config_file='configs/hiden_one_config.json'
output_dir='/tmp/apache-hiden-one/'
docker_mount_point='/etc/httpd/conf.d/'
docker_volume_name='apache-hiden-one-volume'
docker_network_name='apache-rp-network'
docker_container_name='apache-hiden-one'
docker_image_name='apache_hiden_ds'
docker_context='.'
docker_service_exposed=false
docker_target='hiden_point'
docker_service_replicas=1
