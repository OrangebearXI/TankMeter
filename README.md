# TankMeter for Windower4

TankMeter is a simple Windower4 addon for Final Fantasy XI. It shows two small windows on screen. 
The main UI is a compact table of your defensive performance. 
The mini UI shows your current Block percent and Parry percent. 
Both windows are on by default and do not overlap at their default positions.

## What it tracks

TankMeter watches action packets for attacks against your character and updates in real time.

It counts an opportunity when the result is any of the following:
- block
- parry
- evade or miss
- hit

By default, Utsusemi or any shadow loss does not count toward the denominator. 
You can include shadows by changing a boolean in the settings section inside the Lua file. 
Look for `behavior.include_shadows_in_denominator`.

Minimum tracked totals:
- opportunities
- total blocked
- total parried
- total evaded or missed
- total shadows taken
- total physical hits and sum of physical damage
- min and max physical damage when blocked
- total magic hits and sum of magic damage
- max hit overall

Block percent and Parry percent are computed from the chosen denominator and are shown with one decimal place.

## What you see

**Main UI columns, in order**
1. Name  
2. Block percent  
3. Parry percent  
4. EvaMiss percent  
5. Tot. Block  
6. Block Min  
7. Block Max  
8. Avg. Phys Hit  
9. Avg. Mag Hit  
10. Max Hit

Headers use white text with a light sky blue style stroke. 
The data row uses white text with no stroke. 
The background for each window is a single semi transparent rectangle.

**Mini UI**
- Labels: “Block %” and “Parry %” use the stroked header style.
- Numbers: white with no stroke.

## Install

1. Create a folder: `Windower/addons/TankMeter`
2. Copy `TankMeter.lua` into that folder.
3. In game run: `//lua l tankmeter`

The addon loads with both windows visible and placed at these defaults:
- Main UI at x 300, y 150
- Mini UI at x 300, y 120

## Commands

All commands work under `//tankmeter` and the short alias `//tm`.

- `//tm help`  
  Print a short help line.

- `//tm main on` or `//tm main off`  
  Show or hide the main window **including** all text and the background.

- `//tm mini on` or `//tm mini off`  
  Show or hide the mini window.

- `//tm lock on` or `//tm lock off`  
  Lock or unlock dragging for both windows.

- `//tm pos x y`  
  Move the main window and save.

- `//tm minipos x y`  
  Move the mini window and save.

- `//tm font <name>`  
  Set the font. Example `//tm font Segoe UI`

- `//tm size <n>`  
  Set the font size. Example `//tm size 9`

- `//tm alpha <0..255>`  
  Set the background alpha for both windows.

Positions, font, size, and alpha are saved when you change them.

## Behavior notes

- No flicker. Texts and backgrounds are created once and updated only when content changes.
- The addon tracks your character only. There is no party or alliance logic.
- Spacing adapts to content and leaves extra room to avoid overlap. The Name column reserves space for 17 characters.

## Troubleshooting

- **Main window toggle hides the whole block**  
  Use `//tm main off` to hide the headers, data, and background together. Use `//tm main on` to show again.

- **Mini window moved in parts**  
  Only the “Block %” label is a drag handle. The values and “Parry %” move with it.

- **Want to include shadows in the denominator**  
  Open `TankMeter.lua`, find `behavior.include_shadows_in_denominator`, and set it to `true`. Save and reload the addon.

- **Need more spacing**  
  Increase font size with `//tm size 9` or higher. If you need fixed pixel changes to gaps, open an issue and include a screenshot.

## Known limits

- Only outcomes visible in action packets are counted. 
- If a third party addon changes fonts globally, you may need to reload TankMeter so it can measure text again.

## Uninstall

1. In game run: `//lua u tankmeter`
2. Delete the `Windower/addons/TankMeter` folder.

## Credits

- Author: Orangebear  
- Built for Windower4 using `texts`, `prim`, and `resources`

## Changelog highlights

- 1.0.7  
  `//tm main on|off` now hides or shows the entire main UI block, not only the background.
- 1.0.6  
  Mini UI is grouped as a single block. Labels stroked, numbers white with no stroke.
- 1.0.5  
  Wider spacing and a fixed minimum width for the Name column.  
- 1.0.4 and earlier  
  Layout stability and flicker fixes.

---

### License

This project is released under the MIT License. See `LICENSE` if included in the repository.
