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

main() {
    for i in $1; do
        local config=$(jq -c ".$i" server_config.json)
        local temp_file=$(mktemp)

        block_insert "$config" ""

        sudo mv $temp_file /etc/httpd/conf.d/$i_server.conf
        rm $temp_file
    done
}
#####################
### END FUNCTIONS ###
#####################

########################
### SCTIPT EXECUTION ###
########################

servers=$(jq -r '. | keys | .[]' server_config.json)

# Tabulation with spaces.
# Should be multiplied for blocks.
tabs='    '
# Check Linux distro.
version=$(sudo cat /proc/version)

if [ -z "${version##*Red Hat*}" ]; then
    packageManager=yum
fi

sudo $packageManager install jq httpd && main servers
