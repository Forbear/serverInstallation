#!/bin/bash

# $1 - parameters
# $2 - file
updateCheckboxes() {
    local parameter_arr=$1
    echo 'CheckboxParameter:' > $2
    if [[ "${#parameter_arr}" == 0 ]]; then
        local parameter_arr="None"
    fi
    for parameter in $parameter_arr; do
        echo -e "  - key: $parameter\n    value: $parameter" >> $2
    done
}

available_services=""

is_docker_up=$(sudo systemctl is-active docker | grep -q "inactive" && echo "false" || echo "true")

if [[ $is_docker_up = "true" ]]; then
    available_services=$(sudo docker service ls --filter name=$docker_service_name --format='{{json .Name}}')
fi
updateCheckboxes "$available_services" "./jenkins/services.yaml"

available_files=$(ls ./available/)
updateCheckboxes "$available_files" "./jenkins/checkboxes.yaml"
