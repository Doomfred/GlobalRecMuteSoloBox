# Global Rec Mute Solo Box

Global Rec/Mute/Solo controls for REAPER.

Main action:
- `Global_Rec_Mute_Solo.lua`

Included helper action:
- `Global_Rec_Mute_Solo_Reset_Settings.lua`

Internal helper:
- `Core.lua`

Requires:
- ReaPack
- js_ReaScriptAPI

Author: **doomfred** (with OpenAI)


## v1.1.0 — lancement automatique

Deux actions sont ajoutées :

- `Global Rec Mute Solo - Enable at REAPER startup`
- `Global Rec Mute Solo - Disable at REAPER startup`

L'activation ajoute un bloc balisé dans `Scripts/__startup.lua` sans effacer
les éventuelles commandes de démarrage déjà présentes.

Le lancement est retardé d'environ 1 seconde afin de laisser REAPER créer
complètement la Main Toolbar et le Transport avant l'affichage du composant.

Le composant reste ensuite actif indépendamment des changements de projet.
