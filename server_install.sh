#! /bin/bash

#################
### FUNCTIONS ###
#################
# $1 - config
# $2 - $key
# $3 - tabs
insert_with_affixes() {
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

block_insert() {
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
                block_insert "$config" "$_tabs$tabs"
                ;;
            affix*)
                insert_with_affixes "$1" $key "$_tabs$tabs"
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

test_result() {
    cat $temp_file
    rm $temp_file
}

move_result() {
    if [ -d "$output_dir" ]; then
        mv $temp_file "${output_dir}${i}_server.conf"
    else
        echo "$output_dir does not exist."
    fi
}

# docker run --rm -d -p 8080:80 --name apache --mount source=apache-conf,target=/mnt/configuration apache:0.1
docker_create() {
    docker image build -t $docker_image $docker_context
    docker volume create $docker_volume_name
}

docker_run() {
    docker run --rm -d -p $docker_rp_server_bind \
        --name $docker_rp_name \
        --mount source=$docker_volume_name,target=$docker_mount_point \
        $docker_image
}

docker_stop() {
    docker stop $docker_rp_name
}

docker_destroy() {
    docker_stop
    docker volume rm $docker_volume_name
}

main() {
    servers=$(jq -r '. | keys | .[]' $1)
    for i in $servers; do
        local config=$(jq -c ".$i" $1)
        local temp_file=$(mktemp)

        block_insert "$config" ""
        $2
    done
}

#########################
### DEFAULT VARIABLES ###
#########################
exec_mode=general
config_file=server_config.json
output_dir='/etc/httpd/conf.d/'
tabs='    '
verbose=false
docker_mount_point='/mnt/configuration'
docker_volume_name='apache-configuration'
docker_rp_server_bind='8080:80'
docker_rp_name='apache-docker'
docker_image='apache_ds'
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
            verbose=true
            ;;
        *)
            echo "help?"
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
        test)
            if $verbose ; then
                echo "Test mode."
                main "$config_file" test_result
            else
                main "$config_file" no_result
            fi
            ;;
        no-install)
            if $verbose ; then
                echo "No install mode."
            fi

            main "$config_file" move_result

            if $verbose ; then
                echo "Done. Result was moved to ${output_dir}."
            fi
            ;;
        docker_init)
            if [ -f "$docker_context/dockerfile" ]; then
                docker_create
            else
                echo "dockerfile was not found."
            fi
            ;;
        docker_run)
            # Spmewhere here docker image should be checked defore run.
            docker_run
            ;;
        docker_stop)
            docker_stop
            ;;
        docker_rm)
            docker_destroy
            ;;
        general)
            sudo $packageManager install -y jq httpd mod_ssl && main "$config_file" move_result
            ;;
        *)
            "Unexpected execute mode was selected. Error."
    esac
else
    echo "${config_file} was not found. Please make sure configuration file was named properly."
fi
