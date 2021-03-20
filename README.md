## Home Automation
Automation for your home with Home Assistant/MQTT/Zigbee2Mqtt running in Docker.

### What's this?
Easy to use shell script that will run Home Assistant, MQTT Broker and, optionally, Zigbee2Mqtt with some basic configuration on any Docker capable machine.
The home automation playground/sandbox is ready under 3 minutes without any hassle on your side.

### Prerequisites
- Docker capable machine (X64 PC, Raspberry Pi, etc) with docker-compose binary (aka Docker host)
  - version of docker engine supported: docker-ce `19.03+`, docker-compose: `1.25+`
- Some Smart Home enabled end devices (a bulb, thermometer, motion sensor, etc)

### Quick start
- Clone (or download) repository
- Review and adjust `home-automation.cfg` file
    - it's pretty straight-forward, may be left unchanged
    - important defaults are as fallows:
        - PROJECT_PERSISTANT_STORAGE = /opt/storage
        - PROJECT_NAME = ha
        - HA_PORT = 8123
        
     > If you don't change this it will mean all your configuration will be saved in `/opt/storage/ha` directory and Home Assistant Web-Interface will be accessible on Docker host IP port 8123 (ex. http://192.168.1.5:8123)
- As root user run: `./home-automation.sh start` - runs non-interactive setup/startup
- Home Assistant web interface is hopefully available as per configuration file

### Uninstall
- As root user run: `./home-automation.sh down` - runs interactive uninstall

### Setup Mode
- You may request setup mode which will recreate project configuration file `home-automation.yaml` even if exists.
In this mode configuration files in persistent storage will __NOT__ be overwritten if already exist.
As root user run: `./home-automation.sh setup`

### Daily operations:
- Update project images (at any time):
  - `./home-automation.sh stop`  - stops all containers
  - `./home-automation.sh pull`  - pulls latest images available
  - `./home-automation.sh start` - start/recreation of containers

- Check containers health:
  - `./home-automation.sh ps`  - prints all vital data and statuses for all containers in the configuration
  - `./home-automation.sh logs`  - prints all logs from all containers
  - `./home-automation.sh logs <service>`  - limit printed logs to a <service>, where <service> is one of the containers: home-assistant, mqtt or zigbee2mqtt
  - `./home-automation.sh top` - prints processes running inside of the containers

### Notes, remarks and hints:
- You can use it as a base for your Smart Home solution but keep in mind, this is just a simple orchestration for containers, nothing more.
- Once project is running all further configuration must be done within persistent storage (option in home-automation.cfg) for respective services/containers:
    - `<PROJECT_PERSISTANT_STORAGE>/<PROJECT_NAME>/homeassistant/config` directory for home-assistant (often needed)
    - `<PROJECT_PERSISTANT_STORAGE>/<PROJECT_NAME>/zigbee2mqtt/data` directory for zigbee2mqtt (rarely needed)
    - `<PROJECT_PERSISTANT_STORAGE>/<PROJECT_NAME>/mqtt/config` directory for mqtt (very rarely needed)
- You can expose your persistent storage via Samba (Samba must be installed on Docker host) to update files from Windows hosts, for example:
```
[HA]
      path = <PROJECT_PERSISTANT_STORAGE>/<PROJECT_NAME>
      read only = no
      guest ok = yes
      force user = root
      force group = root
      create mask = 0664
      directory mask = 0775
```
  where: <PROJECT_PERSISTANT_STORAGE> and <PROJECT_NAME> are values from `home-assistant.cfg` file (default: `/opt/storage/ha`)
- Make sure you are running backup of persistent storage regularly if seriously building up your Smart Home with this solution
- In case you didn't noticed, `home-automation.sh` is basically a shell wrapper for docker-compose command, see: ./home-automation.sh help for more options
