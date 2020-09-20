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

# docker container create --name apache-docker --mount source=apache-configuration,target=/etc/httpd/conf.d/ apache_ds
createDockerContainer() {
    if [ -f "$docker_context/dockerfile" ]; then
        docker image build --target $docker_target -t $docker_image_name $docker_context
        docker volume create $docker_volume_name
        docker network create --attachable $docker_network_name
        if $docker_container_exposed ; then
            docker container create --rm \
                --name $docker_container_name \
                --mount source=$docker_volume_name,target=$docker_mount_point \
                -p $docker_container_bind \
                --network $docker_network_name \
                $docker_image_name
        else
            docker container create --rm \
                --name $docker_container_name \
                --mount source=$docker_volume_name,target=$docker_mount_point \
                --network $docker_network_name \
                $docker_image_name
        fi
    else
        echo "dockerfile was not found."
    fi
}

copyToDockerVolume() {
    if $verbose ; then
        echo "Copy files from $output_dir to docker container $docker_container_name:$docker_mount_point."
    fi
    local conf_list=$(ls $output_dir)
    for file in $conf_list; do
        docker container cp $output_dir$file $docker_container_name:$docker_mount_point$file
    done
}

dockerRun() {
    docker container start $docker_container_name
}

stopDocker() {
    docker container stop $docker_container_name
}

destroyDocker() {
    stopDocker
    docker container rm $docker_container_name
    docker volume rm $docker_volume_name
    docker image rm $docker_image_name
}

getDockerStructure() {
    # Get docker images names.
    docker_versions=$(docker images --format='{{json .Repository}}')
    # Get docker volumes names.
    docker_volumes=$(docker volume ls --format='{{json .Name}}')
    # Get docker networks names.
    docker_networks=$(docker network ls --format='{{json .Name}}')
    echo -e "$docker_versions \n $docker_volumes \n $docker_networks"
}

makeApacheConfig() {
    servers=$(jq -r '. | keys | .[]' $1)
    for i in $servers; do
        local config=$(jq -c ".$i" $1)
        local temp_file=$(mktemp)

        blockInsert "$config" ""
        $2
    done
}

executeScript() {
    if [ -f $config_file ]; then
        # mod_ssl should be encluded if SSL is in use in json.
        case $exec_mode in
            test-apache-config)
                if $verbose ; then
                    echo "Test mode."
                    makeApacheConfig "$config_file" testResult
                else
                    makeApacheConfig "$config_file" no_result
                fi
                ;;
            prerun)
                getDockerStructure
                ;;
            generate-apache-config)
                makeApacheConfig "$config_file" moveResult
                ;;
            cp-config)
                copyToDockerVolume
                ;;
            docker-init)
                getDockerStructure
                createDockerContainer
                ;;
            docker-run)
                getDockerStructure
                # Spmewhere here docker image should be checked defore run.
                dockerRun
                ;;
            docker-stop)
                getDockerStructure
                stopDocker
                ;;
            docker-rm)
                destroyDocker
                ;;
            docker-full)
                makeApacheConfig "$config_file" moveResult
                # getDockerStructure
                createDockerContainer
                copyToDockerVolume
                dockerRun
                ;;
            general)
                # Here should be docker installation implemented.
                specifyPackageManager
                sudo $packageManager install -y -q jq
                makeApacheConfig "$config_file" moveResult
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

########################
### SCTIPT EXECUTION ###
########################

# Parameters parsing
while [ -n "$1" ]; do
    case $1 in
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
        -v)
            # Toggle verbose mode. Disabled by default.
            verbose=true
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
    # executeScript
    echo 'Manual variables input.'
fi
