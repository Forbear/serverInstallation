#! /bin/bash

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
    if ! [ -d "$output_dir" ]; then
        mkdir $output_dir
    fi
    if [ -w "$output_dir" ]; then
        mv $temp_file "${output_dir}${i}_server.conf"
        chmod 644 ${output_dir}${i}_server.conf
    else
        echo "Error to write in $output_dir."
    fi
}

initiateDependencies() {
    if [ $factsGethered = true ]; then
        # Create docker image if it does not exist.
        if ! [[ "${docker_images[@]}" =~ "${docker_image_name}" ]]; then
            docker image build --target $docker_target -t $docker_image_name $docker_context
        elif [[ "$quite" = false ]]; then
            echo "Image $docker_image_name exists. Skip."
        fi
        # Create docker volume if it does not exist.
        if ! [[ "${docker_volumes[@]}" =~ "${docker_volume_name}" ]]; then
            docker volume create $docker_volume_name
        elif [[ "$quite" = false ]]; then
            echo "Volume $docker_volume_name exists. Skip."
        fi
        # Create docker network if it does not exist.
        if ! [[ "${docker_networks[@]}" =~ "${docker_network_name}" ]]; then
            docker network create --attachable -d overlay $docker_network_name
        elif [[ "$quite" = false ]]; then
            echo "Network $docker_network_name exists. Skip."
        fi
    else
        echo "Facts were not gethered. Issues expected :)"
    fi
}

createDockerService() {
    if [ -f "$docker_context/dockerfile" ]; then
        if $docker_service_exposed ; then
            docker service create \
                --name $docker_container_name \
                --mount source=$docker_volume_name,target=$docker_mount_point \
                -p $docker_container_bind \
                --network $docker_network_name \
                --replicas $docker_service_replicas \
                $docker_image_name
        else
            docker service create \
                --name $docker_container_name \
                --mount source=$docker_volume_name,target=$docker_mount_point \
                --network $docker_network_name \
                --replicas $docker_service_replicas \
                $docker_image_name
        fi
    else
        echo "dockerfile was not found."
    fi
}

copyToDockerVolume() {
    local base_image_created=false
    local base_container_created=false
    if [ "$verbose" = true ]; then
        echo "Copy files from $output_dir to docker container $docker_container_name:$docker_mount_point."
    fi
    if ! [[ "${docker_images[@]}" =~ "base_image_ds" ]]; then
        docker image build --target base -t base_image_ds $docker_context
        base_image_created=true
    else
        base_image_created=true
    fi
    if [[ "$base_image_created" = true ]]; then
        docker container create --name base_container_ds \
            --mount source=$docker_volume_name,target=$docker_mount_point \
            base_image_ds
        base_container_created=true
    fi
    local conf_list=$(ls $output_dir)
    for file in $conf_list; do
        docker container cp $output_dir$file base_container_ds:$docker_mount_point$file
    done
    if [[ "$base_container_created" = true ]]; then
        docker container rm base_container_ds
    fi
}

# Out of date.
stopDocker() {
    docker container stop $docker_container_name
}

# Out of date function. Should be changed.
destroyDocker() {
    stopDocker
    docker container rm $docker_container_name
    docker volume rm $docker_volume_name
    docker image rm $docker_image_name
}

getherFacts() {
    if [ "$verbose" = true ]; then
        echo "Gether facts."
    fi
    # Get docker images names.
    docker_images=$(docker images --format='{{json .Repository}}')
    # Get docker volumes names.
    docker_volumes=$(docker volume ls --format='{{json .Name}}')
    # Get docker networks names.
    docker_networks=$(docker network ls --format='{{json .Name}}')
    if [ "$verbose" = true ]; then
        echo -e "Images:\n${docker_images[@]}\nVolumes:\n$docker_volumes\nNetworks:\n$docker_networks"
    fi
    factsGethered=true
}

makeConfig() {
    case $1 in
        # Jenerate config from JSON file.
        *.json)
            servers=$(jq -r '. | keys | .[]' $1)
            for i in $servers; do
                local config=$(jq -c ".$i" $1)
                local temp_file=$(mktemp)

                blockInsert "$config" ""
                $2
            done
            ;;
        *)
            echo "Specified config file extention is not supported."
    esac
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
                initiateDependencies
                ;;
            generate-config)
                makeConfig "$config_file" moveResult
                ;;
            cp-config)
                copyToDockerVolume
                ;;
            docker-init)
                getherFacts
                initiateDependencies
                createDockerService
                ;;
            docker-stop)
                getherFacts
                # Out of date.
                # stopDocker
                ;;
            docker-rm)
                # Out of date.
                # destroyDocker
                ;;
            docker-build)
                makeConfig "$config_file" moveResult
                getherFacts
                initiateDependencies
                copyToDockerVolume
                createDockerService
                ;;
            general)
                # Here should be docker installation implemented.
                specifyPackageManager
                sudo $packageManager install -y -q jq
                makeConfig "$config_file" moveResult
                ;;
            *)
                echo "Unexpected execute mode was selected. Error."
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
quite=false

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
        -j)
            from_file=false
            shift
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
            quite=true
            shift
            ;;
        -v)
            # Toggle verbose mode. Disabled by default.
            verbose=true
            shift
            ;;
        *)
            echo "help?"
            exec_mode='error'
    esac
    shift
done

if  $from_file ; then
    activeList=$(ls active/)
    if [[ "${#activeList[@]}" > 0 ]]; then
        for set in ${activeList[@]}; do
            # Import defined variables.
            source active/$set
            # Execute script according to variables.
            executeScript
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
