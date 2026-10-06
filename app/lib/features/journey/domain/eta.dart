/// Straight-line walking estimate, computed on the phone: no route is sent
/// to a third-party routing service.
///
/// Average walking speed is about 1.3 m/s (4.7 km/h). Streets are rarely
/// straight, so the distance is stretched by 30%. Rounded up to 5 minutes,
/// never less than 5.
int estimateWalkMinutes(double straightLineMeters) {
  const speed = 1.3;
  const detour = 1.3;
  final minutes = straightLineMeters * detour / speed / 60;
  final rounded = ((minutes / 5).ceil() * 5).clamp(5, 24 * 60);
  return rounded;
}

/// How long after the expected arrival the Circle is alerted.
const journeyGrace = Duration(minutes: 10);

/// Arrival counts within this distance of the destination.
const arrivalRadiusMeters = 150.0;

/// Choices for the check-in timer.
const checkInDurations = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
];
