#! /bin/bash
servers=$(jq -r '. | keys | .[]' server_config.json)

# Tabulation with spaces.
tabs='\ \ \ \ '
# Check Linux distro.
version=$(sudo cat /proc/version)

if [ -z "${version##*Red Hat*}" ]; then
    packageManager=yum
fi

# sudo $packageManager install httpd

# $1 - config
# $2 - key
# $3 - suffix
string_insert() {
    items=($(echo $1 | jq -r ".$2 | .[]"))
    if [[ "${#items[@]}" > 0 ]]; then
        sed -i "$inserts a $tabs\# $key options." $temp_file
        inserts=$((inserts + 1))
        for item in ${items[@]}; do
            sed -i "$inserts a $tabs$item $3" $temp_file
            inserts=$(($inserts + 1))
        done
    fi
}

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
        sed -i "$inserts a $tabs\# $comment" $temp_file
        inserts=$(($inserts + 1))
        for item in ${items[@]}; do
            sed -i "$inserts a $tabs$preffix$item$suffix" $temp_file
            inserts=$(($inserts + 1))
        done
    fi
}

for i in $servers;do
    # Line number to add rules.
    inserts=2

    config=$(jq ".\"$i\"" server_config.json)
    temp_file=$(mktemp)

    sed "s/%%servername%%/ $i/" ./server_template.conf > $temp_file

    keys=$(echo $config | jq -r 'keys | .[]')

    # iterate through config keys
    # allows except some cases with corrupted or not right config
    for key in $keys; do
        case $key in
            ports)
                ports=$(echo $config | jq -r ".$key | .[]")
                listning=""
                for port in $ports; do
                    listning="$listning *:$port"
                done

                if [[ "${ports[*]}" =~ 443 ]]; then
                    sed -i "$inserts a ${tabs}SSLEngine on" $temp_file
                    inserts=$((inserts + 1))
                fi

                sed -i "s/%%ports%%/ $listning/" $temp_file
                ;;
            aliases)
                string_insert "$config" $key
                ;;
            enable)
                string_insert "$config" $key on
                ;;
            disable)
                string_insert "$config" $key off
                ;;
            affix*)
                insert_with_affixes "$config" $key
                ;;
            *)
                echo "$key is not supported"
    esac
    done

    cat $temp_file
    rm $temp_file
done
   
