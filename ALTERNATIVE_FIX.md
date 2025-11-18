# Alternative Fix: Simpler Architecture

## If the Previous Fixes Still Don't Work...

There might be a deeper architectural issue. Let me provide a **completely different approach** that's more robust.

---

## The Nuclear Option: One Animation Per NPC, Period

Instead of trying to manage cancel events, let's use a **flag-based system** that's simpler and more reliable.

### Step 1: Add a Target Tracking System to animation_manager

**REPLACE your entire animation_manager class:**

```verse
animation_manager := class:
    var IsPlaying : logic = false
    var CurrentDefenderIndex : int = -1  # ✅ NEW: Track which defender we're animating for
    var CancelEvent : event() = event(){}
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, DefenderIndex:int):void =
        # ✅ If attacking a different defender, cancel old animation
        if (DefenderIndex <> CurrentDefenderIndex):
            if (IsPlaying = true):
                CancelEvent.Signal()
                Sleep(0.05)
                set CancelEvent = event(){}
            set CurrentDefenderIndex = DefenderIndex
        
        # Only start if not already playing for THIS defender
        if (IsPlaying = false):
            set IsPlaying = true
            spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
    
    CancelAllAnimations():void =
        if (IsPlaying = true):
            CancelEvent.Signal()
            set IsPlaying = false
            set CurrentDefenderIndex = -1
    
    PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        race:
            block:
                Anim.PlayAndAwait(Seq)
            block:
                Sleep(AttackInterval)
            block:
                CancelEvent.Await()
        set IsPlaying = false
```

### Step 2: Pass Defender Index When Calling

```verse
if (TheAnim := AttackAnimToUse?):
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        # ✅ PASS THE DEFENDER INDEX!
        AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval, DefIdx)
```

**Why This Works:**
- When you move from Defender 0 to Defender 1, `DefenderIndex` changes
- The animation manager detects this change
- It automatically cancels the old animation before starting the new one
- No need to manually call cancel anywhere!

---

## Alternative Approach 2: Kill the Animation Manager Entirely

Maybe the animation manager is causing more problems than it solves. Let's try a **direct approach**:

### Remove Animation Manager Usage

**Find this code:**
```verse
if (TheAnim := AttackAnimToUse?):
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval)
```

**REPLACE with direct spawn:**
```verse
if (TheAnim := AttackAnimToUse?):
    # ✅ DIRECTLY SPAWN WITH CANCEL EVENT
    spawn{
        race:
            block:
                Anim.PlayAndAwait(TheAnim)
            block:
                Sleep(Atk.AttackInterval)
            block:
                CurrentDefenderCancelEvent.Await()  # ✅ Listen to the cancel event you're already using!
    }
```

**Why This Might Work Better:**
- No complex state management
- Directly uses the cancel event you're already signaling
- Each spawned animation automatically listens to the right event
- Simpler = fewer bugs

---

## Alternative Approach 3: Per-Defender Animation Tracking

Track which animation coroutine belongs to which defender:

### Add to tower_defense_controller class:
```verse
var ActiveAttackAnimations : [agent][int]task(void) = map{}  # NPC -> DefenderIndex -> AnimTask
```

### When Starting Animation:
```verse
if (TheAnim := AttackAnimToUse?):
    # ✅ Cancel any existing animation for this NPC
    if (ExistingAnims := ActiveAttackAnimations[EnemyAgent]):
        # Cancel all animations for this NPC
        var NewMap : [int]task(void) = map{}
        set ActiveAttackAnimations[EnemyAgent] = NewMap
    
    # Start new animation and track it
    NewTask := spawn{
        race:
            block: Anim.PlayAndAwait(TheAnim)
            block: Sleep(Atk.AttackInterval)
    }
    
    if (AnimMap := ActiveAttackAnimations[EnemyAgent]):
        if (set AnimMap[DefIdx] = NewTask) {}
    else:
        var NewAnimMap : [int]task(void) = map{}
        if (set NewAnimMap[DefIdx] = NewTask) {}
        if (set ActiveAttackAnimations[EnemyAgent] = NewAnimMap) {}
```

---

## Diagnostic: Is It Really Animations Stacking?

Maybe it's not the animations at all. Let's test:

### Test 1: Disable Animations Entirely

```verse
if (TheAnim := AttackAnimToUse?):
    Print("🎬 Would play animation, but disabled for testing")
    # if (AnimMgr := AnimationManagers[EnemyAgent]):
    #     AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval)
```

**If the "stacking" still happens**, it's not the animations - it's multiple attack loops running!

### Test 2: Count Active Attack Loops

Add at the top of your class:
```verse
var ActiveAttackLoops : [agent]int = map{}  # Count loops per NPC
```

At the start of the attack loop (for each defender):
```verse
# Increment counter
if (Count := ActiveAttackLoops[EnemyAgent]):
    if (set ActiveAttackLoops[EnemyAgent] = Count + 1) {}
else:
    if (set ActiveAttackLoops[EnemyAgent] = 1) {}

Print("🔥 [ID:{EnemyID}] DEF{DefIdx}: ACTIVE LOOPS = {ActiveAttackLoops[EnemyAgent]}")
```

At the end (when breaking):
```verse
# Decrement counter
if (Count := ActiveAttackLoops[EnemyAgent]):
    if (set ActiveAttackLoops[EnemyAgent] = Count - 1) {}

Print("🔥 [ID:{EnemyID}] DEF{DefIdx}: EXITING, ACTIVE LOOPS = {ActiveAttackLoops[EnemyAgent]}")
```

**If you see more than 1 active loop**, that's your problem! Multiple attack loops are running simultaneously.

---

## If Multiple Attack Loops Are Running...

The issue is in your defender loop structure. Look for:

```verse
for (DefIdx := 0..State.Defenses.Length - 1):
    # Setup code
    
    loop:  # ← THIS LOOP
        # Attack code
```

Make sure this outer `for` loop isn't somehow being called multiple times for the same NPC. Check:

1. Is `MoveEnemyNPC` being called more than once per NPC?
2. Is the behavior's `MainLoop` spawning multiple times?
3. Is there a race condition in the NPC spawning code?

---

## Summary: Try These in Order

1. **First**: Apply the `AnimMgr.CancelAllAnimations()` calls in the two locations from REAL_ISSUE_FOUND.md
2. **If that fails**: Use Alternative Approach 1 (Track defender index)
3. **If that fails**: Use Alternative Approach 2 (Direct spawn without manager)
4. **If that fails**: Run Diagnostic Tests to see if it's not animations at all
5. **If diagnostics show multiple attack loops**: The bug is in your loop spawning, not animations

---

## Quick Sanity Check

Answer these questions by adding prints:

```verse
# Question 1: How many times is MoveEnemyNPC called per NPC?
MoveEnemyNPC<public>(OwnerAgent : agent, EnemyAgent : agent, EnemyID : int)<suspends> : void =
    Print("🚨 MoveEnemyNPC CALLED for EnemyID {EnemyID}")
    # ... rest of code

# Question 2: How many animation managers exist per NPC?
if (set AnimationManagers[SpawnedAgent] = animation_manager{}) {
    Print("✅ Created animation manager for agent")
}

# Question 3: When does StartAnimation get called?
StartAnimation(...):void =
    Print("🎬 StartAnimation called, IsPlaying={IsPlaying}")
    # ... rest of code
```

Share the output and we can narrow down where the duplication is happening!
