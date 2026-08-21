# AdminRoom

Teleport to admin rooms, change stages, and vote to replay a stage.

## Commands

- sm_adminroom - Teleport anyone to the admin room
- sm_stage - Change the map stage
- sm_adminroom_reloadcfg - Reload both map and keyword configs
- sm_stagevote - Start a vote to pick the next stage (maps with a `votes` config block; see below)
  - sm_potcvote / sm_makovote are kept as aliases of sm_stagevote, so existing maps whose
    entities already call those commands (from sm-plugin-PotcVote / sm-plugin-MakoVote) keep
    working without changes.

## Configuration

### Admin Room Auto-Detection KeyWords

```configs/adminroom/adminroom.cfg```

### Admin Room Map

```configs/adminroom/maps/lowercasemapname.cfg```

Each map config has a `stages` block (see the files under `configs/adminroom/maps/` for real
examples). A stage may set two additional, optional keys:

- `votable` (default `1`) - whether the stage vote can pick this stage. Set to `0` for
  progression stages (e.g. "Normal"/"Hard") that shouldn't be offered again once passed.
- `rtd_percent` (default `0`) - percent chance (1-100) this stage is auto-selected without a
  vote, the first time the vote fires this map (a generalized "roll the dice" bonus stage).

Adding a `votes` block to a map config enables the stage vote for that map:

```
"votes"
{
    "percent"    "60"   // percent of votes the winner needs to avoid a revote
    "delay"      "3.0"  // seconds before the round ends when an admin starts a vote manually
    "countdown"  "3"    // seconds shown to players before the vote menu opens
    "cooldown"   "2"    // most-recently-played stages disabled in the menu before reset
    "actions"            // fired once when a vote starts, e.g. to kill an ambient music entity
    {
        "0"    "ambient_music:Kill"
    }
}
```

Maps without a `votes` block behave as before: sm_stagevote/sm_potcvote/sm_makovote reply that
the vote isn't configured, and the underlying stage vote never triggers.

## API

Other plugins can read the current map's stages and change stages through natives and a
forward declared in `scripting/include/AdminRoom.inc`:

- `AdminRoom_IsEnabled()`
- `AdminRoom_GetStageCount()`
- `AdminRoom_GetStageName(index, buffer, maxlen)`
- `AdminRoom_GetCurrentStage()`
- `AdminRoom_SetStage(index, client=0)`
- `AdminRoom_SetStageByTrigger(trigger, client=0)`
- `forward AdminRoom_OnStageChanged(index, name, client)`
