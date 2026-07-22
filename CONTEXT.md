# Oath of the Frost-Crown Campaign

The campaign context describes how playable Levels, combat outcomes, and Stories form the player's ordered journey through the game.

## Language

**Campaign Prologue Page**:
The single-page narrative preface with narrative-page music presented after the Player starts the campaign and before the Input Guide. It is distinct from the later playable Level 00 narrative sequence.
_Avoid_: Level 00, Opening Story, prologue Level

**Input Guide**:
The campaign instruction page presented after the Campaign Prologue Page. Continuing from it begins Level 01 and its Opening Story.
_Avoid_: Campaign Prologue Page, Opening Story

**Continuation Input**:
A new keyboard-key, mouse-button, gamepad-button, or touchscreen press received after the Campaign Prologue Page or Campaign Epilogue Page becomes active. Releases, key-repeat echoes, pointer motion, and analog-axis motion are not Continuation Inputs, and the input that opens a page cannot also continue past it.
_Avoid_: Any input event, held input, opening input

**Level Completion**:
The successful combat outcome of a Level. It begins that Level's Victory Story when one exists; it does not itself advance to the next Level.
_Avoid_: Level ending, campaign completion

**Victory Story**:
The closing narrative phase that follows Level Completion. Only after the Victory Story finishes may the campaign advance to another Level or enter its final terminal presentation.
_Avoid_: Ending, result screen

**Opening Story**:
The introductory narrative phase of a newly active Level. In Level 01 through Level 04, it begins after that Level's Act Announcement and together with its campaign music; gameplay remains unavailable until the Story finishes, after which that same Level enters Level Initialization.
_Avoid_: Victory Story, Level Initialization

**Act Announcement**:
The silent title-card narrative beat immediately preceding the Opening Story of Level 01 through Level 04. It identifies that Level's numbered Act and title, and remains distinct from the Opening Story itself.
_Avoid_: Opening Story, Campaign Prologue Page, Level title

**Valdemar Pre-Awakening Story**:
The one-time Level 04 narrative phase that begins when the Player first enters Valdemar's throne-room boundary during the initial story-bearing attempt. It pauses gameplay before Valdemar Awakening begins; finishing it immediately begins that awakening, while a retry omits this Story and begins the awakening directly at the boundary.
_Avoid_: Opening Story, Victory Story, Valdemar Awakening, replayed retry Story

**Valdemar Post-Defeat Story**:
The Level 04 Victory Story that begins only after Valdemar's complete death motion reaches its retained Dying presentation and constitutes Level 04 Completion.
_Avoid_: Health-depletion Story, interrupted death motion, ordinary post-combat dialogue

**Level Advancement**:
The replacement of the completed Level with a newly initialized next Level after its Victory Story finishes.
_Avoid_: Level Completion, scene jump

**Level Initialization**:
The playable starting state of a newly active Level: full Player health, visible HUD, available controls, the Player Camera active, no result interface, and an unpaused campaign. A Level without an Opening Story enters this state immediately.
_Avoid_: Scene instantiation, Level Advancement

### Combat

**Player Hurt Immunity**:
The temporary protection that follows accepted non-lethal damage to the Player and rejects otherwise applicable damage until the Player's hurt response finishes. It is distinct from explicit damage immunity granted for a cinematic or terminal outcome.
_Avoid_: Invincibility, damage immunity, invincibility frames

**Persistent Damage Contact**:
The Player's uninterrupted physical contact with a damage source that remains able to deal damage over time, such as a living Enemy's body or an active Black Water Field; separation, loss of the source's damage capability, explicit Player damage immunity, or a terminal outcome makes the contact invalid. If contact remains valid when Player Hurt Immunity ends, one contact immediately produces another complete accepted-damage response—including health loss, the hurt event and presentation, knockback, and renewed Player Hurt Immunity—without requiring contact re-entry; the contact need not be the source that started the immunity and remains applicable if it began or attempted damage during that immunity, while simultaneous contacts cannot produce additional accepted damage during the renewed immunity.
_Avoid_: Skill hit, repeated hit from one skill release, contact re-entry, originating damage source

**Black Water Field**:
The Level 04 field associated with Valdemar's Black Water Cast. It rests below the playable ground between casts and becomes hazardous through its cast motion whenever Valdemar requests it; while it overlaps the Player, uninterrupted contact deals one damage per accepted hit and follows Persistent Damage Contact rather than the once-per-release rule used by ordinary skill hits. Its accepted hits use the ordinary source-relative knockback and Player damage response without a Black Water-specific exception.
_Avoid_: One-hit skill, Valdemar contact damage, permanent terrain hazard

**Boss Stability**:
The rule that accepted damage never displaces a Boss, although it may still reduce health, grant hurt immunity, or cause a hurt presentation according to that Boss's current action. Every Boss retains its position instead of inheriting ordinary Enemy hurt knockback.
_Avoid_: Damage immunity, skill immunity, ordinary Enemy knockback

