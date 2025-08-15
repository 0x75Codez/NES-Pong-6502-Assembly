# NES-Pong-6502-Assembly-
A minimalist Pong clone for the Nintendo Entertainment System, written entirely in 6502 assembly. Player 1 uses the NES controller to control the left paddle, while a simple AI controls the right paddle.

# Features

Written from scratch in pure 6502 assembly.

Player 1: Up/Down on the NES D-Pad.

Simple but effective AI opponent.

Score display for both players (resets after a win).

Collision detection for paddles, ball, and walls.

Center dashed line drawn using background tiles.

Fully functional NES .nes ROM with proper iNES header.

# Code Overview

Header & Vectors – Proper iNES header and interrupt vectors.

Zero Page Variables – Ball position, paddle positions, velocities, scores, etc.

Game Loop – Runs every NMI, updating logic and rendering.

Paddle AI – Simple "follow the ball" logic with a dead zone.

Collision Detection – Handles paddle hits, wall bounces, and scoring.

CHR Tiles – Ball, paddles, center line, and number sprites embedded in ROM.

# Controls

Use a NES Controller 

You can also use a Emulator (like Mesen, which I used) 
https://www.mesen.ca

# Compiling

Compile with a 6502 Assembly Compiler like NESASM or CA65 

Compiler Commands for CA65 (which I used) https://cc65.github.io/

./ca65 game.asm -o game.o
./ld65 -C nes.cfg game.o -o game.nes

# Fun Fact

The NES’s PPU renders backgrounds and sprites separately, so the center dashed line is drawn in the background layer, while paddles and ball are sprites.
