#!/usr/bin/env bash

# make our output look nice...
script_name="evilgophish setup"
# Define the .env file path
ENV_FILE="/root/evilgophish2/evilginx2/.env"


function print_good () {
    echo -e "[${script_name}] \x1B[01;32m[+]\x1B[0m $1"
}

function print_error () {
    echo -e "[${script_name}] \x1B[01;31m[-]\x1B[0m $1"
}

function print_warning () {
    echo -e "[${script_name}] \x1B[01;33m[-]\x1B[0m $1"
}

function print_info () {
    echo -e "[${script_name}] \x1B[01;34m[*]\x1B[0m $1"
}

# Set variables from parameters
export HOME=/root
export GOCACHE=$HOME/.cache

# Install needed dependencies
function install_depends() {
    print_info "Installing dependencies with apt"
    apt-get update
    apt-get install -y build-essential letsencrypt certbot wget git net-tools tmux openssl jq
    print_good "Installed dependencies with apt!"

    print_info "Installing Go from source"

    # Download Go binary
    curl -OL https://golang.org/dl/go1.19.linux-amd64.tar.gz

    # Remove any existing Go installation
    if [ -d "/usr/local/go" ]; then
        rm -rf /usr/local/go
    fi

    # Extract the tarball to /usr/local
    tar -zxvf go1.19.linux-amd64.tar.gz -C /usr/local/

    # Update PATH in .profile if not already present
    if ! grep -q 'export PATH=\$PATH:/usr/local/go/bin' ~/.profile ; then
        echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
    fi

    # Add Go to the PATH environment variable for the current script
    export PATH=$PATH:/usr/local/go/bin

    # Remove the downloaded tarball
    rm go1.19.linux-amd64.tar.gz

    # Apply PATH changes for current session
    source ~/.profile

    print_good "Installed Go from source!"
}


# Configure and install evilginx3
function setup_evilginx3 () {

    cd evilginx2

    # Prepare DNS for evilginx3
    sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved

    print_info "Removing evilginx indicator (X-Evilginx header)..."
    sed -i 's/req.Header.Set(p.getHomeDir(), o_host)/\/\/req.Header.Set(p.getHomeDir(), o_host)/' evilginx2/core/http_proxy.go

    # Build evilginx3
    make

    cp /root/evilgophish/evilginx2/build/evilginx /usr/local/bin


    print_info "Setting permissions to allow evilginx to bind to privileged ports..."
    sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/evilginx

    
    mkdir -p ~/.evilginx/phishlets
    mkdir -p ~/.evilginx/redirectors
    cp -r ./phishlets/* ~/.evilginx/phishlets/
    cp -r ./redirectors/* ~/.evilginx/redirectors/

    wget -O /root/.evilginx/blacklist.txt https://github.com/aalex954/MSFT-IP-Tracker/releases/latest/download/msft_asn_ip_ranges.txt

    cd ..
    print_good "Configured evilginx3!"
}

# Configure and install gophish
function setup_gophish () {

    print_info "Configuring gophish"
    
    cd gophish || exit 1

    # Stripping X-Gophish
    sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go
    sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go
    sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go
    sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go


    # Stripping X-Gophish-Signature
    sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go

    # Changing server name
    sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go

    # Changing rid value
    sed -i 's/const RecipientParameter = "rid"/const RecipientParameter = "keyname"/g' models/campaign.go

    # Replace 'client_id' and 'rid' with 'keyname' across all files
    find . -type f -exec sed -i "s|client_id|keyname|g" {} \;
    find . -type f -exec sed -i "s|rid|keyname|g" {} \;

    go build
    cd ..
    print_good "Configured gophish!"
}

function main () {
    install_depends
    setup_gophish
    setup_evilginx3
    print_good "Installation complete!"
    print_info "It is recommended to run all servers inside a tmux session to avoid losing them over SSH!"
}

main