**Valdemar**:
The final Boss encountered in the Level 04 throne room. He has fifteen maximum health and remains in his Normal Form until the Valdemar Awakening turns him into Dark Mode.
_Avoid_: King, Elk King, generic species King

**Valdemar Awakening**:
The one-time transition that begins when the Valdemar Pre-Awakening Story finishes during the initial story-bearing Level 04 attempt, or immediately when the Player enters the throne-room boundary on a retry. The boundary extends four hundred horizontal pixels from Valdemar regardless of height; he cannot pursue, perform active attacks, take damage, or progress his Black Water Cycle before this transition finishes, whose completion enters Dark Mode, enables his active combat behavior, and begins the first Black Water Cycle.
_Avoid_: Level initialization, Boss Door crossing, preloaded Dark Mode

**Valdemar Health Presentation**:
The Boss Health Bar representing Valdemar's fifteen health. It remains hidden throughout Normal Form and Valdemar Awakening, becomes visible when Dark Mode begins, reflects each accepted damage event, and disappears on Valdemar Defeat.
_Avoid_: Player HUD health, pre-awakening health bar, Normal Form damage

**Valdemar Hurt**:
The four-tenths-second non-lethal damage response that stops Valdemar's pursuit or sword-cooldown waiting without displacing him, presents his full hurt motion, and then resumes pursuit when hurt immunity finishes. Damage accepted during a Sword Gleam still reduces health and grants the same hurt-immunity interval without changing that attack's position, facing, or presentation, while damage attempted during a Black Water Cast is rejected by Valdemar Black Water Immunity.
_Avoid_: Boss knockback, cast interruption, Awakening damage

**Valdemar Contact Damage**:
The one damage dealt through physical contact with Valdemar in Normal Form, during Valdemar Awakening, or throughout Dark Mode, followed by the Player's ordinary knockback and hurt immunity. It is passive rather than an active attack and ends only on Valdemar Defeat.
_Avoid_: Sword Gleam, contact-safe form, repeated damage during Player hurt immunity

**Valdemar Sword Pursuit**:
Valdemar's unbounded Dark Mode movement at one hundred fifty pixels per second, independent of a Skill Detection Area. When his and the Player's vertical coordinates differ by fewer than ten pixels, he pursues the Player's body; otherwise, he locks the position that would align his currently facing Sword Gleam with the Player, turns before running there when necessary, and then turns back to present that Sword Gleam at the Player, while Sword Gleam readiness never changes either target or makes him reverse solely to create or preserve alignment.
_Avoid_: Enemy patrol, bounded chase, proximity-gated chase, physical floor contact

**Valdemar Facing-Coherent Movement**:
The rule that Valdemar always faces the direction of his horizontal movement. Before any pursuit movement whose direction differs from his facing, he turns to that direction first; he never slides or runs backward.
_Avoid_: Backpedaling, backward run, movement-facing mismatch

**Valdemar Sword Gleam**:
A half-second Dark Mode attack that is immediately available upon entering Dark Mode and begins whenever the ready Sword Gleam's horizontal center reaches or crosses the Player's horizontal coordinate through pursuit movement, or becomes exactly aligned when Valdemar turns back at a locked destination; changing facing anywhere else does not count as crossing or alignment. It pairs Valdemar's locked attack position and facing with the Guard Sword Gleam, deals one damage to a given target at most once, and starts an independent four-second cooldown that continues through pursuit, hurt, and Black Water Cast; non-lethal damage cannot interrupt a release, while Valdemar Defeat prevents any further damage from it.
_Avoid_: Guard Sword Gleam cooldown, Valdemar skill presentation, contact damage

**Valdemar Black Water Cycle**:
The repeating sixteen-second interval that begins when Valdemar enters Dark Mode. A completed interval makes one Black Water Cast due and takes priority over a Sword Gleam that has not started; it remains as one pending cast while an active Sword Gleam or hurt presentation finishes, and restarts only when that cast actually begins.
_Avoid_: Ten-second signal interval, immediate first request, Sword Gleam

**Valdemar Black Water Cast**:
A stationary six-second skill presentation that begins facing the Player, locks Valdemar's position and facing, presents nine frames over its first three seconds, and deliberately holds its final frame for the remaining three. It requests exactly one Black Water Field cast when it begins, grants Valdemar Black Water Immunity, and prevents pursuit or Sword Gleam until it finishes; Valdemar Defeat clears any pending cast and stops all future Black Water Cycles, while defeat through incoming damage cannot occur during an active cast.
_Avoid_: Sword Gleam, interruptible cast, permanent Black Water hazard

