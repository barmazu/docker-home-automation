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
    f__echo_err "This script must be run as root, re-exec with sudo..."
    exec sudo "${0}" "${@}"
    exit
fi

if [[ ! -x "$(command -v docker 2>/dev/null)" ]]
then
    f__echo_err "'docker' binary not found or not in the PATH"
    f__echo_err "Make sure docker-ce engine is installed and working"
    f__echo_err "See: https://docs.docker.com/install"
    exit ${FAILURE}
fi

if [[ -x "$(command -v docker-compose 2>/dev/null)" ]]
then
    DOCKER_COMPOSE_BIN=$(command -v docker-compose)
else
    f__echo_err "'docker-compose' binary not found or not in the PATH"
    f__echo_err "See: https://github.com/docker/compose/releases"
    exit ${FAILURE}
fi

#
# Is compose file present?
#
if [[ ! -e ${DOCKER_COMPOSE_FILE} ]] || [[ ${1} == "setup" ]]
then
    f__echo "File ${DOCKER_COMPOSE_FILE} does not exist or setup explicitly requested"
    f__echo "Going into initial setup mode..."
    shift 1
    INITIAL_SETUP=${TRUE}
fi

if [[ ${INITIAL_SETUP} -eq ${TRUE} ]]
then
    
    #
    # Create files with some restrictions
    #
    umask 026
    
    #
    # Setup directory structure
    #
    [[ ! -e  ${PROJECT_PATH} ]] && mkdir -p ${PROJECT_PATH}
    
    #
    # Copy initial and template files to target project path
    #
    for DIR in ${HOME_ASSISTANT_DIR} ${ZIGBEE2MQTT_DIR} ${MQTT_DIR}
    do
        # No need to copy zigbee2mqtt if we are not using it
        if [[ "${DIR}"  =~ zigbee2mqtt ]] && [[ -z ${ZB_DEVICE_PATH} ]]
        then
            f__echo_warn "WARNING: Skipping ${DIR} as ZB_DEVICE_PATH is empty"
            continue
        fi
        cp -r ${SRC_CONFIG_DIR}/"$(basename ${DIR})" ${PROJECT_PATH}
        if [[ $? -eq ${SUCCESS} ]]
        then
            f__echo_ok "Directory ${DIR} has been setup successfully."
        else
            f__echo_err "Error: Unable to set up directory: ${DIR}"
            exit ${FAILURE}
        fi
    done
    
    #
    # Setup initial files
    #
    INITIAL_FILES="$(find ${PROJECT_PATH} -type f -name "*-initial")"
    for INIT_FILE in ${INITIAL_FILES}
    do
        FILE="${INIT_FILE%%-initial}"
        if [[ ! -e "${FILE}" ]]
        then
            f__echo "Creating ${FILE} file using initial file..."
            mv "${INIT_FILE}" "${FILE}"
            if [[ $? -eq ${SUCCESS} ]]
            then
                f__echo_ok "File ${FILE} has been created successfully."
            else
                f__echo_err "Error: Unable to set up file: ${FILE}"
                exit ${FAILURE}
            fi
        fi
        rm -rf "${INIT_FILE}"
    done
    
    #
    # Update template YAML files with config values
    #
    TEMPLATE_FILES="$(find ${PROJECT_PATH} -type f -name "*-template")"
    for TEMPL_FILE in ${TEMPLATE_FILES}
    do
        FILE="${TEMPL_FILE%%-template}"
        if [[ ! -e "${FILE}" ]]
        then
            f__echo "Creating ${FILE} file using template..."
            envsubst <"${TEMPL_FILE}" >"${FILE}"
            if [[ $? -eq ${SUCCESS} ]]
            then
                f__echo_ok "File ${FILE} has been created successfully."
            else
                f__echo_err "Error: Unable to set up file: ${FILE}"
                exit ${FAILURE}
            fi
        fi
        rm -rf "${TEMPL_FILE}"
    done

    #
    # Hash MQTT password
    #
    if [[ ! -e ${MQTT_DIR}/data/passwd-template ]]
    then
        # Make sure we are hashing plain text password
        if grep -q "${MQTT_PASSWORD}" ${MQTT_DIR}/data/passwd
        then
            f__echo "Hashing MQTT plain text password..."
            docker run --rm \
                -v ${MQTT_DIR}/data/passwd:/mosquitto/data/passwd \
                eclipse-mosquitto \
                    mosquitto_passwd -U /mosquitto/data/passwd >/dev/null 2>&1
            if [[ $? -eq ${SUCCESS} ]]
            then
                f__echo_ok "MQTT password has been hashed successfully."
            else
                f__echo_err "Error: Unable to set up MQTT credentials."
                exit ${FAILURE}
            fi
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
            f__echo_ok "Project configuration file: ${DOCKER_COMPOSE_FILE} created."
        else
            f__echo_err "Error: Unable to create ${DOCKER_COMPOSE_FILE} file."
            exit ${FAILURE}
        fi
    fi
    
    #
    # Re-exec if parameters were given 
    #
    if [[ $# -eq 1 ]] && [[ ! "$@" =~ "down" ]]
    then
        f__echo "Restarting now with previously given parameters: $@"
        exec "$0" "$@"
        exit 
    else
        f__echo_ok "Now, start your Home Assistant with: ${0} up"
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
                for HOST_IP in ${HOST_IP_LIST}
                do
                    f__echo_ok "Home Assistant ready at: http://${HOST_IP}:${HA_PORT}"
                done
            else
                f__echo_err "Error: Unable to create ${PROJECT_NAME} containers..."
            fi
            ;;
        down)
            f__echo_warn "---"
            f__echo_warn "WARNING: You are about to ERASE docker containers, image and networks"
            read -p "Are you sure? (y/n) " -r
            if [[ ${REPLY} =~ ^[Yy]$ ]]
            then
                ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} down --rmi all 2>&1
                RC=$?
            fi
            unset REPLY
            f__echo_warn "---"
            f__echo_warn "WARNING: You are about to ERASE persistent storage and configuration"
            read -p "Are you sure? (y/n) " -r
            if [[ ${REPLY} =~ ^[Yy]$ ]]
            then
                rm -rf ${PROJECT_PATH}
                f__echo "Project storage ${PROJECT_PATH} removed."
                rm -rf ./${DOCKER_COMPOSE_FILE}
                f__echo "Project configuration ${DOCKER_COMPOSE_FILE} removed"
                
            else
                f__echo "Persistent storage ${PROJECT_PATH} path left unchanged."
                f__echo "Project configuration ${DOCKER_COMPOSE_FILE} not removed."
            fi
            ;;
        *)
            ${DOCKER_COMPOSE_BIN} -f ${DOCKER_COMPOSE_FILE} -p ${PROJECT_NAME} "${@}" 2>&1
            RC=$?
            ;;
    esac
    exit ${RC}
fi

