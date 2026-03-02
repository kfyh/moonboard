#api-doc:
#	docker run --rm -it -v $(PWD)/ble_api.yaml:/app/asyncapi.yml -v $(PWD)/api:/app/output asyncapi/generator  -o /app/output /app/asyncapi.yml @asyncapi/html-template --force-write

.PHONY: install uninstall

SERVICE := com.moonboard.service

install:
	echo "Install moonboard service for: $(SERVICE)"
	cp ./com.moonboard.conf /etc/dbus-1/system.d
	cp ./$(SERVICE) /lib/systemd/system/
	chmod 644 /lib/systemd/system/$(SERVICE)
	systemctl daemon-reload
	systemctl enable $(SERVICE)

uninstall:
	echo "Uninstall moonboard service for: $(SERVICE)"
	systemctl disable $(SERVICE)
	rm /lib/systemd/system/$(SERVICE)
	rm /etc/dbus-1/system.d/com.moonboard.conf
	systemctl daemon-reload
