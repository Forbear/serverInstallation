#! /bin/bash

available_files=$(ls ../available/)
file_name="checkboxes.yaml"

echo 'CheckboxParameter:' > checkboxes.yaml.bak
for file in $available_files; do
    echo -e "  - key: $file\n    value: $file" >> checkboxes.yaml.bak
done
