#! /bin/bash
docker container stop apache-exposed
docker container stop apache-hiden-one
docker container stop apache-hiden-zero
docker network rm apache-rp-network
docker volume rm apache-exposed-volume
docker volume rm apache-hiden-one-volume
docker volume rm apache-hiden-zero-volume
