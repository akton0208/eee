#!/bin/bash

# Script save path
SCRIPT_PATH="$HOME/v3.sh"

# Check and install Docker
function check_and_install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker not detected, installing..."
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce
        echo "Docker installed."
    else
        echo "Docker is already installed."
    fi
}

# Node installation function
function install_node() {
    check_and_install_docker

    # Automatically get the current machine's IP address
    ip_address=$(hostname -I | awk '{print $1}')
    echo "Detected IP address: ${ip_address}"

    # Prompt user for other environment variable values
    read -p "Node name: " validator_name
    read -p "Reward address: " safe_public_address
    read -p "Private key (without 0x): " private_key

    # Save environment variables to validator.env file
    cat <<EOF > validator.env
ENV=testnet-3

STRATEGY_EXECUTOR_IP_ADDRESS=${ip_address}
STRATEGY_EXECUTOR_DISPLAY_NAME=${validator_name}
STRATEGY_EXECUTOR_BENEFICIARY=${safe_public_address}
SIGNER_PRIVATE_KEY=${private_key}
EOF

    echo "Environment variables set and saved to validator.env file."

    # Pull Docker image
    docker pull elixirprotocol/validator:v3

    # Run Docker container
    docker run -it -d \
      --env-file validator.env \
      --name v3 \
      elixirprotocol/validator:v3
}

# Function to check Docker logs
function check_docker_logs() {
    echo "Checking Elixir Docker container logs..."
    docker logs -f v3
}

# Function to delete Docker container
function delete_docker_container() {
    echo "Deleting Elixir Docker container..."
    docker stop v3
    docker rm v3
    echo "Elixir Docker container deleted."
}

# Function to kill, remove, pull, and run Docker container
function kill_remove_pull_run_docker_container() {
    echo "Killing and removing Elixir Docker container..."
    docker kill v3
    docker rm v3
    echo "Pulling latest Elixir Docker image..."
    docker pull elixirprotocol/validator:v3
    echo "Running new Elixir Docker container..."
    docker run -it -d \
      --env-file validator.env \
      --name v3 \
      elixirprotocol/validator:v3
    echo "Elixir Docker container killed, removed, latest image pulled, and new container running."
}

# Main menu
function main_menu() {
    clear
    echo "Please select an option:"
    echo "1. Install Elixir V3 node"
    echo "2. Check Docker logs"
    echo "3. Delete Elixir Docker container"
    echo "4. Kill, remove, pull, and run latest Elixir Docker container"
    echo "5. Exit"
    read -p "Enter option (1-5): " OPTION

    case $OPTION in
    1) install_node ;;
    2) check_docker_logs ;;
    3) delete_docker_container ;;
    4) kill_remove_pull_run_docker_container ;;
    5) exit 0 ;;
    *) echo "Invalid option." ;;
    esac
}

# Display main menu
main_menu
