# Fix for NPC Attack Animation Duplication Issue

## Root Cause
Multiple animation tasks are being spawned for the same NPC faster than they can complete, causing animations to stack and loop. The code has an `animation_manager` class specifically designed to prevent this, but it's not being used.

## Solution Overview
1. Initialize animation manager for each spawned NPC
2. Use animation manager to control animations (prevents overlaps)
3. Clean up animation manager when NPC dies

---

## FIX #1: Initialize Animation Manager (Line ~2415)

**Search for:**
```verse
# SETUP NPC BEHAVIOR
EnemyID := State.Enemies.Length

if:
    BehaviorClass := SpawnedAgent.GetNPCBehavior[]
    EnemyBehavior := tower_defense_enemy_behavior[BehaviorClass]
then:
    set EnemyBehavior.Controller = Self
    set EnemyBehavior.EnemyID = EnemyID
    set EnemyBehavior.OwnerAgent = option{Agent}
    EnemyBehavior.ReadyEvent.Signal()
```

**Add immediately after `EnemyBehavior.ReadyEvent.Signal()`:**
```verse
                                    # ✅ FIX: INITIALIZE ANIMATION MANAGER FOR THIS NPC
                                    if (set AnimationManagers[SpawnedAgent] = animation_manager{}) {}
```

---

## FIX #2: Use Animation Manager (Line ~2850)

**Search for:**
```verse
                                    # ✅ PROPER ANIMATION MANAGEMENT - PASS CURRENT DEFENDER'S CANCEL EVENT
                                    if (TheAnim := AttackAnimToUse?):
                                        spawn{PlayAttackAnimSpawn(Anim, TheAnim, EnemyAgent, CurrentDefenderCancelEvent)}
                                    
                                    Sleep(Atk.AttackInterval)
```

**Replace with:**
```verse
                                    # ✅ FIX: USE ANIMATION MANAGER TO PREVENT OVERLAPPING ANIMATIONS
                                    if (TheAnim := AttackAnimToUse?):
                                        if (AnimMgr := AnimationManagers[EnemyAgent]):
                                            AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval)
                                        else:
                                            Print("⚠️ WARNING: No animation manager for NPC {EnemyID}")
                                    
                                    Sleep(Atk.AttackInterval)
```

---

## FIX #3: Clean Up Animation Manager (Line ~3135)

**Search for:**
```verse
                                    # KILL THE NPC
                                    if (EnemyChar2 := CurrentEnemy.Agent.GetFortCharacter[]):
                                        if (DamageableNPC := damageable[EnemyChar2]):
                                            DamageableNPC.Damage(10000.0)
                                    
                                    # Clean up HP bar
                                    if (HPBar := CurrentEnemy.HealthBarProp?):
                                        HPBar.Dispose()
```

**Add immediately after HP bar disposal:**
```verse
                                    # ✅ FIX: CLEANUP ANIMATION MANAGER FOR DEAD NPC
                                    var NewAnimMgrs : [agent]animation_manager = map{}
                                    for (Key -> Value : AnimationManagers):
                                        if (Key <> CurrentEnemy.Agent):
                                            if (set NewAnimMgrs[Key] = Value) {}
                                    set AnimationManagers = NewAnimMgrs
```

---

## OPTIONAL FIX #4: Clean Up on Player Leave

**Search for `OnPlayerLeft` function (Line ~860) and find:**
```verse
                # Clean up carried defenders for this player
                var NewCarriedList : []carried_defender = array{}
                for (Carried : CarriedDefenders):
                    if (Carried.CarryingAgent <> Agent):
                        set NewCarriedList += array{Carried}
                    else:
                        if (Carried.Prop.IsValid[]):
                            Carried.Prop.Dispose()
                set CarriedDefenders = NewCarriedList
```

**Add immediately after:**
```verse
                # ✅ FIX: CLEANUP ANIMATION MANAGERS FOR THIS PLAYER'S NPCS
                var NewAnimMgrs : [agent]animation_manager = map{}
                for (EnemyKey -> AnimMgr : AnimationManagers):
                    var KeepThis : logic = true
                    for (Enemy : State.Enemies):
                        if (Enemy.Agent = EnemyKey):
                            set KeepThis = false
                    if (KeepThis?):
                        if (set NewAnimMgrs[EnemyKey] = AnimMgr) {}
                set AnimationManagers = NewAnimMgrs
```

---

## How It Works

The `animation_manager` class (already in your code) has this logic:

```verse
StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float):void =
    # Only start if not already playing  ← PREVENTS OVERLAPS!
    if (IsPlaying = false):
        set IsPlaying = true
        spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
```

When you call `StartAnimation`:
- **If no animation is playing**: Starts the animation and sets `IsPlaying = true`
- **If animation is already playing**: Does nothing (silently ignores the request)
- **After animation finishes**: Sets `IsPlaying = false` so next one can start

This prevents multiple animation tasks from running simultaneously on the same NPC.

---

## Testing

After applying all fixes:
1. Start a round and let NPCs attack defenders
2. Let NPCs kill the first defender and move to the second
3. **Expected**: Attack animations should play smoothly, one at a time
4. **Previous bug**: Animations would stack/loop/duplicate
5. When wave respawns with new NPCs, they should also work correctly

---

## Why Your Previous Fix Didn't Work

Adding `CurrentDefenderCancelEvent.Signal()` only cancels animations when moving between defenders, but doesn't prevent NEW animations from overlapping with CURRENTLY PLAYING animations. The animation manager prevents this at the source by refusing to start a new animation if one is already running.
