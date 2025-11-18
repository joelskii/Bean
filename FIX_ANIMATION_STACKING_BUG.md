# Fix for NPC Attack Animation Stacking Bug

## Root Cause
The bug occurs in the `animation_manager` class's `StartAnimation` method. When an enemy switches from attacking one defender to another, the old animation gets cancelled BUT the `IsPlaying` flag is never reset to `false`. This causes the animation system to think an animation is still playing, preventing new animations from starting immediately. Then on subsequent attack loops, the timing gets out of sync and multiple animations queue up and play simultaneously.

## The Fix
In the `animation_manager` class, locate the `StartAnimation` method around line 690-704:

### BEFORE (Buggy Code):
```verse
StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, DefenderIndex:int):void =
    # ✅ If attacking a different defender, cancel old animation
    if (DefenderIndex <> CurrentDefenderIndex):
        if (IsPlaying = true):
            CancelEvent.Signal()
            set CancelEvent = event(){}  # ❌ BUG: IsPlaying still true!
        set CurrentDefenderIndex = DefenderIndex
    
    # Only start if not already playing for THIS defender
    if (IsPlaying = false):
        set IsPlaying = true
        spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
```

### AFTER (Fixed Code):
```verse
StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, DefenderIndex:int):void =
    # ✅ If attacking a different defender, cancel old animation
    if (DefenderIndex <> CurrentDefenderIndex):
        if (IsPlaying = true):
            CancelEvent.Signal()
            set IsPlaying = false  # ✅ FIX: Reset flag immediately when switching defenders
            set CancelEvent = event(){}
        set CurrentDefenderIndex = DefenderIndex
    
    # Only start if not already playing for THIS defender
    if (IsPlaying = false):
        set IsPlaying = true
        spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
```

## The Change
**Add ONE line:** `set IsPlaying = false` immediately after `CancelEvent.Signal()`

This ensures that when an enemy switches to attack a new defender:
1. The old animation is cancelled
2. The `IsPlaying` flag is immediately reset
3. A new animation can start right away without timing issues
4. No animations can stack up or play multiple times

## Why This Works
- **Before**: When switching defenders, `IsPlaying` stayed `true`, so the next call to `StartAnimation` would skip spawning a new animation. Eventually the old animation would finish and set `IsPlaying = false`, but by then multiple attack loop iterations would have occurred, causing animations to queue up.
  
- **After**: When switching defenders, `IsPlaying` is immediately reset to `false`, allowing a fresh animation to start right away. The `CurrentDefenderIndex` tracking ensures we don't start multiple animations for the same defender.

## Testing
After applying this fix:
1. Start a tower defense round
2. Watch enemies attack the first defender - animations should play normally (1 per attack interval)
3. When the first defender dies and enemies move to the second defender - animations should continue playing normally without stacking
4. Verify no duplicate animations play when switching between defenders

The fix is a single line addition and should completely resolve the 3-day animation stacking issue.
