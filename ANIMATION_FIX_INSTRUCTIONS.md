# Animation Stacking Fix - Implementation Guide

## Problem Analysis
The animation stacking occurs because enemies loop through defenders sequentially. Even with isolated `AttackSingleDefender` functions, the `for` loop context causes state to carry over between defenders.

## Solution: Dynamic Defender Querying
Replace the sequential defender loop with dynamic queries. Instead of iterating through all defenders, the enemy asks "what's the next defender?" each time.

---

## STEP 1: Replace MoveEnemyNPC's Defender Loop

**Find this code (around line 3800+ in your original):**
```verse
block:
    # Attack each defender (including king)
    for (DefIdx := 0..State.Defenses.Length - 1):
        if (EnemyID >= 0, EnemyID < State.Enemies.Length, Unit := State.Enemies[EnemyID], Unit.Health <= 0.0):
            if (HPBar := Unit.HealthBarProp?):
                HPBar.Dispose()
            return
        
        if:
            DefIdx >= 0
            DefIdx < State.Defenses.Length
            Def := State.Defenses[DefIdx]
            Def.Prop.IsValid[]
            Def.Health > 0.0
        then:
            # ✅ CALL ISOLATED ATTACK FUNCTION PER DEFENDER
            AttackSingleDefender(OwnerAgent, EnemyAgent, EnemyID, DefIdx, State, Nav, EnemyChar, Anim)
```

**Replace with:**
```verse
block:
    # ✅ NEW: DYNAMIC DEFENDER QUERY LOOP - NO SEQUENTIAL ITERATION
    loop:
        # Check if enemy is dead
        if (EnemyID >= 0, EnemyID < State.Enemies.Length, Unit := State.Enemies[EnemyID], Unit.Health <= 0.0):
            if (HPBar := Unit.HealthBarProp?):
                HPBar.Dispose()
            return
        
        # ✅ FIND NEXT VALID DEFENDER DYNAMICALLY
        MaybeDefenderInfo := FindNextDefenderToAttack(State, EnemyChar)
        
        if (DefenderInfo := MaybeDefenderInfo?):
            DefIdx := DefenderInfo(0)
            Def := DefenderInfo(1)
            
            Print("🎯 [ID:{EnemyID}] TARGETING DEFENDER AT INDEX {DefIdx}")
            
            # Attack this specific defender
            AttackSingleDefender(OwnerAgent, EnemyAgent, EnemyID, DefIdx, State, Nav, EnemyChar, Anim)
            
            # When this returns, defender is dead - loop queries for next
            Print("✅ [ID:{EnemyID}] DEFENDER {DefIdx} ELIMINATED, FINDING NEXT TARGET...")
        else:
            # No more defenders alive
            Print("🏁 [ID:{EnemyID}] NO DEFENDERS REMAINING - MISSION COMPLETE")
            return
```

---

## STEP 2: Add Helper Function

**Add this NEW function right BEFORE `MoveEnemyNPC` (around line 3780+):**

```verse
# ✅ NEW: Dynamically find the next valid defender to attack (closest first)
FindNextDefenderToAttack(State:player_state, EnemyChar:fort_character) : ?tuple(int, defense_unit) =
    if (not EnemyChar.IsActive[]):
        return false
    
    EnemyPos := EnemyChar.GetTransform().Translation
    
    # Find closest alive defender
    var ClosestDefIdx : int = -1
    var ClosestDist : float = 999999.0
    var ClosestDef : ?defense_unit = false
    
    for (DefIdx := 0..State.Defenses.Length - 1):
        if (DefIdx >= 0, DefIdx < State.Defenses.Length):
            if (Def := State.Defenses[DefIdx]):
                if (Def.Prop.IsValid[], Def.Health > 0.0):
                    DefPos := Def.Prop.GetTransform().Translation
                    Dist := Distance(EnemyPos, DefPos)
                    
                    if (Dist < ClosestDist):
                        set ClosestDefIdx = DefIdx
                        set ClosestDist = Dist
                        set ClosestDef = option{Def}
    
    # Return the closest defender if found
    if (Def := ClosestDef?, ClosestDefIdx >= 0):
        return option{(ClosestDefIdx, Def)}
    
    return false
```

---

## STEP 3: Verify Animation Manager Fix (Already Applied)

Your animation_manager class should look like this:

```verse
animation_manager := class:
    var CurrentDefenderIndex : int = -1
    var CurrentRoutine : ?cancelable = false
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, DefenderIndex:int):void =
        # ✅ ALWAYS cancel previous animation first
        CancelAllAnimations()
        
        # ✅ UPDATE defender index
        set CurrentDefenderIndex = DefenderIndex
        
        # ✅ CAPTURE the cancelable from spawn
        NewRoutine := spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
        set CurrentRoutine = option{NewRoutine}
    
    CancelAllAnimations():void =
        if (Routine := CurrentRoutine?):
            Routine.Cancel()
            set CurrentRoutine = false
        set CurrentDefenderIndex = -1
    
    PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        Anim.PlayAndAwait(Seq)
        Sleep(AttackInterval)
```

---

## Why This Works

### **BEFORE (Broken):**
```
for defender in all_defenders:  # Sequential loop - context carries
    attack(defender)
```
- Loop context persists
- Animation manager state bleeds between iterations
- Multiple animations stack up

### **AFTER (Fixed):**
```
loop:
    next_defender = find_closest()  # Fresh query
    if no defender: break
    attack(next_defender)  # Completely independent
```
- No loop context between attacks
- Each attack session is fully isolated
- Animation manager properly resets
- Enemy naturally targets closest defender

---

## Testing

After applying these changes:
1. Start a round with multiple defenders
2. Watch an enemy attack the first defender until it dies
3. Enemy should move to next defender with NO animation stacking
4. Animations should play once per attack, clean and smooth

The prints will show:
```
🎯 [ID:0] TARGETING DEFENDER AT INDEX 2
⚔️ [ID:0] STARTING ATTACK LOOP ON DEFENDER 2
✅ [ID:0] DEFENDER 2 ELIMINATED, FINDING NEXT TARGET...
🎯 [ID:0] TARGETING DEFENDER AT INDEX 1
⚔️ [ID:0] STARTING ATTACK LOOP ON DEFENDER 1
...
```

---

## Summary

**Two Key Changes:**
1. ✅ **animation_manager** - Properly captures and cancels spawned animations
2. ✅ **MoveEnemyNPC** - Dynamic defender queries instead of sequential loop

These eliminate ALL sources of context/state carryover between defenders.
