# Oath of the Frost-Crown Campaign

The campaign context describes how playable Levels, combat outcomes, and Stories form the player's ordered journey through the game.

## Language

**Level Completion**:
The successful combat outcome of a Level. It begins that Level's Victory Story when one exists; it does not itself advance to the next Level.
_Avoid_: Level ending, campaign completion

**Victory Story**:
The closing narrative phase that follows Level Completion. The campaign advances only after the Victory Story finishes.
_Avoid_: Ending, result screen

**Level Advancement**:
The replacement of the completed Level with a newly initialized next Level after its Victory Story finishes.
_Avoid_: Level Completion, scene jump

**Level Initialization**:
The playable starting state of a newly active Level: full Player health, visible HUD, available controls, the Player Camera active, no result interface, and an unpaused campaign. A Level without an Opening Story enters this state immediately.
_Avoid_: Scene instantiation, Level Advancement

### Combat

**Skill Detection Area**:
The forward-facing region in which the Player's presence allows an Enemy to initiate its species skill.
_Avoid_: Aggro range, attack range

**Elk Thunder Strike Point**:
A grounded location whose horizontal coordinate is randomly selected from an Elk's Skill Detection Area when its thunder skill begins.
_Avoid_: Elk position, Player position

**Elk Thunder Cast**:
A stationary Enemy skill during which an Elk pauses its patrol, releases thunder at its selected Elk Thunder Strike Point, and then resumes its prior behavior.
_Avoid_: Thunder pursuit, moving cast

**Elk Shield**:
A rechargeable protection that negates one incoming damage event against an Elk, regardless of the damage source, while the protection is available. It then becomes unavailable for five seconds without causing a hit reaction or interrupting the Elk's current behavior.
_Avoid_: Weapon block, damage immunity

**Elk Shield Cooldown**:
The fixed five-second interval after an Elk Shield negates damage and before it becomes available again. Damage received during this interval neither resets nor extends it.
_Avoid_: Thunder cooldown, hurt immunity
