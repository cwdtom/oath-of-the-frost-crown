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

**Elk King**:
A Boss variant of the Elk with ten maximum health that retains the Elk's thunder and passive shield while adding an independently triggered earthquake ability.
_Avoid_: Generic multi-skill Enemy, unrelated Enemy species

**Skill Detection Area**:
The forward-facing region in which the Player's presence allows an Enemy to initiate its species skill whenever that skill is ready. Remaining inside continues to satisfy this condition, so an Enemy releases the skill again when its cooldown ends without requiring the Player to leave and re-enter.
_Avoid_: Aggro range, attack range

**Hurt Completion Before Skill**:
The rule that an Enemy completes its non-lethal hurt presentation and associated hurt immunity before starting a ready skill. If the Player remains in the Skill Detection Area, the Enemy begins casting as soon as the hurt state finishes.
_Avoid_: Skill-interrupted hurt, early hurt-immunity termination

**Guard**:
An Enemy with three maximum health that uses the standard Enemy patrol and Skill Detection Area behavior to release Sword Gleam.
_Avoid_: Player-controlled guard, stationary sentry

**Guard Sword Gleam**:
A Guard skill whose synchronized attack motion, sword effect, and damage region are always presented on the side the Guard is facing. Each release deals one damage to a given target at most once and starts a five-second cooldown; non-lethal damage to the Guard does not interrupt a release already in progress, while Guard Defeat prevents any further damage from that release.
_Avoid_: Guard contact damage, repeated damage from one release, hurt-interrupted Sword Gleam

**Elk Thunder Strike Point**:
A grounded location whose horizontal coordinate is randomly selected from an Elk's Skill Detection Area when its thunder skill begins.
_Avoid_: Elk position, Player position

**Elk Thunder Cast**:
A stationary Enemy skill during which an Elk pauses its patrol, releases thunder at its selected Elk Thunder Strike Point, and then resumes its prior behavior.
_Avoid_: Thunder pursuit, moving cast

**Elk King Active Skills**:
The Elk King's thunder and earthquake abilities, each of which independently becomes releasable while the Player remains in the Elk King's Skill Detection Area and may be released concurrently with the other. Remaining in the area continues to satisfy release without re-entry, while leaving after a cast starts or taking non-lethal damage does not cancel it; the Elk Shield is passive and does not participate in these decisions.
_Avoid_: Random skill selection, mutually exclusive skill selection, Elk King Shield cast

**Elk King Casting Window**:
The interval during which at least one Elk King active skill is still being released. The Elk King remains stationary throughout this interval and resumes its pre-cast patrol or idle behavior only after every concurrent cast has finished.
_Avoid_: Per-skill movement resume, shared skill duration

**Elk King Earthquake Cast**:
An Elk King active skill whose release is presented by the Elk King's skill animation together with an earthquake effect on the side the Elk King is facing when the cast begins. It deals one damage to a given target at most once per cast.
_Avoid_: Passive earthquake, idle-animation earthquake, rear-facing earthquake

**Elk King Casting Presentation**:
The Elk King remains in its idle presentation during a thunder-only cast, while an earthquake cast gives its skill presentation priority over concurrent thunder. If that skill presentation finishes while thunder continues, the Elk King returns to a stationary idle presentation until the Elk King Casting Window ends.
_Avoid_: Thunder skill animation, concurrent animation blending

**Elk King Concurrent Skill Hit**:
The combined two damage received when one Elk King thunder cast and one Elk King earthquake cast each hit the same target. Each cast contributes one independently resolved damage event.
_Avoid_: Single combined hit, duplicate damage from one cast

**Elk King Thunder Cooldown**:
The three-second interval, beginning when a thunder cast starts, during which the Elk King cannot release another thunder cast. It is independent of the Elk King Earthquake Cooldown.
_Avoid_: Elk King Earthquake Cooldown, shared skill cooldown

**Elk King Earthquake Cooldown**:
The five-second interval, beginning when an earthquake cast starts, during which the Elk King cannot release another earthquake cast. It is independent of the Elk King Thunder Cooldown.
_Avoid_: Elk King Thunder Cooldown, shared skill cooldown

**Elk King Defeat**:
The Boss combat outcome reached as soon as the Elk King's health is depleted. Thunder and earthquake casts that started before defeat may finish their visual presentation but can no longer damage the Player; the defeated Elk King remains part of Level 03 until that Level session is disposed, and Elk King Defeat is distinct from Level Completion.
_Avoid_: Level Completion, skill cancellation, Elk King cleanup

**Elk King Death Staging**:
The non-interactive transition between Elk King Defeat and its death presentation: the HUD is hidden, the Elk King faces left, and the damage-immune Player retains terrain physics, landing if necessary before running at normal speed to a point with an actual horizontal separation of 470 pixels on its left. The Player Camera follows this movement; once precisely aligned, the Player faces the Elk King, leaves physical interaction, and is seamlessly replaced by the matching Aila shown in the death presentation.
_Avoid_: Player input, teleport, airborne handoff, scaled local offset, visible character swap

**Elk King Death Tableau**:
The terminal Level 03 presentation held on the final frame of the Elk King's death presentation, with the Player Camera holding the final composition and the HUD remaining hidden. Reaching it constitutes Level Completion and immediately begins the Level 03 Victory Story without an intervening transition or result interface; after that Story finishes, the tableau remains while the Player stays hidden, unavailable, and absent from physical interaction until the whole Level 03 session is disposed externally.
_Avoid_: Automatic Level disposal, restored Player control

**Level 03 Terminal Outcome Lock**:
The first confirmed health depletion between the Player and the Elk King fixes Level 03's terminal presentation. Elk King Defeat prevents any later Player Defeat, while an already confirmed Player Defeat prevents Elk King Death Staging from starting; neither result can replace the other afterward.
_Avoid_: Simultaneous terminal presentations, late outcome replacement

**Elk Shield**:
A passive, rechargeable protection possessed by an Elk or Elk King that negates one incoming damage event, regardless of the damage source, while the protection is available. It then becomes unavailable for five seconds without causing a hit reaction or interrupting the protected Enemy's current behavior.
_Avoid_: Weapon block, damage immunity

**Elk Shield Cooldown**:
The fixed five-second interval after an Elk Shield negates damage and before it becomes available again. Damage received during this interval neither resets nor extends it.
_Avoid_: Thunder cooldown, hurt immunity
