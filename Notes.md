# Overview

v1 of the waypoint manager will involve reading text, parsing it into JSON, and converting that into button presses on the UFC and AMPCD.

Notes and restrictions for v1:

- No precise coordinates
- No bullseye entry
- Assumes HSI set up on AMPCD
- Assumes entry of waypoints starting from the user selected waypoint.
- Combat flight exports as decimal degrees, need to convert to degrees and decimal minutes
- Sequence is not supported in v1


Future Considerations:

1. Web or desktop application to convert, preview, and manage waypoints
2. Socket connection and export.lua
3. Support for resuming interrupted input
4. JDAM PP input


# Hornet Inputs

UFC Device Number: 25

```devices["UFC"]						= counter()--25     -- Electronic Equipment Control (UFC) - C-10380/ASQ```

AMPCD Device Number: 37

```devices["AMPCD"]					= counter()--37     -- Advanced Multipurpose Color Display - ???```

UFC Inputs:

BTN 1     : 111
BTN 2 (N) : 112
BTN 3     : 113
BTN 4 (W) : 114
BTN 5     : 115
BTN 6 (E) : 116
BTN 7     : 117
BTN 8     : 118
BTN 9 (S) : 119
BTN 10    : 120
CLR       : 121
ENT       : 122

OSB 1 (POSN) : 100

```
elements["pnt_111"]		= short_way_button(_("UFC Keyboard Pushbutton, 1"),						devices.UFC, UFC_commands.KbdSw1,		111)
elements["pnt_112"]		= short_way_button(_("UFC Keyboard Pushbutton, 2"),						devices.UFC, UFC_commands.KbdSw2,		112)
elements["pnt_113"]		= short_way_button(_("UFC Keyboard Pushbutton, 3"),						devices.UFC, UFC_commands.KbdSw3,		113)
elements["pnt_114"]		= short_way_button(_("UFC Keyboard Pushbutton, 4"),						devices.UFC, UFC_commands.KbdSw4,		114)
elements["pnt_115"]		= short_way_button(_("UFC Keyboard Pushbutton, 5"),						devices.UFC, UFC_commands.KbdSw5,		115)
elements["pnt_116"]		= short_way_button(_("UFC Keyboard Pushbutton, 6"),						devices.UFC, UFC_commands.KbdSw6,		116)
elements["pnt_117"]		= short_way_button(_("UFC Keyboard Pushbutton, 7"),						devices.UFC, UFC_commands.KbdSw7,		117)
elements["pnt_118"]		= short_way_button(_("UFC Keyboard Pushbutton, 8"),						devices.UFC, UFC_commands.KbdSw8,		118)
elements["pnt_119"]		= short_way_button(_("UFC Keyboard Pushbutton, 9"),						devices.UFC, UFC_commands.KbdSw9,		119)
elements["pnt_120"]		= short_way_button(_("UFC Keyboard Pushbutton, 0"),						devices.UFC, UFC_commands.KbdSw0,		120)
elements["pnt_47_121"]	= short_way_button(_("UFC Keyboard Pushbutton, CLR"),					devices.UFC, UFC_commands.KbdSwCLR,		121)
elements["pnt_47_122"]	= short_way_button(_("UFC Keyboard Pushbutton, ENT"),					devices.UFC, UFC_commands.KbdSwENT,		122)
```

AMPCD Inputs:

DATA        : AMPCD PB 10 : 192

WYPT UP     : AMPCD PB 12 : 194
WYPT DOWN   : AMPCD PB 13 : 195

DATA>UFC    : AMPCD PB 5  : 187