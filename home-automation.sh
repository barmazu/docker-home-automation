#!/bin/bash

DOCKER_PERSISTENT_ROOT=/opt

DOCKER_STORAGE_DIR=storage
DOCKER_PROJECT_NAME=ha
DOCKER_COMPOSE_FILE=./home-automation.yaml
HOME_AUTOMATION_SRC_CONFIG=./configuration

PROJECT_STORAGE_PATH=${DOCKER_PERSISTENT_ROOT}/${DOCKER_STORAGE_DIR}/${DOCKER_PROJECT_NAME}

# HOME ASSISTANT
HOME_ASSISTANT_DIR=${PROJECT_STORAGE_PATH}/homeassistant
# MQTT
MQTT_DIR=${PROJECT_STORAGE_PATH}/mqtt
# ZIGBEE2MQTT
ZIGBEE2MQTT_DIR=${PROJECT_STORAGE_PATH}/zigbee2mqtt

if [[ "${UID}" -ne 0 ]]
then
    >&2 echo "This script must be run as root, re-exec with sudo..."
    exec sudo "${0}" "${@}"
    exit
fi

if [[ ! -e ${DOCKER_COMPOSE_FILE} ]]
then
    >&2 echo "File ${DOCKER_COMPOSE_FILE} does not exist"
    exit 1
fi

if [[ ! -x "$(command -v docker 2>/dev/null)" ]]
then
    >&2 echo "docker binary not found or not in the PATH"
    >&2 echo "make sure docker-ce engine is installed and working"
    >&2 echo "see: https://docs.docker.com/install"
    exit 1
fi

if [[ -x "$(command -v  docker-compose 2>/dev/null)" ]]
then
    DOCKER_COMPOSE_BIN=$(command -v docker-compose)
else
    >&2 echo "docker-compose binary not found or not in the PATH"
    >&2 echo "see: https://github.com/docker/compose/releases"
    exit 1
fi

case ${1} in
    start|up)
        [[ ! -e  ${PROJECT_STORAGE_PATH} ]] && mkdir -p ${PROJECT_STORAGE_PATH}
        for DIR in ${HOME_ASSISTANT_DIR} ${MQTT_DIR} ${ZIGBEE2MQTT_DIR}
        do
            if [[ ! -e  ${DIR} ]]
            then
                (
                  umask 022
                  cp -r ${HOME_AUTOMATION_SRC_CONFIG}/"$(basename ${DIR})" ${PROJECT_STORAGE_PATH}
                  chown -R root:root ${DIR}
                )
            fi
        done

        ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} up -d 2>&1
        ;;
    *)

        ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} "${@}" 2>&1
        ;;
esac
exit 0
