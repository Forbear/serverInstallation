#! /bin/bash
docker service rm apache-exposed
docker service rm apache-hiden-one
docker service rm apache-hiden-zero
echo "10s service termanate wait."
sleep 10
docker network rm apache-rp-network
docker volume rm apache-exposed-volume
docker volume rm apache-hiden-one-volume
docker volume rm apache-hiden-zero-volume
docker container prune -f
if [[ "$1" = "full" ]]; then
    docker image rm apache_ds
    docker image rm apache_hiden_ds
    docker image rm base_image_ds
fi
