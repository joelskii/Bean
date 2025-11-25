# THE REAL ISSUE: Two Disconnected Cancel Systems!

## Why My Previous Fix Didn't Work

I just realized the ACTUAL problem after analyzing your code more carefully:

**You have TWO completely separate cancel event systems that don't talk to each other!**

### System 1: CurrentDefenderCancelEvent (Per-Defender)
```verse
# Created for EACH defender
var CurrentDefenderCancelEvent : event() = event(){}

# Signaled when moving to next defender
CurrentDefenderCancelEvent.Signal()
```

### System 2: animation_manager.CancelEvent (Per-NPC)
```verse
# Inside animation_manager class
var CancelEvent : event() = event(){}

# PlayAnimationAsync races against this
block: CancelEvent.Await()
```

## The Problem

When you call:
```verse
CurrentDefenderCancelEvent.Signal()  # Signal system 1
```

But `PlayAnimationAsync` is listening to:
```verse
CancelEvent.Await()  # Listening to system 2
```

**They're different events! Signaling one doesn't trigger the other!**

---

## The ACTUAL Fix: Bridge the Two Systems

You need to connect `CurrentDefenderCancelEvent` to `animation_manager.CancelEvent`.

### Solution A: Spawn a Bridge Coroutine (EASIEST)

Find where you start the attack loop for each defender (around line 2735):

```verse
var CurrentDefenderCancelEvent : event() = event(){}
set PreviousDefenderCancelEvent = option{CurrentDefenderCancelEvent}

# ✅ ADD THIS BRIDGE COROUTINE:
if (AnimMgr := AnimationManagers[EnemyAgent]):
    spawn{
        CurrentDefenderCancelEvent.Await()  # Wait for defender cancel
        AnimMgr.CancelAllAnimations()        # Trigger animation manager cancel
    }

# NOW ATTACK THIS DEFENDER UNTIL IT DIES
loop:
    # ... attack code ...
```

This creates a "listener" that waits for `CurrentDefenderCancelEvent` and then calls the animation manager's cancel method.

---

### Solution B: Make Animation Manager Accept Cancel Event (CLEANER)

#### Step 1: Update animation_manager to accept an external cancel event

**REPLACE the StartAnimation method:**

```verse
StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, ExternalCancel:?event() = false):void =
    # Cancel any running animation first
    if (IsPlaying = true):
        CancelEvent.Signal()
        Sleep(0.05)
        set CancelEvent = event(){}
    
    set IsPlaying = true
    spawn{PlayAnimationAsync(Anim, Seq, AttackInterval, ExternalCancel)}  # Pass it through

PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, ExternalCancel:?event())<suspends>:void =
    race:
        block:
            Anim.PlayAndAwait(Seq)
        block:
            Sleep(AttackInterval)
        block:
            CancelEvent.Await()  # Internal cancel
        block:
            # ✅ NEW: Listen to external cancel too!
            if (ExtCancel := ExternalCancel?):
                ExtCancel.Await()
    set IsPlaying = false
```

#### Step 2: Pass CurrentDefenderCancelEvent when calling StartAnimation

```verse
if (TheAnim := AttackAnimToUse?):
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        # ✅ PASS THE CANCEL EVENT!
        AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval, option{CurrentDefenderCancelEvent})
```

---

## Why This Happens

Look at your loop structure:

```verse
for (DefIdx := 0..State.Defenses.Length - 1):  # Outer loop: each defender
    
    # ✅ CREATE NEW CANCEL EVENT HERE
    var CurrentDefenderCancelEvent : event() = event(){}
    
    loop:  # Inner loop: attack current defender
        AnimMgr.StartAnimation(...)  # Spawns coroutine
        Sleep(AttackInterval)
    
    # ✅ SIGNAL CANCEL EVENT HERE
    CurrentDefenderCancelEvent.Signal()
    break  # Move to next defender in outer loop
```

