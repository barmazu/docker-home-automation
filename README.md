##Home Automation
Automation for your home with Home Assistant/MQTT/Zigbee2Mqtt running in Docker.

###What's this?
Easy to use shell script that will run Home Assistant, MQTT Broker and Zigbee2Mqtt with some basic configuration on any Docker capable machine.
The home automation playground/sandbox is ready under 3 minutes without any hassle on your side.

###Prerequisites

- Docker capable machine (X64 PC, Raspberry Pi, etc) with docker-compose binary
- CC2531 Zigbee sniffer at /dev/ttyACM0
- (Probably) Some Zigbee protocol enabled end devices (a bulb, thermometer, motion sensor, etc)

###Quick start

- Clone (or download) repository
- As root user run: ./home-automation.sh start
- Home Assistant interface is hopefully available at <YOUR_DEVICE_IP>:82

###Uninstall

- ./home-automation.sh stop 
- ./home-automation.sh rm
- rm -rf /opt/storage/ha

### Notes and remarks

- This is barely secure instance (for now) - **use for testing purposes only**
- No easy customization is allowed (for now) - you may edit scripts/configuration if you know what you are doing
- home-automation.sh is basically a shell wrapper for docker-compose command 
(e.g. run ./home-automation.sh ps to display status of your containers, see: ./home-automation.sh help for more)
