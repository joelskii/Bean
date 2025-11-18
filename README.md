# Tower Defense - Animation Stacking Bug Fix

## Problem Statement

Attacker NPCs have their attack animations stacking when they move from one defender to another:
- ✅ **Defender 1**: Works perfectly
- ❌ **Defender 2+**: Animations stack and overlap
- ✅ **Fresh spawns**: Work perfectly after death/respawn

## Root Cause

The `animation_manager` class has a `PlayAnimationAsync` coroutine that doesn't listen to cancel events:

```verse
PlayAnimationAsync(...)<suspends>:void =
    race:
        block: Anim.PlayAndAwait(Seq)
        block: Sleep(AttackInterval)
        # ❌ NO CANCEL LISTENER!
    set IsPlaying = false
```

When an NPC moves from Defender 1 to Defender 2:
1. Old animation coroutine keeps running (no way to stop it)
2. New animation coroutine starts
3. Both run simultaneously = animation stacking

## The Solution

Add a cancel event to the animation manager and make the coroutine race against it:

### 1. Update animation_manager class
- Add `CancelEvent : event()` property
- Add `CancelAllAnimations()` method  
- Make `PlayAnimationAsync` race against `CancelEvent.Await()`

### 2. Cancel animations when switching targets
- Call `AnimMgr.CancelAllAnimations()` when defender dies
- This signals the cancel event
- Old coroutine exits cleanly
- New animation starts fresh

## Fix Documentation

This repository contains three detailed fix documents:

1. **[ANIMATION_STACKING_FIX.md](ANIMATION_STACKING_FIX.md)**
   - Complete step-by-step instructions
   - Shows exact code locations and replacements
   - Includes all 3 required changes

2. **[QUICK_FIX.md](QUICK_FIX.md)**
   - Simplified explanation in plain English
   - One-line root cause summary
   - Quick reference for the fix

3. **[WHY_IT_FAILS.md](WHY_IT_FAILS.md)**
   - Visual diagrams of the broken vs fixed flow
   - Architecture explanation
   - Shows why previous attempts failed

## Implementation Summary

The fix requires **3 code changes**:

1. **Update `animation_manager` class** (~line 1000)
   - Add cancel event and listener method

2. **Cancel when defender prop invalid** (~line 2800)
   - Call `AnimMgr.CancelAllAnimations()` before breaking loop

3. **Cancel when defender dies from damage** (~line 2950)
   - Call `AnimMgr.CancelAllAnimations()` before disposing prop

## Why This Works

Each `animation_manager` has its own `CancelEvent`:
- When defender dies → signal cancel event
- `PlayAnimationAsync` is racing against `CancelEvent.Await()`
- Signal arrives → race ends → coroutine exits
- Only one animation per NPC at a time ✅

## Testing Checklist

After applying the fix:
- [ ] Defender 1 attacks work (baseline - was already working)
- [ ] Defender 2+ attacks work without stacking
- [ ] Multiple NPCs have independent animations
- [ ] Fresh spawns after death still work
- [ ] No animation overlap or duplication

## Technical Details

**Language**: UEFN Verse  
**System**: Tower Defense game mechanics  
**Component**: NPC animation management  
**Issue Type**: Race condition / coroutine lifecycle bug  

---

## Quick Start

1. Read [QUICK_FIX.md](QUICK_FIX.md) for the simple explanation
2. Apply the 3 changes from [ANIMATION_STACKING_FIX.md](ANIMATION_STACKING_FIX.md)
3. Test using the checklist above
4. If you want to understand WHY, read [WHY_IT_FAILS.md](WHY_IT_FAILS.md)

---

**Note**: This fix assumes you already have the `animation_manager` infrastructure in place. If not, you'll need to implement that first (see the `FIX_INSTRUCTIONS.md` from the previous fix attempt).