**What's happening:**
1. Defender 1: Create event A, spawn animation listening to animation_manager's internal event
2. Defender 1 dies: Signal event A (but animation isn't listening to it!)
3. Defender 2: Create event B, spawn NEW animation
4. Now TWO animations are running!

---

## Debugging to Confirm This is the Issue

Add this to your attack loop:

```verse
# When creating the cancel event
var CurrentDefenderCancelEvent : event() = event(){}
Print("🔵 [ID:{EnemyID}] DEF{DefIdx}: Created cancel event")

# Inside the attack loop where you call StartAnimation
if (AnimMgr := AnimationManagers[EnemyAgent]):
    Print("🟢 [ID:{EnemyID}] DEF{DefIdx}: Calling StartAnimation, IsPlaying={AnimMgr.IsPlaying}")
    AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval)

# When signaling the cancel
CurrentDefenderCancelEvent.Signal()
Print("🔴 [ID:{EnemyID}] DEF{DefIdx}: Signaled cancel event")
```

**If you see:**
```
🔵 [ID:0] DEF0: Created cancel event
🟢 [ID:0] DEF0: Calling StartAnimation, IsPlaying=false
🟢 [ID:0] DEF0: Calling StartAnimation, IsPlaying=false  ← Called multiple times
🔴 [ID:0] DEF0: Signaled cancel event
🔵 [ID:0] DEF1: Created cancel event
🟢 [ID:0] DEF1: Calling StartAnimation, IsPlaying=false  ← New animation starts
```

This confirms animations aren't being cancelled because they're listening to the wrong event!

---

## The Quick Fix (Choose One)

### Option 1: Bridge Coroutine (Fastest - 3 lines of code)

```verse
if (AnimMgr := AnimationManagers[EnemyAgent]):
    spawn{CurrentDefenderCancelEvent.Await(); AnimMgr.CancelAllAnimations()}
```

Add this right after creating `CurrentDefenderCancelEvent`.

### Option 2: Manual Cancel Call (Also Fast - 2 lines)

```verse
if (not Def.Prop.IsValid[]):
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()  # ✅ Actually call the cancel!
    CurrentDefenderCancelEvent.Signal()
    break
```

Add the AnimMgr.CancelAllAnimations() call BEFORE signaling the event.

---

## Why My Previous Fix Seemed Correct But Failed

I told you to:
1. ✅ Add `CancelEvent` to animation_manager - You probably did this
2. ✅ Add `CancelEvent.Await()` to the race - You probably did this  
3. ✅ Call `AnimMgr.CancelAllAnimations()` - **BUT WHERE??**

The issue is Step 3. You need to call it in the RIGHT places where you signal `CurrentDefenderCancelEvent`!

---

## The Two Critical Locations

### Location 1: When Defender Prop Becomes Invalid (Line ~2800)
```verse
if (not Def.Prop.IsValid[]):
    Print("❌ [ID:{EnemyID}] DEFENDER DESTROYED - MOVING TO NEXT")
    
    # ✅ ADD THIS!
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    
    CurrentDefenderCancelEvent.Signal()
    Sleep(0.1)
    break
```

### Location 2: When Defender Dies from Damage (Line ~2950)
```verse
if (NewHP <= 0.0):
    # ✅ ADD THIS!
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    
    AcquireDefenderLock(State)
    # ... rest of cleanup ...
    
    if (set EnemyAnimationPlaying[EnemyAgent] = false) {}
    CurrentDefenderCancelEvent.Signal()  # ← This line already exists
    Sleep(0.1)
    break
```

---

## Test After Applying

1. Add debug prints around StartAnimation calls
2. Verify you see `CancelAllAnimations()` being called
3. Verify `IsPlaying` goes false when moving between defenders
4. Watch for animation stacking

If it STILL doesn't work after this, the problem is elsewhere (possibly multiple attack loops running simultaneously, not just animations).
