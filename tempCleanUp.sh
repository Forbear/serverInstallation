#! /bin/bash
docker service rm apache-exposed
docker service rm apache-hiden-one
docker service rm apache-hiden-zero
echo "6s service termanate wait."
sleep 6
docker network rm apache-rp-network
docker volume rm apache-exposed-volume
docker volume rm apache-hiden-one-volume
docker volume rm apache-hiden-zero-volume
docker container prune -f
