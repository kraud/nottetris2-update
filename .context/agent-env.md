# Agent Execution & Environment Automation Spec

This document instructs the agent on how to run the game, read debug outputs, and cycle through the testing loop on macOS.

## 1. The Execution Command
To run the project from source code without archiving it, the agent must invoke the LÖVE binary via the macOS absolute application path, pointing it to the current directory (`.`):

```bash
/Applications/love.app/Contents/MacOS/love .


## 2. Debug Panel
Press F12 on the title screen to open the `debug_params` tuning panel (`gameBdebug.lua`). Press Escape to close. Values are saved to `options.txt`.