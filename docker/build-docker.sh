USER_NAME=user

docker build -t wip-docker-secboot-builder  --build-arg USERNAME=$USER_NAME --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) --build-arg HOST_DOCKER_GID=$(getent group docker | awk -F: '{print $3}') .
