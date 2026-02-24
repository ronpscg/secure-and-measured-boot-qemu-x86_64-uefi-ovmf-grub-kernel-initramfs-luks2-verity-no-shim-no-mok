USER_NAME=user
: ${BASE=ubuntu:22.04}
docker build -t wip-yocto-docker-secboot-builder-$BASE  --build-arg BASE=$BASE --build-arg USERNAME=$USER_NAME --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) --build-arg HOST_DOCKER_GID=$(getent group docker | awk -F: '{print $3}') .
