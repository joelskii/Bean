# COMPLETE SOLUTION: Fix Animation Stacking & Wrong Defender Destruction

## THE PROBLEM

Your file `tower_defense_controller.verse` got truncated to 1377 lines (should be ~4000 lines).
The critical functions are missing:
- `MoveEnemyNPC`
- `AttackSingleDefender` 
- `FindNextDefenderToAttack`

**AND you have two critical bugs:**

### Bug #1: Wrong Defenders Being Destroyed
**What happens:**
- Enemy targets Defender B (at index 1)
- Defender A (at index 0) dies and gets removed
- Array shifts: Now index 1 points to Defender C!
- Enemy destroys Defender C instead of Defender B
- Result: BOTH defenders die

**Root cause:** Using array index (`DefIdx`) as identifier when array can change

### Bug #2: King Animation Stacking
**What happens:**
- Enemy attacks defenders, animations work fine
- Defenders die, array shifts
- King's array index changes from 2 → 1 → 0
- Animation manager thinks each index is a different target
- Result: Multiple animations stack on king

**Root cause:** Animation key uses array index (unstable) instead of stable identifier

---

## THE SOLUTION

Use the **Prop object** as the identifier instead of array indices.

**Why Prop?**
- ✅ Stable: Never changes even when array is modified
- ✅ Unique: Each defender has its own Prop instance
- ✅ Trackable: Can use `Prop.GetHashCode[]` for animation keys

---

## STEP 1: Restore Your Full File

**CRITICAL:** You need to restore the full `tower_defense_controller.verse` file first.

The file should be ~4000 lines and include these functions:
- `FindNextDefenderToAttack` (around line 3780)
- `MoveEnemyNPC` (around line 3820)
- `AttackSingleDefender` (around line 3900)

**Option A:** Revert to your backup before my changes
**Option B:** Copy the full original code from your first message in this conversation

Once you have the full file, proceed to Step 2.

---

## STEP 2: Modify FindNextDefenderToAttack

**Current signature:**
```verse
FindNextDefenderToAttack(State:player_state, EnemyChar:fort_character) : ?tuple(int, defense_unit) =
```

**Change to:**
```verse
FindNextDefenderToAttack(State:player_state, EnemyChar:fort_character) : ?defense_unit =
```

**Inside the function, remove index tracking:**

**OLD:**
```verse
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
    
    if (Def := ClosestDef?, ClosestDefIdx >= 0):
        return option{(ClosestDefIdx, Def)}
    
    return false
```

**NEW:**
```verse
    var ClosestDef : ?defense_unit = false
    var ClosestDist : float = 999999.0
    
    for (DefIdx := 0..State.Defenses.Length - 1):
        if (DefIdx >= 0, DefIdx < State.Defenses.Length):
            if (Def := State.Defenses[DefIdx]):
                if (Def.Prop.IsValid[], Def.Health > 0.0):
                    DefPos := Def.Prop.GetTransform().Translation
                    Dist := Distance(EnemyPos, DefPos)
                    
                    if (Dist < ClosestDist):
                        set ClosestDist = Dist
                        set ClosestDef = option{Def}
    
    return ClosestDef
```

---

## STEP 3: Update MoveEnemyNPC Call Site

**In `MoveEnemyNPC`, find:**
```verse
MaybeDefenderInfo := FindNextDefenderToAttack(State, EnemyChar)

if (DefenderInfo := MaybeDefenderInfo?):
    DefIdx := DefenderInfo(0)
    Def := DefenderInfo(1)
    
    AttackSingleDefender(OwnerAgent, EnemyAgent, EnemyID, DefIdx, State, Nav, EnemyChar, Anim)
```

**Change to:**
```verse
MaybeDefender := FindNextDefenderToAttack(State, EnemyChar)

if (Defender := MaybeDefender?):
    AttackDefenderByProp(OwnerAgent, EnemyAgent, EnemyID, Defender, State, Nav, EnemyChar, Anim)
```

---

## STEP 4: Rename & Refactor AttackSingleDefender

**Change function signature from:**
```verse
AttackSingleDefender(OwnerAgent:agent, EnemyAgent:agent, EnemyID:int, DefIdx:int, State:player_state, Nav:navigatable, EnemyChar:fort_character, Anim:play_animation_controller)<suspends>:void =
```

**To:**
```verse
AttackDefenderByProp(OwnerAgent:agent, EnemyAgent:agent, EnemyID:int, TargetDefender:defense_unit, State:player_state, Nav:navigatable, EnemyChar:fort_character, Anim:play_animation_controller)<suspends>:void =
```

---

## STEP 5: Use Prop Instead of DefIdx Throughout

**At the start of AttackDefenderByProp:**

**OLD:**
```verse
    if (OP := player[OwnerAgent], not OP.IsActive[]): 
        return
    
    if (DefIdx < 0 or DefIdx >= State.Defenses.Length):
        return
    
    if (Def := State.Defenses[DefIdx]):
        if (not Def.Prop.IsValid[] or Def.Health <= 0.0):
            return
        
        DefPos := Def.Prop.GetTransform().Translation
```

**NEW:**
```verse
    if (OP := player[OwnerAgent], not OP.IsActive[]): 
        return
    
    # Store Prop as stable identifier
    TargetProp := TargetDefender.Prop
    
    if (not TargetProp.IsValid[] or TargetDefender.Health <= 0.0):
        return
    
    DefPos := TargetProp.GetTransform().Translation
```

---

## STEP 6: Fix Attack Position Logic

**Find references to `Def.DefenderTypeIndex` and replace with `TargetDefender.DefenderTypeIndex`**

