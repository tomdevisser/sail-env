#!/bin/bash

# Custom logging
log_info() {
	local blue="\\033[0;34m"
	local nc="\\033[0m"
	echo -e "${blue}==>${nc} $1"
}

log_success() {
        local green="\\033[0;32m"
        local nc="\\033[0m"
        echo -e "${green}==>${nc} $1"
}

log_error() {
        local red="\\033[0;31m"
        local nc="\\033[0m"
        echo -e "${red}==>${nc} $1"
}
