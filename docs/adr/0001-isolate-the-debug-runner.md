# Isolate the Debug Runner from the production campaign entry

The Debug Runner is a separate development scene that reuses the production Campaign orchestration without adding debug input to the production Main entry. It owns eight checkpoint slots addressed by `Ctrl+1` through `Ctrl+8`; each consecutive pair starts one of Level01 through Level04, first with its Opening Story and then in its playable initialized state. Debug health overrides use explicit Debug Build-only Player and Enemy interfaces, giving the Player 999 health and each Enemy 1 health without adding debug health presentation.

This keeps level transitions and completion Stories representative of production while preventing debug shortcuts and combat overrides from becoming normal campaign behavior. Re-entering a checkpoint replaces the active Level with a fresh instance, including while a Story has paused the scene tree or a result popup is visible.
