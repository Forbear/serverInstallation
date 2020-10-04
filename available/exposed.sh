#! /bin/bash/
exec_mode=docker-build
config_file='configs/exposed_config.json'
output_dir='/tmp/apache-exposed/'
docker_mount_point='/etc/httpd/conf.d/'
docker_volume_name='apache-exposed-volume'
docker_network_name='apache-rp-network'
docker_container_bind='80:80'
docker_container_name='apache-exposed'
docker_image_name='apache_ds'
docker_context='.'
docker_service_exposed=true
docker_target='proxy_point'
docker_service_replicas=1
