#! /bin/bash

available_files=$(ls ./available/)
file_name="./jenkins/checkboxes.yaml"

echo 'CheckboxParameter:' > $file_name
for file in $available_files; do
    echo -e "  - key: $file\n    value: $file" >> $file_name
done
