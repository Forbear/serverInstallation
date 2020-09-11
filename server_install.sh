#! /bin/bash

#################
### FUNCTIONS ###
#################
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
    if [ -d "$output_dir" ]; then
        mv $temp_file "${output_dir}${i}_server.conf"
        chmod 644 ${output_dir}${i}_server.conf
    else
        echo "$output_dir does not exist."
    fi
}

# docker container create --name apache-docker --mount source=apache-configuration,target=/etc/httpd/conf.d/ apache_ds
dockerCreate() {
    if [ -f "$docker_context/dockerfile" ]; then
        docker image build -t $docker_image_name $docker_context
        docker volume create $docker_volume_name
        docker container create \
            --name $docker_rp_name \
            --mount source=$docker_volume_name,target=$docker_mount_point \
            -p $docker_rp_server_bind \
            $docker_image_name
    else
        echo "dockerfile was not found."
    fi
}

dockerCopy() {
    if $verbose ; then
        echo "Copy files from $output_dir to docker container $docker_rp_name:$docker_mount_point."
    fi
    local conf_list=$(ls $output_dir)
    for file in $conf_list; do
        docker container cp $output_dir$file $docker_rp_name:$docker_mount_point$file
    done
}

dockerRun() {
    docker container start $docker_rp_name
}

dockerStop() {
    docker container stop $docker_rp_name
}

dockerDestroy() {
    dockerStop
    docker container rm $docker_rp_name
    docker volume rm $docker_volume_name
    docker image rm $docker_image_name
}

main() {
    servers=$(jq -r '. | keys | .[]' $1)
    for i in $servers; do
        local config=$(jq -c ".$i" $1)
        local temp_file=$(mktemp)

        blockInsert "$config" ""
        $2
    done
}

#########################
### DEFAULT VARIABLES ###
#########################
exec_mode=test
config_file=server_config.json
output_dir='/tmp/apache-rp-conf/'
tabs='    '
verbose=false
docker_mount_point='/etc/httpd/conf.d/'
docker_volume_name='apache-configuration'
docker_rp_server_bind='8080:80'
docker_rp_name='apache-docker'
docker_image_name='apache_ds'
docker_context='.'

########################
### SCTIPT EXECUTION ###
########################

while [ -n "$1" ]; do
    case $1 in
        -f)
            config_file="$2"
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

if [ -f "$config_file" ]; then
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
    # mod_ssl should be encluded if SSL is in use in json.
    case $exec_mode in
        test-apache-config)
            if $verbose ; then
                echo "Test mode."
                main "$config_file" testResult
            else
                main "$config_file" no_result
            fi
            ;;
        generate-apache-config)
            main "$config_file" moveResult
            ;;
        cp-config)
            dockerCopy
            ;;
        docker-init)
            dockerCreate
            ;;
        docker-run)
            # Spmewhere here docker image should be checked defore run.
            dockerRun
            ;;
        docker-stop)
            dockerStop
            ;;
        docker-rm)
            dockerDestroy
            ;;
        docker-full)
            main "$config_file" moveResult
            dockerCreate
            dockerCopy
            dockerRun
            ;;
        general)
            # Here should be docker installation implemented.
            sudo $packageManager install -y jq
            main "$config_file" moveResult
            ;;
        *)
            "Unexpected execute mode was selected. Error."
    esac
else
    echo "${config_file} was not found. Please make sure configuration file was named properly."
fi
