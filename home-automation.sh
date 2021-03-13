#!/bin/bash

#
# Load configuration 
#
SRC_CONFIG_DIR=configuration
. ./${SRC_CONFIG_DIR}/home-automation.config || { >&2 echo "Error: configuration file not found!" ; exit 1 ; }

#
# Are you root?
#
if [[ "${UID}" -ne 0 ]]
then
    >&2 echo "This script must be run as root, re-exec with sudo..."
    exec sudo "${0}" "${@}"
    exit
fi

#
# Is compose file present?
#
if [[ ! -e ${DOCKER_COMPOSE_FILE} ]]
then
    echo "File ${DOCKER_COMPOSE_FILE} does not exist"
    INITIAL_SETUP=${TRUE}
fi

if [[ ! -x "$(command -v docker 2>/dev/null)" ]]
then
    >&2 echo "'docker' binary not found or not in the PATH"
    >&2 echo "Make sure docker-ce engine is installed and working"
    >&2 echo "See: https://docs.docker.com/install"
    exit ${FAILURE}
fi

if [[ -x "$(command -v docker-compose 2>/dev/null)" ]]
then
    DOCKER_COMPOSE_BIN=$(command -v docker-compose)
else
    >&2 echo "'docker-compose' binary not found or not in the PATH"
    >&2 echo "See: https://github.com/docker/compose/releases"
    exit ${FAILURE}
fi

if [[ ${INITIAL_SETUP} -eq ${TRUE} ]]
then

    #
    # Setup directory structure
    #
    [[ ! -e  ${PROJECT_PATH} ]] && mkdir -p ${PROJECT_PATH}
    for DIR in ${HOME_ASSISTANT_DIR} ${MQTT_DIR} ${ZIGBEE2MQTT_DIR}
    do
        if [[ ! -e "${DIR}" ]]
        then
            (
              umask 022
              cp -r ${SRC_CONFIG_DIR}/"$(basename ${DIR})" ${PROJECT_PATH}
            )
        fi
    done

    #
    # Update template YAML files with config values
    #
    TEMPLATE_FILES="$(find ${PROJECT_PATH} -type f -name "*-template")"
    for FILE in ${TEMPLATE_FILES}
    do
        echo "Updating ${FILE} file..."
        envsubst <"${FILE}" >"${FILE%%-template}"
        rm -rf "${FILE}"
    done

    #
    # Setup MQTT password
    #
    if [[ ! -e ${MQTT_DIR}/data/passwd-template ]]
    then
        docker run --rm -v ${MQTT_DIR}/data/passwd:/mosquitto/data/passwd eclipse-mosquitto mosquitto_passwd -U /mosquitto/data/passwd
        if [[ $? -eq ${SUCCESS} ]]
        then
            echo "MQTT credentials has been setup successfully"
        else
            >&2 echo "Error: Unable to set up MQTT credentials"
            exit ${FAILURE}
        fi
    fi

    #
    # Create compose file
    #
    if [[ ! -e ${DOCKER_COMPOSE_FILE} ]] && [[ -s ${SRC_CONFIG_DIR}/${DOCKER_COMPOSE_FILE}-template ]]
    then
        cp ${SRC_CONFIG_DIR}/${DOCKER_COMPOSE_FILE}-template ./${DOCKER_COMPOSE_FILE}
    fi

else
    case ${1} in
        start|up)
            ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} up -d --remove-orphans 2>&1
            RC=$?
            ;;
        *)

            ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} "${@}" 2>&1
            RC=$?
            ;;
    esac
fi
exit ${RC}
