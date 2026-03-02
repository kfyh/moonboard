.PHONY: install uninstall

SERVICE := moonboard_led.service

install:
	echo "Install moonboard service for: $(SERVICE)"
	cp ./$(SERVICE) /lib/systemd/system/
	chmod 644 /lib/systemd/system/$(SERVICE)
	systemctl daemon-reload
	systemctl enable $(SERVICE)

uninstall:
	echo "Uninstall moonboard service for: $(SERVICE)"
	systemctl disable $(SERVICE)
	rm /lib/systemd/system/$(SERVICE)
	systemctl daemon-reload
