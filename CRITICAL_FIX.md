# CRITICAL FIX: Stable Defender Identification

## Root Cause
Using array indices to track defenders causes them to become stale when defenders die:
- Enemy gets `DefIdx = 1`
- Defender at index 0 dies and gets removed
- Now `DefIdx = 1` points to a DIFFERENT defender
- Wrong defender gets destroyed

## Solution: Use Prop as Stable ID

### CHANGE 1: Modify FindNextDefenderToAttack

**Replace:**
```verse
FindNextDefenderToAttack(State:player_state, EnemyChar:fort_character) : ?tuple(int, defense_unit) =
    if (not EnemyChar.IsActive[]):
        return false
    
    EnemyPos := EnemyChar.GetTransform().Translation
    
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

**With:**
```verse
# ✅ Returns the defender unit itself, not an index
FindNextDefenderToAttack(State:player_state, EnemyChar:fort_character) : ?defense_unit =
    if (not EnemyChar.IsActive[]):
        return false
    
    EnemyPos := EnemyChar.GetTransform().Translation
    
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

### CHANGE 2: Modify MoveEnemyNPC to use Prop

**Replace the loop with:**
```verse
block:
    # ✅ DYNAMIC DEFENDER QUERY - Uses Prop as stable ID
    loop:
        # Check if enemy is dead
        if (EnemyID >= 0, EnemyID < State.Enemies.Length, Unit := State.Enemies[EnemyID], Unit.Health <= 0.0):
            if (HPBar := Unit.HealthBarProp?):
                HPBar.Dispose()
            return
        
        # ✅ FIND NEXT VALID DEFENDER (returns the unit itself)
        MaybeDefender := FindNextDefenderToAttack(State, EnemyChar)
        
        if (Defender := MaybeDefender?):
            Print("🎯 [ID:{EnemyID}] TARGETING DEFENDER")
            
            # Attack using the Prop as identifier
            AttackDefenderByProp(OwnerAgent, EnemyAgent, EnemyID, Defender, State, Nav, EnemyChar, Anim)
            
            Print("✅ [ID:{EnemyID}] DEFENDER ELIMINATED, FINDING NEXT TARGET...")
        else:
            Print("🏁 [ID:{EnemyID}] NO DEFENDERS REMAINING")
            return
```

### CHANGE 3: Create New AttackDefenderByProp Function

**Add this NEW function (replaces AttackSingleDefender):**

