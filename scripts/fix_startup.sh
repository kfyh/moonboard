#!/bin/bash
sudo systemctl stop moonboard_led
sudo systemctl stop com.moonboard

# startup in correct order
sudo systemctl restart com.moonboard
sudo systemctl restart moonboard_led