# Battery strategy

AfriSafety must keep working all day on a 2 GB-RAM Android phone during load
shedding, without draining the battery or mobile data. This is how.

## Tracking modes

`LocationPolicy` (`app/lib/features/sharing/domain/location_policy.dart`)
picks a mode from recent movement, battery level and what the user is doing.

| Mode | When | Accuracy | Distance filter | Upload at most every | Heartbeat |
|---|---|---|---|---|---|
| Moving | speed ≥ 1 m/s or moved > 50 m in 5 min | high | 25 m | 30 s | 5 min |
| Stationary | no movement > 50 m for 5 min | balanced | 100 m | 2 min | 15 min |
| Low battery | battery < 15 % | low | 250 m | 5 min | 30 min |
| Emergency | SOS, check-in timer or journey running | high | 0 m | 10 s | 30 s |

Emergency mode ignores battery saving on purpose: a walk home or an SOS is
when location matters most, and it lasts minutes, not hours.

## What runs when

- Location is collected only inside the Android foreground service, with its
  notification. Nothing runs while sharing is paused everywhere, unless the
  user starts an SOS, a check-in timer or a journey.
- **Places, history and journeys add no extra GPS use.** They reuse the fixes
  the sharing stream already produces. Geofencing is a distance calculation on
  each fix, not a separate OS geofence registration.
- The check-in escrow is refreshed at most every 2 minutes.
- History records at most one point per 100 m moved or 10 minutes.

## Data use

- A location update is 19 bytes before encryption (about 80 bytes on the
  wire). A Circle event is under 100 bytes.
- Only the newest unsent fix per Circle is retried; stale fixes are dropped.
- Map tiles load only when the map is on screen.

## Staying alive

- The Flutter engine is process-wide, so sharing survives swiping the app
  away while the foreground service runs.
- Samsung, Xiaomi, Oppo and Transsion phones (Tecno, Infinix, itel) still kill
  background apps aggressively. The Safety tab explains how to set **Battery →
  Unrestricted**, and the map always shows "last updated" honestly.

## Ideas not yet built

- Activity recognition (walking / in vehicle / still) to switch modes sooner.
- Batching uploads on 2G/EDGE.
- Measured battery numbers on a real Galaxy A05 over a full day.
