# MapIconCompletionMarkerMod
This is a mod for Oblivion Remastered that allows you to to manually mark world map icons as completed.
This helps you track what you've finished, which is especially useful for Oblivion Gates and dungeons.

Available for download on Nexus Mods!

## Usage
1. Open the World Map.
2. Hover over any icon.
3. Press Shift to switch the icon to its "completed" state.
4. Press Shift again to toggle it back to "uncompleted."

The icon toggle states are saved across game sessions in the `toggled_icons.json` file.
You can manually edit this file if needed.

## Installation
1. Download and install UE4SS.
2. Download the zip file and extract the contents.
3. Place the `MapIconCompletionMarkerMod` folder into `Steam\steamapps\common\Oblivion Remastered\OblivionRemastered\Binaries\Win64\Mods`.

## FAQ
Q: Does this work with controller input?
A: No, currently only Shift on keyboard is supported. Controller support may be added in the future.

Q: Will this break quests or other mods?
A: No, this is a visual change only. Functionality is not affected.

Q: Are the toggle states recorded in my save game?
A: No. Toggle states are saved globally in a JSON file, not in your individual save games. This means if you load an older or different save, your previously toggled icons will still appear as completed (or not) based on the shared data.

Q: Will Oblivion Gates be marked as completed automatically?
A: No, you have to mark them yourself - for now!
