#!/bin/bash -eu

echo "Vultr host installation"

apt-get update && apt-get upgrade -y

apt-get install git -y
