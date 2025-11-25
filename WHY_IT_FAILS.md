# Why Animation Stacking Happens: A Visual Explanation

## Current Broken Flow

```
NPC attacks Defender 1:
├─ animation_manager.StartAnimation() called
├─ spawn{PlayAnimationAsync()} → Coroutine A starts
│  └─ race { Anim.Play() | Sleep(1.0) }  ← Only 2 conditions
└─ Animation plays correctly ✅

Defender 1 dies:
├─ CurrentDefenderCancelEvent.Signal()  ← You signal this
├─ Sleep(0.1)
└─ Move to Defender 2

❌ PROBLEM: Coroutine A is STILL RUNNING!
   └─ It's racing against Anim.Play() and Sleep()
   └─ It NEVER checks CurrentDefenderCancelEvent
   └─ So it keeps looping!

NPC attacks Defender 2:
├─ animation_manager.StartAnimation() called AGAIN
├─ Check: IsPlaying = false (Coroutine A finished its race)
├─ spawn{PlayAnimationAsync()} → Coroutine B starts
│  └─ race { Anim.Play() | Sleep(1.0) }
└─ BUT WAIT...

❌ Coroutine A is STILL in the attack loop!
   └─ It's doing: Play sound → Damage → Sleep(AttackInterval) → loop
   └─ So now BOTH Coroutine A and B are playing animations!

Result: ANIMATION STACKING 💥
```

---

## What You Thought Was Happening

```
Defender 1 dies:
├─ CurrentDefenderCancelEvent.Signal()  ← Signal sent
└─ ❓ Magic happens and animations stop?

NO! The animation coroutine doesn't know about this event!
```

---

## The Fixed Flow

```
NPC attacks Defender 1:
├─ animation_manager.StartAnimation() called
├─ spawn{PlayAnimationAsync()} → Coroutine A starts
│  └─ race { 
│      Anim.Play() | 
│      Sleep(1.0) | 
│      CancelEvent.Await()  ← ✅ NOW LISTENS!
│     }
└─ Animation plays correctly ✅

Defender 1 dies:
├─ AnimationManager.CancelAllAnimations()  ← New method
│  └─ CancelEvent.Signal()
├─ Coroutine A receives signal via CancelEvent.Await() ✅
├─ Coroutine A: race condition ends immediately
├─ Coroutine A: set IsPlaying = false
└─ Coroutine A: EXITS ✅

NPC attacks Defender 2:
├─ animation_manager.StartAnimation() called
├─ Check: IsPlaying = false ✅
├─ spawn{PlayAnimationAsync()} → Coroutine B starts
│  └─ race { Anim.Play() | Sleep(1.0) | CancelEvent.Await() }
└─ ONLY Coroutine B is running ✅

Result: NO STACKING ✅
```

---

## The Key Insight

**Your code was SIGNALING but not LISTENING!**

```verse
# You had this:
CurrentDefenderCancelEvent.Signal()  ← Sending signal

# But PlayAnimationAsync was:
race:
    block: Anim.PlayAndAwait(Seq)
    block: Sleep(AttackInterval)
    # ❌ NO LISTENER FOR THE SIGNAL!

# It needed:
race:
    block: Anim.PlayAndAwait(Seq)
    block: Sleep(AttackInterval)
    block: CancelEvent.Await()  ← ✅ LISTENER!
```

---

## Why "Everything" Failed Before

1. **Tried different cancel events?**
   - Doesn't matter - coroutine wasn't listening to ANY event

2. **Tried longer sleeps after signaling?**
   - Doesn't help - coroutine keeps running indefinitely

3. **Tried clearing IsPlaying flag?**
   - Doesn't stop the spawned coroutine

4. **Tried disposing animation manager?**
   - Coroutine already spawned, it's independent

**The ONLY way to stop a spawned coroutine is to make it AWAIT an event that you can signal!**

---

## The Architecture Problem

```
Your mental model:
┌─────────────────┐
│ Attack Loop     │
│  ┌──────────┐   │
│  │ Play Anim│   │ ← You thought this was inside the loop
│  └──────────┘   │
└─────────────────┘
Signal cancel → Loop stops → Animation stops ✅

Actual architecture:
┌──────────────────────────────┐
│ Attack Loop                  │
│  │                           │
│  ├─ spawn{PlayAnimAsync()}  │ ← Spawns independent coroutine
│  │         ↓                 │
│  │    [Coroutine Land]       │
│  │    ┌──────────────┐       │
│  │    │ Play Anim    │       │ ← Lives independently!
│  │    │ (racing...)  │       │
│  │    └──────────────┘       │
│  │                           │
│  └─ Sleep(AttackInterval)    │
└──────────────────────────────┘

Signal cancel → Loop stops → BUT COROUTINE KEEPS GOING! ❌
```

---

## The Fix: Give Coroutines a Leash

```verse
# Before (coroutine runs free):
spawn{PlayAnimationAsync(...)}  
# ↑ Like releasing a dog with no leash

# After (coroutine can be recalled):
var CancelEvent : event() = event(){}
spawn{
    race:
        PlayAnimation()
        CancelEvent.Await()  ← The leash!
}

# When you need to stop it:
CancelEvent.Signal()  ← Pull the leash!
```

---

## Summary

**The bug exists because:**
1. `PlayAnimationAsync` is a spawned coroutine (runs independently)
2. It only races against animation duration and a timer
3. It has NO mechanism to listen for cancel signals
4. When you move to the next defender, the old coroutine keeps running
5. The new defender starts a NEW coroutine
6. Now both are running = stacking

**The fix:**
1. Add `CancelEvent` to `animation_manager`
2. Make `PlayAnimationAsync` race against `CancelEvent.Await()`
3. Call `CancelEvent.Signal()` when moving to next defender
4. Old coroutine exits, new one starts fresh
5. Only one animation at a time ✅
