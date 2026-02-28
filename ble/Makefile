#api-doc:
#	docker run --rm -it -v $(PWD)/ble_api.yaml:/app/asyncapi.yml -v $(PWD)/api:/app/output asyncapi/generator  -o /app/output /app/asyncapi.yml @asyncapi/html-template --force-write

.PHONY: install uninstall

SERVICE := com.moonboard.service

install:
	echo "Install moonboard service for: $(SERVICE)"
	sudo cp ./com.moonboard.conf /etc/dbus-1/system.d
	sudo cp ./$(SERVICE) /lib/systemd/system/
	sudo chmod 644 /lib/systemd/system/$(SERVICE)
	sudo systemctl daemon-reload
	sudo systemctl enable $(SERVICE)
	sudo systemctl restart $(SERVICE)

uninstall:
	echo "Uninstall moonboard service for: $(SERVICE)"
	sudo systemctl stop $(SERVICE)
	sudo systemctl disable $(SERVICE)
	sudo rm /lib/systemd/system/$(SERVICE)
	sudo rm /etc/dbus-1/system.d/com.moonboard.conf
	sudo systemctl daemon-reload
