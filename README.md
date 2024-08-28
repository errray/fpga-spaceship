This project has been developed as a semester-end project at the undergraduate level, programmed for the Altera System-on-Chip (SoC) FPGA development board using Verilog with Quartus II (13.1).

The game involves a spaceship positioned at the center, which must shoot down asteroids coming from different directions and represented in various shapes (rectangle, square, circle). If the spaceship fails to shoot an asteroid, it collides with the spaceship, resulting in the game ending (a "Game Over" message appears on the screen). Additionally, a button is configured to increase the game’s difficulty level. When pressed, it causes the asteroids to move faster. A multi-shot mode for the spaceship has been implemented to counter this difficulty, allowing the spaceship to hit all targets within a 90-degree angle.

The pixel_generation_from_left.v file defines the location where the moving objects are generated and the principles governing their movement.

The seven_segment.v file contains the code related to displaying the "Game Over" message on the screen when an asteroid hits the spaceship.

The lfsr.v file ensures the random generation of asteroids and communicates the generated randomness to the pixel generation module, causing the asteroids to appear at the edge of the screen.

The vga_controller.v file contains the connections between different files related to VGA display.

The clock_divider.v file is used to convert the board's internal frequency of 50 MHz to 1 Hz, as the original frequency is too high for the game.

![fpga_example](https://github.com/user-attachments/assets/fe31aec1-6efa-4de5-977d-32b6a936e6b3)
