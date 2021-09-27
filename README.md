# dcs-waypoint-manager

System for automated input of waypoints in DCS F/A-18C. This reads in a file with a JSON Array of endpoints, and inputs them into the F/A-18 hornet.

This is useful on multiplayer servers where you may not have a configured mission at spawn, and will need to input multiple waypoints.

## Installation:

Copy the `Scripts` folder into your `Saved Games/DCS` folder.

Add this line to your Export.lua file:

```
local wyptmgrlfs = require('lfs'); dofile(wyptmgrlfs.writedir()..[[Scripts\WaypointManager\WaypointManager.export.lua]])
```

## Usage:

### Setup:

In your `Saved Games/DCS` folder create a folder `WaypointManager`. Create a `coords.json` file and add contents in this format:

Note, this is the format in which CombatFlite exports JSON.

x represents longitude in decimal degrees. y represents latitude in decimal degrees.

```
[
  {
    "x": 34.3042667639525,
    "y": 35.3303223621309
  },
  {
    "x": 35.3535317088892,
    "y": 35.5062266808792
  },
  {
    "x": 35.7012880906397,
    "y": 34.7970285909108
  },
  {
    "x": 34.8718691341659,
    "y": 34.5883319604829
  },
  {
    "x": 34.4281799574498,
    "y": 34.9740883629481
  }
]
```

You can have multiple JSON files in this folder, you will be able to select between them in the jet.

### In-Game

1. When loaded into the Hornet, ensure you have your HSI up on your AMPCD. The script will start entering on the currently selected waypoint. If you need to offset, increment the waypoints.
2. Press the hotkey set up in the Waypoint Manager config (`Ctrl-Shift-z` by default). You will see a window open with the file contents and a `Go` Button.
3. Press the `Go` button. Using a combination of AMPCD and UFC buttons the script will input the waypoints.

Notes:

- Inputing coordinates more than once is not supported. This could have unexpected results.
- This will not create a waypoint sequence.
- You are free to interact with the cockpit or alt-tab out. The script will not be interrupted by radio usage, etc.
  - **Usage of the UFC or AMPCD while the script is running will cause unexpected behavior. Do not do anything that will change the UFC context**
- Once started, the script will not stop until it has attempted to input all of the given waypoints.

## Known Bugs

1. Entering waypoints a second time will cause all waypoints to enter twice
2. Display issues on reading file.

## Future Features

1. Interrupting or cancelling waypoint input
2. Creating waypoint sequences
3. Setting waypoints as Bullseye
4. Use of precise coordinates
5. Setting up pre-planned missions for JDAMs and JSOWs

# Attributions and Kudos

I am not an expert lua developer--most of this was assembled using code samples, concepts, and references from:

1. DCS Scratchpad
2. VAICOM Pro export.lua
3. DCS-SRS export.lua