```verse
# ✅ NEW: Attack defender identified by Prop (stable), not by index (unstable)
AttackDefenderByProp(OwnerAgent:agent, EnemyAgent:agent, EnemyID:int, TargetDefender:defense_unit, State:player_state, Nav:navigatable, EnemyChar:fort_character, Anim:play_animation_controller)<suspends>:void =
    if (OP := player[OwnerAgent], not OP.IsActive[]): 
        return
    
    # Use Prop as stable identifier
    TargetProp := TargetDefender.Prop
    
    if (not TargetProp.IsValid[] or TargetDefender.Health <= 0.0):
        return
    
    DefPos := TargetProp.GetTransform().Translation
    var TargetPos : vector3 = DefPos

    # Calculate attack position
    if (TargetDefender.DefenderTypeIndex = -1):
        # King
        if (State.SelectedKingRoute >= 0, State.SelectedKingRoute < State.Config.KingRoutes.Length):
            if (Route := State.Config.KingRoutes[State.SelectedKingRoute]):
                if (Route.InitialKing.AttackTransforms.Length > 0):
                    RandomAttackIdx := GetRandomInt(0, Route.InitialKing.AttackTransforms.Length - 1)
                    if (AttackTransform := Route.InitialKing.AttackTransforms[RandomAttackIdx]):
                        FixedKingAttack := FixTransform(AttackTransform)
                        set TargetPos = vector3{
                            X := FixedKingAttack.Translation.X,
                            Y := FixedKingAttack.Translation.Y,
                            Z := DefPos.Z
                        }
    else:
        # Normal defender - find spot by matching Prop
        var FoundAttackPos : logic = false
        for (SpotIdx := 0..State.Config.DefensePlacementSpots.Length - 1):
            if (not FoundAttackPos?):
                if (Spot := State.Config.DefensePlacementSpots[SpotIdx]):
                    # ✅ Match by Prop, not by index
                    if (PlacedDef := Spot.PlacedDefender?):
                        if (PlacedDef.Prop = TargetProp):
                            if (Spot.AttackTransforms.Length > 0):
                                RandomAttackIdx := GetRandomInt(0, Spot.AttackTransforms.Length - 1)
                                if (AttackTransformFromSpot := Spot.AttackTransforms[RandomAttackIdx]):
                                    FixedAttack := FixTransform(AttackTransformFromSpot)
                                    set TargetPos = FixedAttack.Translation
                                    set FoundAttackPos = true
        
        if (FoundAttackPos = false):
            Radius := 300.0
            RandomAngle := GetRandomFloat(0.0, 6.28318530718)
            OffsetX1 := Cos(RandomAngle) * Radius
            OffsetY1 := Sin(RandomAngle) * Radius
            set TargetPos = vector3{
                X := DefPos.X + OffsetX1,
                Y := DefPos.Y + OffsetY1,
                Z := DefPos.Z
            }

    # Apply random offset
    OffsetX := GetRandomFloat(-35.0, 35.0)
    OffsetY := GetRandomFloat(-35.0, 35.0)
    set TargetPos = vector3{X := TargetPos.X + OffsetX, Y := TargetPos.Y + OffsetY, Z := TargetPos.Z}

    Print("🚶 [ID:{EnemyID}] NAVIGATING TO DEFENDER")
    
    # Navigation (same as before)
    var NavCompleted : logic = false
    loop:
        if (NavCompleted?):
            break
            
        if (EnemyID >= 0, EnemyID < State.Enemies.Length):
            if (CheckUnit := State.Enemies[EnemyID], CheckAtk := State.Config.Attackers[CheckUnit.AttackerIndex]):
                BaseSpeedMultiplier := Clamp(CheckAtk.MovementSpeed / 100.0, 0.5, 2.0)
                CurrentTime := GetSimulationElapsedTime()
                
                if (CheckUnit.FrozenUntil > CurrentTime):
                    if (CheckUnit.CurrentSpeedMultiplier <= 0.01):
                        Print("🧊 [ID:{EnemyID}] FROZEN - WAITING")
                        TimeRemaining := CheckUnit.FrozenUntil - CurrentTime
                        Sleep(TimeRemaining)
                        
                        if (set State.Enemies[EnemyID] = enemy_unit{
                            ID := CheckUnit.ID,
                            Agent := CheckUnit.Agent,
                            Health := CheckUnit.Health,
                            AttackerIndex := CheckUnit.AttackerIndex,
                            IsAttacking := CheckUnit.IsAttacking,
                            HealthBarProp := CheckUnit.HealthBarProp,
                            IsDead := CheckUnit.IsDead,
                            ScaledDamage := CheckUnit.ScaledDamage,
                            MaybeVariant := CheckUnit.MaybeVariant,
                            FrozenUntil := 0.0,
                            CurrentSpeedMultiplier := 1.0
                        }) {}
                        Nav.SetMovementSpeedMultiplier(BaseSpeedMultiplier)
                    else:
                        SpeedMultiplier := Clamp(BaseSpeedMultiplier * CheckUnit.CurrentSpeedMultiplier, 0.5, 2.0)
                        Nav.SetMovementSpeedMultiplier(SpeedMultiplier)
                else:
                    if (CheckUnit.CurrentSpeedMultiplier < 1.0):
                        if (set State.Enemies[EnemyID] = enemy_unit{
                            ID := CheckUnit.ID,
                            Agent := CheckUnit.Agent,
                            Health := CheckUnit.Health,
                            AttackerIndex := CheckUnit.AttackerIndex,
                            IsAttacking := CheckUnit.IsAttacking,
                            HealthBarProp := CheckUnit.HealthBarProp,
                            IsDead := CheckUnit.IsDead,
                            ScaledDamage := CheckUnit.ScaledDamage,
                            MaybeVariant := CheckUnit.MaybeVariant,
                            FrozenUntil := 0.0,
                            CurrentSpeedMultiplier := 1.0
                        }) {}
                    Nav.SetMovementSpeedMultiplier(BaseSpeedMultiplier)
        
        CurrentPos := EnemyChar.GetTransform().Translation
        DistToTarget := Distance(CurrentPos, TargetPos)
        if (DistToTarget <= 50.0):
            set NavCompleted = true
            break
        
        NavTarget := MakeNavigationTarget(TargetPos)
        race:
            block:
                Nav.NavigateTo(NavTarget, ?ReachRadius := 50.0)
                set NavCompleted = true
            block:
                loop:
                    Sleep(0.1)
                    if (EnemyID >= 0, EnemyID < State.Enemies.Length):
                        if (MonitorUnit := State.Enemies[EnemyID]):
                            CurrentTime := GetSimulationElapsedTime()
                            if (MonitorUnit.FrozenUntil > CurrentTime, MonitorUnit.CurrentSpeedMultiplier <= 0.01):
                                Nav.StopNavigation()
                                break

    # Rotate to face defender
    if (TargetProp.IsValid[]):
        DefenderPos := TargetProp.GetTransform().Translation
        NPCPos1 := EnemyChar.GetTransform().Translation
        DirectionToDefender := vector3{
            X := DefenderPos.X - NPCPos1.X,
            Y := DefenderPos.Y - NPCPos1.Y,
            Z := 0.0
        }
        if (Dir := DirectionToDefender.MakeUnitVector[]):
            Yaw := ArcTan(Dir.Y, Dir.X)
            FacingRot := MakeRotation(vector3{X:=0.0, Y:=0.0, Z:=1.0}, Yaw)
            if (EnemyChar.TeleportTo[NPCPos1, FacingRot]) {}

    # ✅ Use Prop hashcode as animation key (stable across array changes)
    var AnimKey : int = 0
    if (PropHash := TargetProp.GetHashCode[]):
        set AnimKey = PropHash

    Print("⚔️ [ID:{EnemyID}] ATTACKING DEFENDER (AnimKey:{AnimKey})")

    # ✅ ATTACK LOOP - Keep attacking until THIS specific Prop is destroyed
    loop:
        if (EnemyID < 0 or EnemyID >= State.Enemies.Length):
            return
        
        if (Unit := State.Enemies[EnemyID]):
            if (Unit.IsDead? or Unit.Health <= 0.0):
                if (HPBar := Unit.HealthBarProp?):
                    HPBar.Dispose()
                return
        else:
            return
        
        # ✅ Check if THIS SPECIFIC defender (by Prop) is still valid
        if (not TargetProp.IsValid[]):
            Print("❌ [ID:{EnemyID}] DEFENDER DESTROYED - EXITING")
            if (AnimMgr := AnimationManagers[EnemyAgent]):
                AnimMgr.CancelAllAnimations()
            return
        
        # ✅ Find THIS defender in array (search by Prop each time)
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
            if (Unit := State.Enemies[EnemyID]):
                if (Atk := State.Config.Attackers[Unit.AttackerIndex]):
                    var AttackAnimToUse : ?animation_sequence = Atk.AttackAnimation
                    if(Variant := Unit.MaybeVariant?):
                        for(VNS : Atk.VariantNPCSpawners):
                            if(VNS.VariantName = Variant.Name):
                                if(VarAnim := VNS.AttackAnimation?):
                                    set AttackAnimToUse = option{VarAnim}
                    
                    Atk.AttackSound.Play()
                    
                    if(DNSettings := Atk.DamageNumberSettings?):
                        FreshDefPos := FoundDef.Prop.GetTransform().Translation
                        spawn{ShowDamageNumber(FreshDefPos, Unit.ScaledDamage, 1.0, DNSettings, State)}

                    if (TheAnim := AttackAnimToUse?):
                        if (AnimMgr := AnimationManagers[EnemyAgent]):
                            # ✅ Use stable hash as key, not array index
                            AnimMgr.StartAnimation(Anim, TheAnim, Atk.AttackInterval, AnimKey)
                    
                    Sleep(Atk.AttackInterval)

                    # Apply damage
                    if (FoundDef.DefenderTypeIndex = -1):
                        # King
                        NewHP := Max(State.KingHealth - Unit.ScaledDamage, 0.0)
                        set State.KingHealth = NewHP
                        UpdateKingHealthUI(State)
                        
                        if (set State.Defenses[FoundDefenderIndex] = defense_unit{
                            Prop := FoundDef.Prop,
                            Health := NewHP,
                            DefenderTypeIndex := -1,
                            CurrentVariantLevel := FoundDef.CurrentVariantLevel,
                            MaybeVariant := FoundDef.MaybeVariant,
                            SecondaryProp := FoundDef.SecondaryProp
                        }) {}
                        
                        if (NewHP <= 0.0):
                            spawn{HandleKingDeath(OwnerAgent)}
                            return
                    else:
                        # Normal defender
                        NewHP := FoundDef.Health - Unit.ScaledDamage
                        
                        if (set State.Defenses[FoundDefenderIndex] = defense_unit{
                            Prop := FoundDef.Prop, 
                            Health := NewHP, 
                            DefenderTypeIndex := FoundDef.DefenderTypeIndex,
                            CurrentVariantLevel := FoundDef.CurrentVariantLevel,
                            MaybeVariant := FoundDef.MaybeVariant,
                            SecondaryProp := FoundDef.SecondaryProp
                        }):
                            if (NewHP <= 0.0):
                                if (AnimMgr := AnimationManagers[EnemyAgent]):
                                    AnimMgr.CancelAllAnimations()
                                    
                                # ✅ Dispose THIS specific prop
                                FoundDef.Prop.Dispose()
                                
                                # ✅ Cleanup spot (search by Prop)
                                for (SIdx := 0..State.Config.DefensePlacementSpots.Length-1):
                                    if (OSpot := State.Config.DefensePlacementSpots[SIdx]):
                                        if (PlacedDef := OSpot.PlacedDefender?):
                                            if (PlacedDef.Prop = TargetProp):
                                                CleanupPlacementSpot(OSpot)
                                
                                Print("✅ [ID:{EnemyID}] DEFENDER KILLED - EXITING")
                                return
                        else:
                            Sleep(0.1)
        else:
            # Defender not found in array (already removed)
            Print("⚠️ [ID:{EnemyID}] DEFENDER NO LONGER IN ARRAY")
            return
```

## Key Changes

1. **No more array indices** - Use `Prop` as the stable identifier
2. **Animation key uses Prop hash** - Won't change as array shifts
3. **Search by Prop each time** - Finds correct defender even if array changes
4. **Only dispose the specific Prop** - No index confusion

## Why This Works

**BEFORE:**
```
DefIdx = 1 → Defender B
[Defender A dies, array shifts]
DefIdx = 1 → Now points to Defender C! ❌
```

**AFTER:**
```
TargetProp = DefenderB's Prop
[Defender A dies, array shifts]
Search for TargetProp → Still finds Defender B ✅
```

The `Prop` object reference never changes, so it's a perfect stable identifier!
