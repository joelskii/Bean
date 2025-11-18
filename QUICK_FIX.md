# Quick Fix for Animation Stacking Bug

## The Problem in Plain English

Your `animation_manager` class is supposed to prevent animation stacking, but it doesn't actually work because:

**The animation coroutine doesn't know when to stop!**

Look at this code:
```verse
PlayAnimationAsync(...)<suspends>:void =
    race:
        block:
            Anim.PlayAndAwait(Seq)
        block:
            Sleep(AttackInterval)  # ⚠️ Only races against timer!
    set IsPlaying = false
```

When you signal `CurrentDefenderCancelEvent`, this coroutine **keeps running** because it's only racing against the animation duration and sleep timer - there's no cancel listener!

---

## The One-Line Root Cause

**The animation manager's `PlayAnimationAsync` doesn't listen to any cancel signal, so old animations keep playing when moving to the next defender.**

---

## The Fix (3 Changes)

### Change 1: Add cancel event to animation_manager
```verse
animation_manager := class:
    var IsPlaying : logic = false
    var CancelEvent : event() = event(){}  # ✅ ADD THIS
    
    StartAnimation(...):void =
        if (IsPlaying = true):
            CancelEvent.Signal()  # ✅ Cancel old animation
            Sleep(0.05)
            set CancelEvent = event(){}  # ✅ New event for next animation
        set IsPlaying = true
        spawn{PlayAnimationAsync(...)}
    
    CancelAllAnimations():void =  # ✅ ADD THIS METHOD
        if (IsPlaying = true):
            CancelEvent.Signal()
            set IsPlaying = false
```

### Change 2: Make PlayAnimationAsync listen to cancel
```verse
PlayAnimationAsync(...)<suspends>:void =
    race:
        block:
            Anim.PlayAndAwait(Seq)
        block:
            Sleep(AttackInterval)
        block:
            CancelEvent.Await()  # ✅ ADD THIS BLOCK!
    set IsPlaying = false
```

### Change 3: Call cancel when moving to next defender
```verse
if (not Def.Prop.IsValid[]):
    # ✅ ADD THESE 2 LINES
    if (AnimMgr := AnimationManagers[EnemyAgent]):
        AnimMgr.CancelAllAnimations()
    
    CurrentDefenderCancelEvent.Signal()
    Sleep(0.1)
    break
```

---

## Why You've Tried "Everything" But It Didn't Work

You probably tried:
- ✅ Creating cancel events
- ✅ Signaling cancel events
- ✅ Waiting after signaling

**But you never made the animation coroutine actually LISTEN to the cancel event!**

It's like shouting "STOP!" at someone who's wearing headphones - you're making the signal, but they can't hear it.

By adding `CancelEvent.Await()` to the race condition in `PlayAnimationAsync`, you're giving the animation "ears" to hear the cancel signal.

---

## The Proof It Will Work

- **Defender 1 works**: First animation plays normally ✅
- **Defender 2+ broken**: Old animation still playing when new one starts ❌
- **After NPC death works**: Fresh NPC = fresh animation manager with IsPlaying=false ✅

This perfectly matches a scenario where old coroutines aren't being cancelled!
