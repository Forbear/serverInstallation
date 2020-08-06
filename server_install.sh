#! /bin/bash
servers=$(jq -r '. | keys | .[]' server_config.json)

# Line number to add rules.
inserts=2
# Tabulation with spaces.
tabs='\ \ \ \ '
# Check Linux distro.
version=$(sudo cat /proc/version)

if [ -z "${version##*Red Hat*}" ]; then
    packageManager=yum
fi

sudo $packageManager install httpd

# $1 - config
# $2 - key
# $3 - inserts
string_insert() {
    items=($(echo $1 | jq -r ".$2 | .[]"))
    local_inserts=$3
    if [[ "${#items[@]}" > 0 ]]; then
        for item in $items; do
            sed -i "$local_inserts a $tabs$item on" $temp_file
        done
        sed -i "$local_inserts a $tabs\# $key options." $temp_file
        echo $local_inserts
    fi
}

for i in $servers;do
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
                inserts=$(string_insert $config $key $inserts)
                ;;
            enable)
                modules=($(echo $config | jq -r ".$key | .[]"))
                if [[ "${#modules[@]}" > 0 ]]; then
                    for module in ${modules[@]}; do 
                        sed -i "$inserts a $tabs$module on" $temp_file
                    done
                fi
                ;;
            disable)
                modules=($(echo $config | jq -r ".$key | .[]"))
                if [[ "${#modules[@]}" > 0 ]]; then
                    for module in ${modules[@]}; do
                        sed -i "$inserts a $tabs$module off" $temp_file
                    done
                fi
                ;;
        *)
        echo "$key is not supported"
    esac
    done

    cat $temp_file
    rm $temp_file
done
   
