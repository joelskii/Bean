# Fix for Attacker Animation Stacking (Defender 2+ Bug)

## Problem Analysis

**Symptoms:**
- Defender 1: Works perfectly ✅
- Defender 2+: Animations stack/overlap ❌
- Fresh spawns after death: Work perfectly ✅

**Root Cause:**
The `animation_manager` class doesn't properly listen to cancel events. When an NPC moves from Defender 1 to Defender 2, the old animation coroutine keeps running because it races against `Sleep(AttackInterval)` instead of the cancel event.

---

## The Fix: Make Animation Manager Cancel-Aware

### Step 1: Update `animation_manager` class

**Find this code (around line 1000):**
```verse
animation_manager := class:
    var IsPlaying : logic = false
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float):void =
        # Only start if not already playing
        if (IsPlaying = false):
            set IsPlaying = true
            spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
    
    PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        race:
            block:
                Anim.PlayAndAwait(Seq)
            block:
                Sleep(AttackInterval)
        set IsPlaying = false
```

**Replace with:**
```verse
animation_manager := class:
    var IsPlaying : logic = false
    var CancelEvent : event() = event(){}
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float):void =
        # ✅ CANCEL ANY RUNNING ANIMATION FIRST
        if (IsPlaying = true):
            CancelEvent.Signal()
            Sleep(0.05)  # Let previous animation clean up
            set CancelEvent = event(){}  # Create fresh event
        
        set IsPlaying = true
        spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
    
    CancelAllAnimations():void =
        if (IsPlaying = true):
            CancelEvent.Signal()
            set IsPlaying = false
    
    PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        race:
            block:
                Anim.PlayAndAwait(Seq)
            block:
                Sleep(AttackInterval)
            block:
                CancelEvent.Await()  # ✅ NOW LISTENS TO CANCEL!
        set IsPlaying = false
```

---

### Step 2: Call CancelAllAnimations when moving to next defender

**Find this code in the attack loop (around line 2800):**
```verse
if (not Def.Prop.IsValid[]):
    Print("❌ [ID:{EnemyID}] DEFENDER DESTROYED - MOVING TO NEXT")
    # ✅ CANCEL ALL ANIMATIONS BEFORE MOVING TO NEXT DEFENDER
    CurrentDefenderCancelEvent.Signal()
    Sleep(0.1)  # Let animations clean up
    break
```

**Replace with:**
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

---

### Step 3: Also cancel when defender dies from damage

**Find this code where defender health reaches 0 (around line 2950):**
```verse
if (NewHP <= 0.0):
    AcquireDefenderLock(State)
    AcquireEnemyLock(State)
    
    if (DefIdx < State.Defenses.Length):
        if (CheckDef := State.Defenses[DefIdx]):
            CheckDef.Prop.Dispose()
```

**Add before the lock acquisition:**
```verse
if (NewHP <= 0.0):
    # ✅ CANCEL ANIMATIONS BEFORE MOVING TO NEXT DEFENDER
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    
    AcquireDefenderLock(State)
    AcquireEnemyLock(State)
```

---

## Why This Works

1. **Per-NPC Cancel Event**: Each animation manager has its own cancel event
2. **Race Condition Fix**: `PlayAnimationAsync` now races against the cancel event, not just the timer
3. **Clean Handoff**: When moving to next defender, we explicitly cancel the old animation before starting a new one
4. **No Stacking**: Since `StartAnimation` cancels any running animation first, only ONE animation can play at a time per NPC

---

## Testing

After applying these fixes:
1. ✅ Defender 1 should work (was already working)
2. ✅ Defender 2+ should NOT stack animations
3. ✅ Fresh spawns should still work
4. ✅ Multiple NPCs should each have independent animations