**Example:**
```verse
if (Def.DefenderTypeIndex = -1):  # OLD
```

**Becomes:**
```verse
if (TargetDefender.DefenderTypeIndex = -1):  # NEW
```

**In placement spot matching, find:**
```verse
if (Spot.PlacedDefenderArrayIndex = DefIdx):
```

**Replace with:**
```verse
if (PlacedDef := Spot.PlacedDefender?):
    if (PlacedDef.Prop = TargetProp):
```

---

## STEP 7: Use Prop Hash for Animation Key

**Before the attack loop, add:**
```verse
# Generate stable animation key from Prop
var AnimKey : int = 0
if (PropHash := TargetProp.GetHashCode[]):
    set AnimKey = PropHash

Print("⚔️ [ID:{EnemyID}] ATTACKING (AnimKey:{AnimKey})")
```

**Then in the animation call, find:**
```verse
AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval, DefIdx)
```

**Replace with:**
```verse
AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval, AnimKey)
```

---

## STEP 8: Search for Defender by Prop Each Frame

**Inside the attack loop, find:**
```verse
if (DefIdx >= 0 and DefIdx < State.Defenses.Length):
    if (CurrentDef := State.Defenses[DefIdx]):
```

**Replace with:**
```verse
# Search for THIS defender by its Prop (handles array changes)
var FoundDefenderIndex : int = -1
var FoundDefender : ?defense_unit = false

for (SearchIdx := 0..State.Defenses.Length - 1):
    if (SearchIdx >= 0, SearchIdx < State.Defenses.Length):
        if (CheckDef := State.Defenses[SearchIdx]):
            if (CheckDef.Prop = TargetProp):
                set FoundDefenderIndex = SearchIdx
                set FoundDefender = option{CheckDef}
                break

if (FoundDef := FoundDefender?, FoundDefenderIndex >= 0):
```

**And update ALL references to `CurrentDef` to `FoundDef` and `DefIdx` to `FoundDefenderIndex`**

---

## STEP 9: Fix State Updates

**Find all lines like:**
```verse
if (set State.Defenses[DefIdx] = defense_unit{
```

**Replace with:**
```verse
if (set State.Defenses[FoundDefenderIndex] = defense_unit{
```

---

## STEP 10: Fix Defender Cleanup

**Find:**
```verse
if (DefIdx < State.Defenses.Length):
    if (CheckDef := State.Defenses[DefIdx]):
        CheckDef.Prop.Dispose()
        
        for (SIdx := 0..State.Config.DefensePlacementSpots.Length-1):
            if (OSpot := State.Config.DefensePlacementSpots[SIdx]):
                if (OSpot.PlacedDefenderArrayIndex = DefIdx):
                    CleanupPlacementSpot(OSpot)
```

**Replace with:**
```verse
# Dispose THIS specific prop
FoundDef.Prop.Dispose()

# Cleanup spot by matching Prop
for (SIdx := 0..State.Config.DefensePlacementSpots.Length-1):
    if (OSpot := State.Config.DefensePlacementSpots[SIdx]):
        if (PlacedDef := OSpot.PlacedDefender?):
            if (PlacedDef.Prop = TargetProp):
                CleanupPlacementSpot(OSpot)
```

---

## STEP 11: Handle Missing Defender Case

**At the end of the `if (FoundDef := FoundDefender?, FoundDefenderIndex >= 0):` block, add:**
```verse
else:
    # Defender not found - was removed from array
    Print("⚠️ [ID:{EnemyID}] DEFENDER REMOVED FROM ARRAY")
    return
```

---

## VERIFICATION CHECKLIST

After making all changes, verify:

- [ ] `FindNextDefenderToAttack` returns `?defense_unit` (not tuple)
- [ ] No more `DefIdx` variable in attack functions  
- [ ] `TargetProp` is used as identifier throughout
- [ ] Animation key uses `TargetProp.GetHashCode[]`
- [ ] Defender search loops by Prop each frame
- [ ] Cleanup uses Prop matching, not index
- [ ] Function renamed to `AttackDefenderByProp`

---

## EXPECTED BEHAVIOR AFTER FIX

### Test 1: Multiple Defenders
1. Place 3 defenders
2. Send enemies to attack
3. **Expected:** Enemies attack defenders one at a time
4. **Expected:** Only the targeted defender dies
5. **Expected:** Other defenders stay alive

### Test 2: King After Defenders
1. All defenders dead
2. Enemies move to king
3. **Expected:** King attack animations play ONCE per attack
4. **Expected:** No stacking, no multiple simultaneous animations
5. **Expected:** Clean, smooth animation

---

## WHY THIS WORKS

**The Problem:**
```
Array: [DefenderA, DefenderB, DefenderC]
Index:     0         1          2

Enemy targets index 1 (DefenderB)
DefenderA dies, array becomes:
Array: [DefenderB, DefenderC]
Index:     0          1

Now index 1 = DefenderC (WRONG TARGET!)
```

**The Solution:**
```
Array: [DefenderA, DefenderB, DefenderC]
Props:   PropA      PropB      PropC

Enemy targets PropB
DefenderA dies, array becomes:
Array: [DefenderB, DefenderC]
Props:   PropB      PropC

PropB is still PropB (CORRECT TARGET!)
```

**Props are stable references that don't change when arrays are modified.**

---

## NEED HELP?

If you're stuck:
1. Make sure you have the FULL file (not the truncated 1377 line version)
2. Apply changes ONE STEP at a time
3. Test after each major change
4. Check the console for any errors

The key principle: **Never use array indices when the array can change. Use stable object references instead.**
