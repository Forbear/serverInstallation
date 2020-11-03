#! /bin/bash
# exec_mode=docker-init
docker_imported=true
docker_container_bind='8081:8081'
docker_service_name='nexus-repo'
docker_image_name='sonatype/nexus3'
docker_context='.'
docker_service_exposed=True
docker_service_replicas=1
