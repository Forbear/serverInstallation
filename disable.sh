#! /bin/bash

ls active/ | grep -q $1 && rm active/$1
