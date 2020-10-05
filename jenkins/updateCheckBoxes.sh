#! /bin/bash

# $1 - parameters
# $2 - file
updateCheckboxes() {
    echo 'CheckboxParameter:' > $2
    for parameter in $1; do
        echo -e "  - key: $parameter\n    value: $parameter" >> $2
    done
}

available_files=$(ls ./available/)
available_services=$(sudo docker service ls --filter name=$docker_service_name --format='{{json .Name}}')

updateCheckboxes "$available_files" "./jenkins/checkboxes.yaml"
updateCheckboxes "$available_services" "./jenkins/services.yaml"
