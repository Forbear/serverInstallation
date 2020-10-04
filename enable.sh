#! /bin/bash

ls active/ | grep -q $1 && ln -s ../available/$1 active/$1
