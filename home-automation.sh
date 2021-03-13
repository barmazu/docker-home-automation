#!/bin/bash

#
# Load configuration 
#
. ./project.setup || { >&2 echo "Error: project setup file not found!" ; exit 1 ; }

#
# Are you root?
#
if [[ "${UID}" -ne 0 ]]
then
    >&2 echo "This script must be run as root, re-exec with sudo..."
    exec sudo "${0}" "${@}"
    exit
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

#
# Is compose file present?
#
if [[ ! -e ${DOCKER_COMPOSE_FILE} ]]
then
    echo "File ${DOCKER_COMPOSE_FILE} does not exist"
    echo "Ignoring given parameters, going into initial setup mode..."
    INITIAL_SETUP=${TRUE}
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
              if [[ $? -eq ${SUCCESS} ]]
              then
                  echo "Directory ${DIR} has been setup successfully."
              else
                  >&2 echo "Error: Unable to set up directory: ${DIR}"
                  exit ${FAILURE}
              fi
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
        if [[ $? -eq ${SUCCESS} ]]
        then
            echo "Template file ${FILE} has been updated successfully."
        else
            >&2 echo "Error: Unable to set up template faile: ${FILE}"
            exit ${FAILURE}
        fi
        rm -rf "${FILE}"
    done

    #
    # Setup MQTT password
    #
    if [[ ! -e ${MQTT_DIR}/data/passwd-template ]]
    then
        echo "Setting up MQTT password..."
        docker run --rm \
            -v ${MQTT_DIR}/data/passwd:/mosquitto/data/passwd \
            eclipse-mosquitto \
                mosquitto_passwd -U /mosquitto/data/passwd >/dev/null 2>&1
        if [[ $? -eq ${SUCCESS} ]]
        then
            echo "MQTT credentials have been setup successfully."
        else
            >&2 echo "Error: Unable to set up MQTT credentials."
            exit ${FAILURE}
        fi
    fi

    #
    # Create compose file
    #
    if [[ ! -e ${DOCKER_COMPOSE_FILE} ]] && [[ -s ${SRC_CONFIG_DIR}/${DOCKER_COMPOSE_FILE}-template ]]
    then
        envsubst <"${SRC_CONFIG_DIR}/${DOCKER_COMPOSE_FILE}-template" >"./${DOCKER_COMPOSE_FILE}"
        if [[ $? -eq ${SUCCESS} ]]
        then
            echo "Project configuration file: ${DOCKER_COMPOSE_FILE} created."
        else
            >&2 echo "Error: Unable to create ${DOCKER_COMPOSE_FILE} file."
            exit ${FAILURE}
        fi
    fi
    
    #
    # Re-exec if parameters were givien 
    #
    if [[ $# -eq 1 ]] && [[ ! "$@" =~ "down" ]]
    then
        echo "Restarting now with previously given parameters: $@"
        exec "$0" "$@"
        exit 
    else
        echo "Now, start your Home Assistant with: ${0} up"
    fi
    
else
    case "${1}" in
        start|up)
            if [[ -n "${ZB_DEVICE_PATH}" ]]
            then
                ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} up -d --remove-orphans 2>&1
                RC=$?
            else
                ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} up -d --remove-orphans --no-deps mqtt home-assistant 2>&1
                RC=$?
            fi
            if [[ ${RC} -eq ${SUCCESS} ]]
            then
                echo "Home Assistant ready at: http://$(hostname -I | cut -d' ' -f1):${HA_PORT}"
            else
                >&2 echo "Error: Unable to create ${PROJECT_NAME} conatiners..."
            fi
            ;;
        down)
            echo ""
            echo "WARNING: You are about to EARSE docker containers, image and networks"
            read -p "Are you sure? (y/n) " -r
            if [[ ${REPLY} =~ ^[Yy]$ ]]
            then
                ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} down --rmi all 2>&1
                RC=$?
            fi
            unset REPLY
            echo ""
            echo "WARNING: You are about to EARSE persistent storage and configuration"
            read -p "Are you sure? (y/n) " -r
            if [[ ${REPLY} =~ ^[Yy]$ ]]
            then
                rm -rf ${PROJECT_PATH}
                echo "Project storage ${PROJECT_PATH} removed."
                rm -rf ./${DOCKER_COMPOSE_FILE}
                echo "Project configuration ${DOCKER_COMPOSE_FILE} removed"
                
            else
                echo "Persistent storage ${PROJECT_PATH} path left unchanged."
                echo "Project configuration ${DOCKER_COMPOSE_FILE} not removed."
            fi
            ;;
        *)
            ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} "${@}" 2>&1
            RC=$?
            ;;
    esac
    exit ${RC}
fi

