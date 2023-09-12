#!/bin/bash
for s in moonboard_led.service moonboard_ble.service;
sudo systemctl restart $service
done
