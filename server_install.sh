#! /bin/bash

#################
### FUNCTIONS ###
#################
# $1 - config
# $2 - $key
insert_with_affixes() {
    fields=$(echo $1 | jq -rc ".$2")
    preffix=$(echo $fields | jq -r ".preffix")
    suffix=$(echo $fields | jq -r ".suffix")
    comment=$(echo $fields | jq -r ".comment")
    items=($(echo $fields | jq -r ".content | .[]"))

    if [[ "$prefix" != "null" ]]; then
        preffix="$preffix "
    else
        preffix=""
    fi

    if [[ "$suffix" != "null" ]]; then
        suffix="$suffix "
    else
        suffix=""
    fi

    if [[ "${#items[@]}" > 0 ]]; then
        echo "$tabs\# $comment" >> $temp_file
        for item in ${items[@]}; do
            echo "$tabs$preffix$item$suffix" >> $temp_file
        done
    fi
}

block_insert() {
    preffix=$(echo $1 | jq -r ".preffix")
    content=$(echo $1 | jq -r ".content")
    # Other keys.
    block_keys=$(echo $1 | jq -r "keys | .[]" | grep -v (preffix|content))
    echo "<$preffix $content>" >> $temp_file
    for key in $block_keys; do
        case $key in
            block*)
                config=$(echo $1 | jq -c ".$key")
                block_insert "$config"
                ;;
            affix*)
                insert_with_affixes "$1" $key
                ;;
            *)
                echo "$key is not supported"
        esac
    done
    echo "</$preffix>" >> $temp_file
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
tabs='\ \ \ \ '
# Check Linux distro.
version=$(sudo cat /proc/version)

if [ -z "${version##*Red Hat*}" ]; then
    packageManager=yum
fi

# sudo $packageManager install httpd

for i in $servers;do
    # Line number to add rules.
    inserts=2

    config=$(jq -c ".$i" server_config.json)
    temp_file=$(mktemp)

    block_insert "$config"

    cat $temp_file
    rm $temp_file
done
   