**Valdemar Black Water Immunity**:
The explicit damage immunity lasting for the full Valdemar Black Water Cast. Every incoming damage attempt during this interval is rejected without changing health, beginning hurt immunity, or presenting Valdemar Hurt.
_Avoid_: Valdemar Hurt, cast interruption, Sword Gleam damage handling

**Valdemar Defeat**:
The Boss combat outcome reached when Valdemar's health is depleted. It disables his pursuit, attacks, Black Water Cycle, and combat collisions, hides his Health Bar, and preserves his position and facing through the complete dead motion into the retained Dying presentation; it remains distinct from the later Level 04 Completion.
_Avoid_: Level 04 Completion, immediate cleanup

**Level 04 Completion**:
The successful Level 04 outcome reached when Valdemar's complete death motion enters its retained Dying presentation and emits one `died` event. It immediately begins the Valdemar Post-Defeat Story rather than occurring when his health is first depleted.
_Avoid_: Valdemar Defeat, health depletion, interrupted death motion

**Level 04 Terminal Outcome Lock**:
The first confirmed health depletion between the Player and Valdemar irreversibly fixes Level 04's terminal outcome, including when both occur during the same physics frame. Valdemar Defeat first immediately hides the HUD, removes Player control, and grants terminal Player damage immunity so no lingering combat effect can replace the victory, while Player Defeat first prevents any later Valdemar Defeat from replacing the loss; Level 04 Completion still waits for Valdemar's complete death motion after a locked victory.
_Avoid_: Simultaneous terminal presentations, same-frame outcome replacement, delayed victory decision

**Level 04 Closing Tableau**:
The non-interactive combat composition retained through the Valdemar Post-Defeat Story, with Valdemar in his Dying presentation, the HUD hidden, and Player control unavailable. When that Story finishes, the campaign leaves this tableau for the Campaign Epilogue Page.
_Avoid_: Campaign Epilogue Page, result screen, restored gameplay

**Campaign Epilogue Page**:
The single-page narrative conclusion with narrative-page music presented after the Valdemar Post-Defeat Story and after Level 04 and its music have ended. Continuing from it enters the Producer Page.
_Avoid_: Valdemar Post-Defeat Story, Level 04 Closing Tableau, result screen

**Producer Page**:
The campaign's final presentation with narrative-page music entered from the Campaign Epilogue Page. It remains visible indefinitely and does not accept Continuation Input or initiate another campaign transition.
_Avoid_: Campaign Epilogue Page, title page, restart page

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
The terminal Level 03 presentation held on the final frame of the Elk King's death presentation, with the Player Camera holding the final composition and the HUD remaining hidden. Reaching it constitutes Level Completion and immediately begins the Level 03 Victory Story without an intervening transition or result interface; the tableau remains while that Story plays, with the Player hidden, unavailable, and absent from physical interaction, until Level Advancement disposes the whole Level 03 session.
_Avoid_: Automatic Level disposal, restored Player control

**Level 03 Terminal Outcome Lock**:
The first confirmed health depletion between the Player and the Elk King fixes Level 03's terminal presentation. Elk King Defeat prevents any later Player Defeat, while an already confirmed Player Defeat prevents Elk King Death Staging from starting; neither result can replace the other afterward.
_Avoid_: Simultaneous terminal presentations, late outcome replacement

**Elk Shield**:
A passive, rechargeable protection possessed by an Elk or Elk King that negates one otherwise applicable incoming damage event, regardless of the damage source, while the protection is available. Damage already rejected by another immunity or invalid actor state does not consume it; negating damage starts a Shield Break Window without changing health or causing knockback.
_Avoid_: Weapon block, damage immunity

**Elk Shield Cooldown**:
The fixed five-second interval after an Elk's Shield Break Window ends and before its shield becomes visible and available again. Damage received during this interval is resolved normally and neither resets nor extends it.
_Avoid_: Thunder cooldown, hurt immunity

**Player Shield**:
A passive, rechargeable protection possessed by Player 04 that begins each Level instance available and negates one otherwise applicable incoming damage event, regardless of the damage source. Damage already rejected by another immunity or invalid actor state does not consume it; negating damage starts a Shield Break Window without changing health or causing knockback.
_Avoid_: Elk Shield, damage immunity, weapon block

**Shield Break Window**:
The interval in which a spent Player or Elk Shield presents its break and rejects every further damage event without causing a hit reaction, knockback, action interruption, or loss of Player control. It lasts until that presentation finishes; further hits do not repeat or change its presentation or timing, after which the shield's five-second cooldown begins and a still-valid Persistent Damage Contact may immediately damage the Player without requiring contact re-entry.
_Avoid_: Shield Cooldown, hurt immunity, reusable protection

**Player Shield Cooldown**:
The fixed five-second interval after Player 04's Shield Break Window ends and before the Player Shield becomes visible and available again. Damage received during this interval is resolved normally and neither resets nor extends it.
_Avoid_: Elk Shield Cooldown, hurt immunity
