#!/bin/bash

# $1 - parameters
# $2 - file
updateCheckboxes() {
    local parameter_arr=($1)
    local ignored=($2)
    echo 'CheckboxParameter:' > $3
    if [[ "${#ignored[*]}" > 0 ]]; then
        for ignore in "${ignored[@]}"; do
            local parameter_arr=$(echo -e "(${parameter_arr[@]/$ignore})")
        done
    fi
    if [[ "${#parameter_arr[*]}" == 0 ]]; then
        local parameter_arr="None"
    fi
    for parameter in ${parameter_arr[@]}; do
        echo -e "  - key: $parameter\n    value: $parameter" >> $3
    done
}

available_services=""
available_files=""

ignored_services=("elasticsearch-service" "kibana-service" "logstash-service" "filebeat-service")
ignored_files=("elasticsearch.json" "logstash.json" "kibana.json" "filebeat.json")

is_docker_up=$(sudo systemctl is-active docker | grep -q "inactive" && echo "false" || echo "true")

if [[ $is_docker_up = "true" ]]; then
    available_services=$(sudo docker service ls --filter name=$docker_service_name --format='{{json .Name}}')
fi
updateCheckboxes "${available_services[*]}" "${ignored_services[*]}" "./jenkins/services.yaml"

available_files=$(ls ./available/)
updateCheckboxes "${available_files[*]}" "${ignored_files[*]}" "./jenkins/checkboxes.yaml"
