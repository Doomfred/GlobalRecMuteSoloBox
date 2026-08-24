# GlobalRecMuteSoloBox v1.1.5

Upload/replace the contents of this archive at the repository root.

Then:
1. Commit to `main`.
2. In REAPER: Extensions > ReaPack > Synchronize packages.
3. Run `Global Rec Mute Solo - Enable at REAPER startup` once again.
4. `Scripts/__startup.lua` should now use `reaper.GetResourcePath()` instead of an absolute Windows user path.
