.PHONY: install uninstall

SERVICE := moonboard_led.service

install:
	echo "Install moonboard service for: $(SERVICE)"
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
	sudo systemctl daemon-reload
