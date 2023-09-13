#api-doc:
#	docker run --rm -it -v $(PWD)/ble_api.yaml:/app/asyncapi.yml -v $(PWD)/api:/app/output asyncapi/generator  -o /app/output /app/asyncapi.yml @asyncapi/html-template --force-write

install:
	service="moonboard_ble.service"
	echo "Install moonboard service for: moonboard_ble.service" 
	sudo cp ./moonboard_ble.service /lib/systemd/system/
	sudo chmod 644 /lib/systemd/system/moonboard_ble.service
	sudo systemctl daemon-reload
	sudo systemctl enable moonboard_ble.service
	sudo systemctl restart moonboard_ble.service
