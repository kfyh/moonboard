# LED System Build Instructions

The LEDs used are **addressable LED** stripes. There are many types of them (e.g., WS281X, WS2801, APA102). The original project specifies WS2801, but this project is configured to use WS2811 LEDs.

![LEDs](led.png)

## Requirements

Besides the tools, time, and budget, you will need:
* **Raspberry Pi**: e.g., Raspberry Pi 3 Model A+ or Raspberry Pi Zero W with SD Card.
* **4x LED Strips**: 50x WS2811 LED, 5V, 12mm - custom cable length of 23cm (alternatively 3x 4x LED Strips with standard length of 7cm).
* **Power Supply**: [Mean Well MDR-60-5](https://www.meanwell.com/webapp/product/search.aspx?prod=MDR-60) (~60mA * 50 * 4 = 12A ==> 60W for 5V).
* **Suitable Case**: (e.g., TEKO).

## General Considerations

Bear in mind that 198 LEDs wired with 3-4 cables each mean a lot of soldering work. You probably want to order ready-to-use LED stripes with a suitable custom length. 5V leads to higher currents compared to 12V versions of comparable bright LEDs. The voltage drop in such a length will lead to color mismatches. To fix this, the stripes usually have separate voltage connectors on each end in addition to the 3 / 4 pin connection.

![LED Strip](led_strip.png)

If custom lengths are not available, you can use 50 LED strips and skip intermediate LEDs (e.g. using every 3rd LED).

## Wiring the LED Stripes

The WS2811 LED strips have three wires:
* **White**: GND
* **Red**: 5V
* **Green**: Signal (GPIO18 / PWM0 on the Pi)

Both the LED strip and the Raspberry Pi are driven by the same power supply.

> [!WARNING]
> Powering the Raspberry Pi directly via GPIO has no fuse protection. Double check your wiring before powering on.

![Raspi Wiring](raspi_wiring.png)

## Configuration

The LED layout and mapping of hold coordinates to physical LEDs is configured in [led_mapping.json](file:///Users/localkevin/workspace/moonboard/src/led/led_mapping.json).

To customize your layout:
1. Open [led_mapping.json](file:///Users/localkevin/workspace/moonboard/src/led/led_mapping.json).
2. Edit the mappings to assign the correct 0-indexed LED number to each grid coordinate (e.g. `"A1": 0`, `"B18": 54`).
3. If you have custom panels, you can use the example JSON mapping templates under `src/led` as references (such as `led_mapping_3-Panels.json` or `led_mapping_horiz.json`).

## Testing

For testing, simply turn on the device and use the official Moonboard app on your phone:
1. Make sure your phone's Bluetooth is enabled.
2. Open the Moonboard app, select a problem, and click the light/bulb icon.
3. When prompted to connect to a board, select **Yes**. The board should automatically pair and light up the selected problem.

There are no direct CLI-based testing tools needed.

## Further Readings
* [Raspberry Pi Zero als LED Strip Controller](https://developer-blog.net/raspberry-pi-zero-als-led-strip-controller)
