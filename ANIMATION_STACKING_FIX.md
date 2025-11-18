# Fix for Attack Animation Stacking Issue

## Problem
Attack animations stack when NPCs move from one defender to another. The first defender works fine, but subsequent defenders cause animations to play multiple times.

## Root Cause
1. Broken global cancellation system using class-level variables shared across all NPCs
2. `PreviousAttackTask` never actually set (attack loop runs inline, not as spawned task)
3. Complex cancellation logic that doesn't work as intended
4. Counter system (`ActiveAttackLoops`) that doesn't prevent stacking

## Solution

### 1. Remove Broken Class Variables

**DELETE these lines from tower_defense_controller class:**

```verse
var PreviousDefenderCancelEvent : ?event() = false
var PreviousAttackTask : ?task(void) = false       
var EnemyAnimationPlaying : [agent]?logic = map{}
var ActiveAttackLoops : [agent]int = map{}
```

**KEEP only:**
```verse
var AnimationManagers : [agent]animation_manager = map{}
```

### 2. Replace animation_manager Class

**Replace the entire animation_manager class with:**

```verse
animation_manager := class:
    var IsPlaying : logic = false
    var CurrentDefenderIndex : int = -1
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, DefenderIndex:int):void =
        # If attacking a different defender, stop old animations
        if (DefenderIndex <> CurrentDefenderIndex):
            set IsPlaying = false
            set CurrentDefenderIndex = DefenderIndex
        
        # Only start if not already playing for THIS defender
        if (IsPlaying = false):
            set IsPlaying = true
            spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
    
    CancelAllAnimations():void =
        set IsPlaying = false
        set CurrentDefenderIndex = -1
    
    PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        race:
            block:
                Anim.PlayAndAwait(Seq)
            block:
                Sleep(AttackInterval)
            block:
                loop:
                    if (IsPlaying = false):
                        break
                    Sleep(0.05)
        set IsPlaying = false
```

### 3. Clean Up MoveEnemyNPC Attack Loop

**In MoveEnemyNPC, DELETE this entire section (around line 3000):**

```verse
# ✅ CREATE NEW CANCEL EVENT FOR THIS DEFENDER
# Cancel previous attack if present
if (PrevCancel := PreviousDefenderCancelEvent?):
    PrevCancel.Signal()
    Sleep(0.08)

if (PrevTask := PreviousAttackTask?):
    PrevTask.Await()
var CurrentDefenderCancelEvent : event() = event(){}
set PreviousDefenderCancelEvent = option{CurrentDefenderCancelEvent}
```

**DELETE this counter logic inside the attack loop:**

```verse
# Increment counter
if (Count := ActiveAttackLoops[EnemyAgent]):
    if (set ActiveAttackLoops[EnemyAgent] = Count + 1) {}
else:
    if (set ActiveAttackLoops[EnemyAgent] = 1) {}
```

**DELETE this at the end of the attack loop:**

```verse
# Decrement counter
if (Count := ActiveAttackLoops[EnemyAgent]):
    if (set ActiveAttackLoops[EnemyAgent] = Count - 1) {}
```

**REMOVE all references to `CurrentDefenderCancelEvent.Signal()`** - there are 2 places where this is called when a defender is destroyed. Delete those lines.

### 4. Simplify Defender Destroyed Logic

**Replace this block:**

```verse
if (not Def.Prop.IsValid[]):
    Print("❌ [ID:{EnemyID}] DEFENDER DESTROYED - MOVING TO NEXT")
    
    # ✅ CANCEL ANIMATIONS USING ANIMATION MANAGER
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    
    CurrentDefenderCancelEvent.Signal()
    Sleep(0.1)  # Let animations clean up
    break
```

**With:**

```verse
if (not Def.Prop.IsValid[]):
    Print("❌ [ID:{EnemyID}] DEFENDER DESTROYED - MOVING TO NEXT")
    
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    
    break
```

**And this block:**

```verse
if (NewHP <= 0.0):
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    AcquireDefenderLock(State)
    AcquireEnemyLock(State)
    
    if (DefIdx < State.Defenses.Length):
        if (CheckDef := State.Defenses[DefIdx]):
            CheckDef.Prop.Dispose()
            
            for (SIdx := 0..State.Config.DefensePlacementSpots.Length-1):
                if (OSpot := State.Config.DefensePlacementSpots[SIdx]):
                    if (OSpot.PlacedDefenderArrayIndex = DefIdx):
                        CleanupPlacementSpot(OSpot)
    
    ReleaseEnemyLock(State)
    ReleaseDefenderLock(State)

    if (set EnemyAnimationPlaying[EnemyAgent] = false) {}
    CurrentDefenderCancelEvent.Signal()
    Sleep(0.1)

    # Decrement counter
    if (Count := ActiveAttackLoops[EnemyAgent]):
        if (set ActiveAttackLoops[EnemyAgent] = Count - 1) {}
    break
```

**With:**

```verse
if (NewHP <= 0.0):
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
        
    AcquireDefenderLock(State)
    AcquireEnemyLock(State)
    
    if (DefIdx < State.Defenses.Length):
        if (CheckDef := State.Defenses[DefIdx]):
            CheckDef.Prop.Dispose()
            
            for (SIdx := 0..State.Config.DefensePlacementSpots.Length-1):
                if (OSpot := State.Config.DefensePlacementSpots[SIdx]):
                    if (OSpot.PlacedDefenderArrayIndex = DefIdx):
                        CleanupPlacementSpot(OSpot)
    
    ReleaseEnemyLock(State)
    ReleaseDefenderLock(State)
    break
```

### 5. Remove Unused Function

**DELETE the entire `PlayAttackAnimSpawn` function** - it's no longer used:

```verse
PlayAttackAnimSpawn(Anim:play_animation_controller, Seq:animation_sequence, EnemyAgent:agent, CancelEvent:event())<suspends>:void =
    race:
        block:
            Anim.PlayAndAwait(Seq)
        block:
            if (EnemyChar := EnemyAgent.GetFortCharacter[]):
                EnemyChar.EliminatedEvent().Await()
        block:
            CancelEvent.Await()
```

## Why This Works

1. **No shared state between NPCs** - Each NPC has its own animation_manager
2. **Simple state machine** - Just `IsPlaying` flag and `CurrentDefenderIndex`
3. **Natural cleanup** - When defender changes, old animations are cancelled via flag
4. **Single animation at a time** - The `IsPlaying` check prevents stacking
5. **No complex cancellation** - The loop naturally exits when defenders die

## Expected Behavior After Fix

- ✅ NPC attacks Defender 1: plays attack animation once per attack interval
- ✅ Defender 1 dies, NPC moves to Defender 2: old animation stops, new one starts
- ✅ NPC attacks Defender 2: plays attack animation once per attack interval (NO STACKING)
- ✅ Process repeats for all defenders without any animation accumulation

## Key Insight

The original code tried to solve a timing problem with complex cancellation logic. The real solution is simpler: **ensure only one animation can be "playing" at a time per NPC, using a simple boolean flag**. When switching defenders, just set the flag to false to allow a new animation to start.
