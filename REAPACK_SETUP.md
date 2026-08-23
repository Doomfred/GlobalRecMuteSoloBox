# ReaPack setup

Copy these files/folders into the root of:

`https://github.com/Doomfred/GlobalRecMuteSoloBox`

Keep the existing `LICENSE` and `README.md`.

## Repository URL to import in REAPER

After committing the files to the `main` branch, import this URL in:

**Extensions > ReaPack > Manage repositories > Import**

`https://raw.githubusercontent.com/Doomfred/GlobalRecMuteSoloBox/main/index.xml`

## Repository tree

```text
GlobalRecMuteSoloBox/
├── LICENSE                       (already in your GitHub repository)
├── README.md                     (already in your GitHub repository)
├── index.xml
├── .reapack-index.conf
├── REAPACK_SETUP.md
└── Scripts/
    └── GlobalRecMuteSoloBox/
        ├── Global_Rec_Mute_Solo.lua
        ├── Core.lua
        ├── Global_Rec_Mute_Solo_Reset_Settings.lua
        └── README.md
```

## First test

1. Commit/push the files.
2. Import the `index.xml` URL above in ReaPack.
3. Synchronize packages.
4. Search for **Global Rec Mute Solo**.
5. Install it.
6. Confirm that both actions appear:
   - Global Rec Mute Solo
   - Global Rec Mute Solo - Reset Settings

`Core.lua` is installed as an internal helper and should not appear as an Action.

## Future releases

For long-term version history, use `reapack-index` to regenerate `index.xml`
from Git commits. The bootstrap `index.xml` supplied here uses `main` URLs so
that the first repository can be tested immediately.


## Important correction

The `index.xml` in this archive uses ReaPack's normal XML syntax:
`<link rel="website">URL</link>`.

Replace any previous `index.xml` in the repository root with this corrected file.


## v1.1.0 update

Upload the two new startup helper scripts together with the updated
`Global_Rec_Mute_Solo.lua` and `index.xml`.

After synchronizing ReaPack, run:
`Global Rec Mute Solo - Enable at REAPER startup`

Restart REAPER once to test that the component appears automatically.
