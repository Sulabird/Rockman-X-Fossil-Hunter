## About
This is a WIP scrolling-platformer heavily inspired by the Rockman X franchise, in its current state
it only contains a test map with movement options similar to that of said franchise, as well as the basic lemon shot.
Tiles are 16x16, by default the game will scale from 480x270.<br><br>
For more context I'm a novice nim user trying out game development. I've been interested in the
Rockman X games for quite a while. I kind just made up the physics so don't expect it to play identically.

## Made with Kirpi
This project is made with kirpi, an elegant, lightweight game framework for Nim.<br>
You should check out kirpi here: https://github.com/erayzesen/kirpi

## Controls
Currently not re-bindable
You can hold the dash button for mono and consecutive jumps and wall jumps.
- Left: Accelerate left
- Right: Accelerate right
- X: Shoot
- C: Jump
- V: Dash

## Building & Running
Note: Building on windows not tested<br>
On linux & windows build.sh/ps1 will check for kirpi and install it with nimble if needed, as well
as compile the game outputting it in ./bin, on linux it also checks for wayland using WAYLAND_DISPLAY<br><br>
To build manually:<br>
- Install kirpi with nimble: ``nimble install kirpi``<br>
- Compile the game ``nim c [options] ./src/game.nim``<br>
- Move it to ./bin ``mkdir ./bin && mv ./src/game.nim ./bin``

To run the game make sure your working directory
is ./bin and execute the binary.

## Legal Notice
Rockman X Fossil Hunter is a FOSS (Free, Open Source Software) fan game. Code is licensed under the AGPL.
It is not affiliated, associated, authorized, endorsed by, or in any way officially connected with CAPCOM<br>
Sprites are my own work, these are licensed under CC-BY-SA 4.0, however Rockman X / Mega Man X is property of CAPCOM.
