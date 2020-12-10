#!/bin/bash

#################
### FUNCTIONS ###
#################

specifyPackageManager() {
    # Check Linux distro.
    version=$(cat /etc/*release* | grep ID_LIKE)
    case $version in
        *debian*)
            packageManager=apt-get
            ;;
        *centos*)
            packageManager=yum
            ;;
        *)
            echo "$version is not supported."
    esac
}

# $1 - config
# $2 - $key
# $3 - tabs
insertWithAffixes() {
    local fields=$(echo $1 | jq -rc ".$2")
    local preffix=$(echo $fields | jq -r ".preffix")
    local suffix=$(echo $fields | jq -r ".suffix")
    local comment=$(echo $fields | jq -r ".comment")
    local items=($(echo $fields | jq -r ".content | .[]"))
    local _tabs=$3

    if [[ "$preffix" != "null" ]]; then
        preffix="$preffix "
    else
        preffix=""
    fi

    if [[ "$suffix" != "null" ]]; then
        suffix=" $suffix"
    else
        suffix=""
    fi

    if [[ "${#items[@]}" > 0 ]]; then
        echo "$_tabs# $comment" >> $temp_file
        for item in ${items[@]}; do
            echo "$_tabs$preffix$item$suffix" >> $temp_file
        done
    fi
}

blockInsert() {
    local content=$(echo $1 | jq -r ".content")
    local preffix=$(echo $1 | jq -r ".preffix")
    local _tabs=$2
    # Other keys.
    local block_keys=$(echo $1 | jq -r "keys | .[]" | egrep -v "preffix|content")
    echo "$_tabs<$preffix $content>" >> $temp_file
    for key in $block_keys; do
        case $key in
            block*)
                local config=$(echo $1 | jq -c ".$key")
                blockInsert "$config" "$_tabs$tabs"
                ;;
            affix*)
                insertWithAffixes "$1" $key "$_tabs$tabs"
                ;;
            *)
                echo "$key is not supported"
        esac
    done
    echo "$_tabs</$preffix>" >> $temp_file
}

no_result() {
    rm $temp_file
}

testResult() {
    cat $temp_file
    rm $temp_file
}

moveResult() {
    local output_directory=$1
    if ! [ -d "$output_directory" ]; then
        mkdir $output_directory
    fi
    if [ -w "$1" ]; then
        mv $temp_file "${output_directory}${i}_server.conf"
        chmod 644 ${output_directory}${i}_server.conf
    else
        echo "Error to write in $output_directory."
    fi
}

getherFacts() {
    if [ "$verbose" = true ]; then
        echo "Gether facts."
    fi
    # Get docker images names.
    docker_images=$(sudo docker images --format='{{json .Repository}}')
    # Get docker volumes names.
    docker_volumes=$(sudo docker volume ls --format='{{json .Name}}')
    # Get docker networks names.
    docker_networks=$(sudo docker network ls --format='{{json .Name}}')
    if [ "$verbose" = true ]; then
        echo -e "Images:\n${docker_images[@]}\nVolumes:\n$docker_volumes\nNetworks:\n$docker_networks"
    fi
    factsGethered=true
}

checkDependenciesShell() {
    # Create docker image if it does not exist.
    if ! [[ "${docker_images[@]}" =~ "${docker_image_name}" ]]; then
        if [ "$docker_imported" = true ]; then
            sudo docker pull $docker_image_name
        else
            sudo docker image build --target $docker_target -t $docker_image_name $docker_context
        fi
    elif [[ "$quiet" = false ]]; then
        echo "Image $docker_image_name exists. Skip."
    fi
    # Create docker volume if it does not exist.
    if ! [[ "${docker_volumes[@]}" =~ "${docker_volume_name}" ]]; then
        sudo docker volume create $docker_volume_name
    elif [[ "$quiet" = false ]]; then
        echo "Volume $docker_volume_name exists. Skip."
    fi
    # Create docker network if it does not exist.
    if ! [[ "${docker_networks[@]}" =~ "${docker_network_name}" ]]; then
        sudo docker network create --attachable -d overlay $docker_network_name
    elif [[ "$quiet" = false ]]; then
        echo "Network $docker_network_name exists. Skip."
    fi
}

initiateDependencies() {
    if [ $factsGethered = true ]; then
        case $dependencies_source in
            shell)
                checkDependenciesShell
                ;;
            *)
                echo "Error #004."
        esac
    else
        echo "Facts were not gethered. Issues expected :)"
    fi
}

createServiceShell() {
    initiateDependencies
    # Create initial service. Will be updated with all dependencies below.
    sudo docker service create -q \
        --name $docker_service_name \
        --replicas 0 \
        $docker_image_name
    # Udate service if network specified.
    if [[ "${#docker_network_name}" > 0 ]]; then
        sudo docker service update -q $docker_service_name \
            --network-add $docker_network_name
    fi
    # Udate service if mount specified.
    if [[ "${#docker_mount_point}" > 0 ]]; then
        sudo docker service update -q $docker_service_name \
            --mount-add source=$docker_volume_name,target=$docker_mount_point
    fi
    # Update service if publisj specified.
    if [[ "${#docker_container_bind}" > 0 ]]; then
        sudo docker service update -q $docker_service_name \
            --publish-add $docker_container_bind
    fi
    sudo docker service update -q $docker_service_name \
        --replicas $docker_service_replicas
}

createServiceJson() {
    local config_json=$json_source
    local service_image=""
    local volumes=""
    local service_config_dir=""
    local config_keys_json=$(echo $config_json | jq -r 'keys | .[]')
    local service_line="sudo docker service create -q"
    for config_item in ${config_keys_json[@]}; do
        local parameter=$(echo $config_json | jq -r ".$config_item")
        case $config_item in
            docker_service_bind)
                local service_line="$service_line -p $parameter"
                ;;
            docker_service_name)
                local service_line="$service_line --name $parameter"
                ;;
            # docker_service_replicas)
            #     local service_line="$service_line --replicas $parameter"
            #     ;;
            docker_service_mount)
                local volumes=($(echo $parameter | jq -r '. | keys | .[]'))
                if [[ "${#volumes[@]}" > 1 ]]; then
                    for volume in ${volumes[@]}; do
                        if ! [[ "${docker_volumes[@]}" =~ "$volume" ]]; then
                            echo "Docker volume $volume was not found. Creating..."
                            sudo docker volume create $volume
                        elif [[ "$quiet" = false ]]; then
                            echo "Docker volume $volumes exists. Skip."
                        fi
                        local target=$(echo $parameter | jq -r ".$volume")
                        local service_line="$service_line --mount source=$volume,destination=$target"
                    done
                    local volumes=${volumes[0]}
                else
                    if ! [[ "${docker_volumes[@]}" =~ "$volumes" ]]; then
                        echo "Docker volume $volumes was not found. Creating..."
                        sudo docker volume create $volumes
                    elif [[ "$quiet" = false ]]; then
                        echo "Docker volume $volumes exists. Skip."
                    fi
                    local parameter=$(echo $parameter | jq -r '.[]')
                    local service_line="$service_line --mount source=$volumes,destination=$parameter"
                fi
                ;;
            docker_service_mode)
                local service_mode=$(echo $parameter | jq -r 'keys | .[]')
                case $service_mode in
                    replicated)
                        local service_replicas=$(echo $parameter | jq -r '. | .[]')
                        local service_line="$service_line --mode $service_mode --replicas $service_replicas"
                        ;;
                    global)
                        local service_line="$service_line --mode $service_mode"
                        ;;
                    *)
                        echo "Service_mode error #006."
                esac
                ;;
            docker_service_image)
                local image_target=$(echo $parameter | jq -r 'keys | .[]')
                local service_image=$(echo $parameter | jq -r '. | .[]')
                if [[ "$image_target" = "imported" ]]; then
                    local service_tag=$(echo $service_image | jq -r '. | .[]')
                    local service_image="$(echo $service_image | jq -r 'keys | .[]')"
                    if ! [[ "${docker_images[@]}" =~ "$service_image" ]]; then
                        echo "Docker image $service_image:$service_tag was not found. Pulling..."
                        sudo docker pull $service_image:$service_tag
                    elif [[ "$quiet" = false ]]; then
                        echo "Docker image $service_image:$service_tag exists. Skip."
                    fi
                    local service_image="$service_image:$service_tag"
                else
                    if ! [[ "${docker_images[@]}" =~ "$service_image" ]]; then
                        echo "Docker image $service_image was not found. Creating..."
                        sudo docker image build -q --target $image_target -t $service_image $docker_context
                    elif [[ "$quiet" = false ]]; then
                        echo "Docker image $service_image exists. Skip."
                    fi
                fi
                ;;
            docker_service_network)
                if ! [[ "${docker_networks[@]}" =~ "$parameter" ]]; then
                    echo "Network $parameter was not found. Creating..."
                    sudo docker network create --attachable -d overlay $parameter
                elif [[ "$quiet" = false ]]; then
                    echo "Docker network $parameter exists. Skip."
                fi
                local service_line="$service_line --network $parameter"
                ;;
            docker_service_user)
                local service_line="$service_line --user $parameter"
                ;;
            make_apache_config)
                local config_file=$(echo $parameter | jq -rc 'keys | .[]')
                local service_config_dir=$(echo $parameter | jq -r '. | .[]')
                makeConfig "$config_file" moveResult "$service_config_dir"
                ;;
            copy_to_volume)
                local service_config_dir=$parameter
                ;;
            external_*)
                local service_line="$service_line -e $parameter"
                ;;
            exec_mode)
                if [[ "$verbose" = true ]]; then
                    echo "exec_mode is selected as $parameter."
                fi
                ;;
            docker_*)
                ;;
            *)
                echo "json template parse error #003. $config_item was not recognized."
        esac
    done
    if [[ "$volumes" != "" ]] && [[ "$service_config_dir" != "" ]]; then
        local base_image_created=false
        if ! [[ "${docker_images[@]}" =~ "base_image_ds" ]]; then
            sudo docker image build --target base -t base_image_ds .
            local base_image_created=true
        else
            local base_image_created=true
        fi
        if [[ "$base_image_created" = true ]]; then
            sudo docker container create --name base_container_ds \
                --mount source=$volumes,target=/opt/ \
                base_image_ds
            local base_container_created=true
        fi
        if [[ "$base_container_created" = true ]]; then
            local conf_list=$(ls $service_config_dir)
            if [[ "$quiet" = false ]]; then
                echo -e "Files to copy: $conf_list\nVolume is: $volumes"
            fi
            for file in $conf_list; do
                sudo docker container cp $service_config_dir$file base_container_ds:/opt/$file
            done
        fi
        if [[ "$base_container_created" = true ]]; then
            sudo docker container rm base_container_ds
        fi
    fi
    if ! [[ "$service_image" = "" ]]; then
        local service_line="$service_line $service_image"
        if [[ "$quiet" = false ]]; then
            echo "Service line:"
            echo $service_line
        fi
        $service_line
    fi
}

createDockerService() {
    if [ -f "$docker_context/dockerfile" ]; then
        case $dependencies_source in
            shell)
                createServiceShell
                ;;
            json)
                createServiceJson
                ;;
            *)
                echo "Error #005."
        esac
    else
        echo "dockerfile was not found. Error #002."
    fi
}

copyToDockerVolume() {
    local base_image_created=false
    local base_container_created=false
    if [ "$verbose" = true ]; then
        echo "Copy files from $output_dir to docker container $docker_service_name:$docker_mount_point."
    fi
    if ! [[ "${docker_images[@]}" =~ "base_image_ds" ]]; then
        sudo docker image build --target base -t base_image_ds $docker_context
        local base_image_created=true
    else
        local base_image_created=true
    fi
    if [[ "$base_image_created" = true ]]; then
        sudo docker container create --name base_container_ds \
            --mount source=$docker_volume_name,target=$docker_mount_point \
            base_image_ds
        local base_container_created=true
    fi
    local conf_list=$(ls $output_dir)
    for file in $conf_list; do
        sudo docker container cp $output_dir$file base_container_ds:$docker_mount_point$file
    done
    if [[ "$base_container_created" = true ]]; then
        sudo docker container rm base_container_ds
    fi
}

stopDockerService() {
    sudo docker service rm $docker_service_name
}

# Out of date function. Should be changed.
destroyDocker() {
    stopDockerService
    echo "10s service termanate wait."
    sleep 10
    # Block below should be executed only if those
    # dependencies are not in use!!!
    sudo docker network rm $docker_network_name
    sudo docker volume rm $docker_volume_name
    sudo docker image rm $docker_image_name
}

dockerUpdateReplicas() {
    # Here is check for current replicas number also can be implemented.
    local selected_service_info=$(sudo docker service ls --filter name=$docker_service_name --format='{{json .}}')
    if [[ "$selected_service_info" = "" ]]; then
        echo "$docker_service_name was not found."
    else
        sudo docker service update -q --replicas=$docker_service_replicas $docker_service_name
    fi
}

makeConfig() {
    case $1 in
        # Jenerate config from JSON file.
        *.json)
            local servers=$(jq -r '. | keys | .[]' $1)
            for i in $servers; do
                local config=$(jq -c ".$i" $1)
                local temp_file=$(mktemp)

                blockInsert "$config" ""
                if [[ "$2" = "moveResult" ]]; then
                    $2 $3
                else
                    $2
                fi
            done
            ;;
        *)
            echo "Specified config file extention is not supported."
    esac
}

update_json_with_external() {
    local config_json=$1
    local external=$2
    local external_json_keys=$(echo $external | jq -r 'keys | .[]')
    for key in $external_json_keys; do
        local parameter=$(echo $external | jq -r '. | .[]')
        local config_json=$(echo $config_json | jq ".$key = \"$parameter\"")
    done
    echo $config_json
}

executeScript() {
    if [ -f $config_file ]; then
        # mod_ssl should be encluded if SSL is in use in json.
        case $exec_mode in
            test-config)
                if [ "$verbose" = true ]; then
                    echo "Test mode."
                    makeConfig "$config_file" testResult
                else
                    makeConfig "$config_file" no_result
                fi
                ;;
            prerun)
                getherFacts
                ;;
            generate-config)
                makeConfig "$config_file" moveResult $output_dir
                ;;
            cp-config)
                copyToDockerVolume
                ;;
            docker-init)
                getherFacts
                createDockerService
                ;;
            docker-stop)
                getherFacts
                stopDockerService
                ;;
            docker-rm)
                # Out of date.
                # destroyDocker
                ;;
            docker-build)
                makeConfig "$config_file" moveResult $output_dir
                getherFacts
                copyToDockerVolume
                createDockerService
                ;;
            docker-update-replicas)
                dockerUpdateReplicas
                ;;
            general)
                # Here should be docker installation implemented.
                specifyPackageManager
                sudo $packageManager install -y -q jq
                makeConfig "$config_file" moveResult $output_dir
                ;;
            *)
                if [[ "$verbose" = true ]]; then
                    echo "$exec_mode"
                fi
                echo "Unexpected execute mode ($exec_mode) was selected. Error #001."
        esac
    else
        echo "$config_file was not found. Please make sure configuration file was named properly."
    fi
}

#########################
### DEFAULT VARIABLES ###
#########################
tabs='    '
from_file=true
factsGethered=false
quiet=false

########################
### SCTIPT EXECUTION ###
########################

# Parameters parsing
while [ -n "$1" ]; do
    case $1 in
        -c)
            config_file="$2"
            shift
            ;;
        -d)
            docker_context="$2"
            shift
            ;;
        -ej)
            external_json="$2"
            shift
            ;;
        -j)
            from_file=false
            ;;
        -f)
            variables_init="$2"
            shift
            ;;
        -m)
            exec_mode="$2"
            shift
            ;;
        -o)
            ###### !!! ######
            # Somewhere this dir should be checked for RW access.
            ###### !!! ######
            output_dir="$2"
            shift
            ;;
        -q)
            quiet=true
            ;;
        -sn)
            docker_service_name="$2"
            shift
            ;;
        -sr)
            docker_service_replicas="$2"
            shift
            ;;
        -v)
            # Toggle verbose mode. Disabled by default.
            verbose=true
            ;;
        *)
            echo -e "Option $1 was not found."
            exec_mode='error'
    esac
    shift
done

if  $from_file ; then
    activeList=$(ls active/ | egrep '(\.sh|\.json)')
    if [ "$verbose" = true ]; then
        echo -e "Active list:\n$activeList\n"
    fi
    if [[ "${#activeList[@]}" > 0 ]]; then
        for set in ${activeList[@]}; do
            case $set in
                *.sh)
                    # Define dependencies check.
                    dependencies_source="shell"
                    # Import defined variables.
                    source active/$set
                    # Execute script according to variables.
                    executeScript
                    ;;
                *.json)
                    # Define dependencies check.
                    dependencies_source="json"
                    config_key=$(echo $set | sed -E 's/(.*)\.(sh|json)/\1/')
                    json_source=$(cat active/$set)
                    if [[ "$external_json" != "" ]]; then
                        external_json_value=$(echo $external_json | jq -r ".$config_key")
                        json_source=$(update_json_with_external "$json_source" "$external_json_value")
                    fi
                    docker_context=$(echo $json_source | jq -r '.docker_context')
                    exec_mode=$(echo $json_source | jq -r '.exec_mode')
                    executeScript
                    ;;
                *)
                    echo "active/$set file format is not recognized."
            esac
        done
    else
        echo "Active variables are not set."
    fi
else
    # Was not tested.
    echo 'Manual variables input.'
    # Example.
    # ./server_install.sh -j -m docker-build -c configs/default_config.json
    executeScript
fi
