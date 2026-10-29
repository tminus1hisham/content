/// Fictional demo identities; each has five distinct local photographs.
const demoPhotoSets = {
  'u1': 'fan',
  'u2': 'amani',
  'u3': 'new',
  'u5': 'pendo',
  'c10': 'zuri',
  'c11': 'kofi',
  'c12': 'neema',
};

String? demoImageFor(String id, {int number = 1}) {
  assert(number >= 1 && number <= 5);
  final name = demoPhotoSets[id];
  return name == null ? null : 'assets/demo/$name-$number.jpg';
}
