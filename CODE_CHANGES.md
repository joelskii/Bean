# Code Changes: Before vs After

## Change 1: animation_manager class

### BEFORE (Broken)
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

**Problem**: No way to cancel the spawned coroutine!

---

### AFTER (Fixed)
```verse
animation_manager := class:
    var IsPlaying : logic = false
    var CancelEvent : event() = event(){}  # ✅ NEW: Cancel mechanism
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float):void =
        # ✅ NEW: Cancel any running animation first
        if (IsPlaying = true):
            CancelEvent.Signal()
            Sleep(0.05)  # Let previous animation clean up
            set CancelEvent = event(){}  # Create fresh event for next animation
        
        set IsPlaying = true
        spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
    
    # ✅ NEW METHOD
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
                CancelEvent.Await()  # ✅ NEW: Listen for cancel signal!
        set IsPlaying = false
```

**What Changed**:
- Added `CancelEvent` property
- Added `CancelAllAnimations()` method
- Made `PlayAnimationAsync` race against `CancelEvent.Await()`
- `StartAnimation` now cancels any running animation before starting a new one

---

## Change 2: Cancel When Defender Prop Invalid

### BEFORE (Broken)
```verse
if (not Def.Prop.IsValid[]):
    Print("❌ [ID:{EnemyID}] DEFENDER DESTROYED - MOVING TO NEXT")
    # ✅ CANCEL ALL ANIMATIONS BEFORE MOVING TO NEXT DEFENDER
    CurrentDefenderCancelEvent.Signal()  # ❌ Doesn't actually stop animations!
    Sleep(0.1)  # Let animations clean up
    break
```

**Problem**: Signals an event that animations don't listen to!

---

### AFTER (Fixed)
```verse
if (not Def.Prop.IsValid[]):
    Print("❌ [ID:{EnemyID}] DEFENDER DESTROYED - MOVING TO NEXT")
    
    # ✅ CANCEL ANIMATIONS USING ANIMATION MANAGER
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()  # ✅ Actually cancels the animation!
    
    CurrentDefenderCancelEvent.Signal()
    Sleep(0.1)  # Let animations clean up
    break
```

**What Changed**:
- Added call to `AnimMgr.CancelAllAnimations()`
- This properly signals the cancel event that animations are listening to

---

## Change 3: Cancel When Defender Dies From Damage

### BEFORE (Broken)
```verse
if (NewHP <= 0.0):
    AcquireDefenderLock(State)
    AcquireEnemyLock(State)
    
    if (DefIdx < State.Defenses.Length):
        if (CheckDef := State.Defenses[DefIdx]):
            CheckDef.Prop.Dispose()
            # ... cleanup code ...
```

**Problem**: No animation cancellation when defender dies from damage!

---

### AFTER (Fixed)
```verse
if (NewHP <= 0.0):
    # ✅ CANCEL ANIMATIONS BEFORE MOVING TO NEXT DEFENDER
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    
    AcquireDefenderLock(State)
    AcquireEnemyLock(State)
    
    if (DefIdx < State.Defenses.Length):
        if (CheckDef := State.Defenses[DefIdx]):
            CheckDef.Prop.Dispose()
            # ... cleanup code ...
```

**What Changed**:
- Added call to `AnimMgr.CancelAllAnimations()` before the lock
- Ensures animation is cancelled before moving to next target

---

## Summary of Changes

| Component | Lines Changed | Purpose |
|-----------|---------------|---------|
| `animation_manager` class | ~15 lines | Add cancel mechanism |
| Defender invalid check | 3 lines | Cancel on prop destroyed |
| Defender death check | 3 lines | Cancel on HP <= 0 |
| **Total** | **~21 lines** | **Fix animation stacking** |

---

## Key Concepts

### The Race Condition Pattern

**Before**:
```verse
race:
    block: DoAnimation()
    block: Sleep(time)
    # No cancel listener
```
→ Runs until animation or timer completes, can't be stopped early

**After**:
```verse
race:
    block: DoAnimation()
    block: Sleep(time)  
    block: CancelEvent.Await()  # ✅ Cancel listener
```
→ Can be stopped early by signaling CancelEvent

### The Coroutine Lifecycle

**Before**:
```
spawn{PlayAnimation()} → Coroutine starts → Runs to completion
   ↓
Can't stop it!
```

**After**:
```
spawn{PlayAnimation()} → Coroutine starts → Races against CancelEvent
   ↓                                              ↓
Signal CancelEvent ──────────────────────────> Exits immediately!
```

---

## Testing the Fix

### Test Case 1: Single Defender Death
```
1. NPC attacks Defender 1
2. Defender 1 dies
3. NPC moves to Defender 2
4. ✅ VERIFY: Only one animation playing (no stacking)
```

### Test Case 2: Multiple Defenders
```
1. NPC attacks Defender 1, 2, 3, 4 sequentially
2. ✅ VERIFY: Each defender transition is clean (no stacking)
```

### Test Case 3: Multiple NPCs
```
1. Spawn 5 NPCs
2. Each attacks different defenders
3. ✅ VERIFY: Each NPC has independent animations (no interference)
```

### Test Case 4: Fresh Spawn
```
1. Kill an NPC mid-animation
2. Spawn a new NPC
3. ✅ VERIFY: New NPC animation works perfectly (baseline)
```

---

## Common Pitfalls to Avoid

### ❌ DON'T DO THIS:
```verse
# Trying to set IsPlaying from outside
AnimMgr.IsPlaying = false  # Won't stop the coroutine!
```

### ✅ DO THIS:
```verse
# Use the cancel method
AnimMgr.CancelAllAnimations()  # Properly signals the coroutine
```

---

### ❌ DON'T DO THIS:
```verse
# Signal an event the coroutine doesn't listen to
MyEvent.Signal()  # Coroutine doesn't know about MyEvent!
```

### ✅ DO THIS:
```verse
# Signal the event the coroutine is awaiting
CancelEvent.Signal()  # Coroutine has CancelEvent.Await() in race block
```

---

## Why Previous Fixes Failed

### Attempt 1: Longer sleep after cancel
```verse
CurrentDefenderCancelEvent.Signal()
Sleep(5.0)  # ❌ Doesn't help - coroutine isn't listening!
```

### Attempt 2: Multiple cancel signals
```verse
CurrentDefenderCancelEvent.Signal()
CurrentDefenderCancelEvent.Signal()  # ❌ Still not listening!
CurrentDefenderCancelEvent.Signal()
```

### Attempt 3: Setting flags
```verse
set ShouldCancelAnimation = true  # ❌ Coroutine doesn't check this flag!
```

**The only way**: Make the coroutine race against an event, then signal that event!

---

## Implementation Checklist

- [ ] Update `animation_manager` class with cancel event
- [ ] Add `CancelAllAnimations()` method
- [ ] Add `CancelEvent.Await()` to race condition
- [ ] Call cancel when defender prop invalid
- [ ] Call cancel when defender dies from damage
- [ ] Test with single NPC → defender 1, then defender 2
- [ ] Test with multiple NPCs simultaneously
- [ ] Verify no animation stacking occurs
- [ ] Verify each NPC's animations are independent

---

**Difficulty**: Easy  
**Impact**: Critical - Fixes major gameplay bug  
**Time to Implement**: ~10 minutes  
**Risk**: Low - Changes are isolated to animation system
