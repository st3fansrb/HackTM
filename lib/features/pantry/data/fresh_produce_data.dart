class FreshProduceEntry {
  final String name;
  final int baseShelfLifeDays;
  final double fridgeMultiplier;
  final double freezerMultiplier;

  const FreshProduceEntry(
    this.name, {
    required this.baseShelfLifeDays,
    required this.fridgeMultiplier,
    required this.freezerMultiplier,
  });
}

const kFreshProduceTable = <FreshProduceEntry>[
  FreshProduceEntry('Mere',          baseShelfLifeDays: 30, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Pere',          baseShelfLifeDays: 10, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Banane',        baseShelfLifeDays:  2, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Portocale',     baseShelfLifeDays: 21, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Mandarine',     baseShelfLifeDays: 14, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Lămâi',        baseShelfLifeDays: 21, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Grapefruit',    baseShelfLifeDays: 21, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Kiwi',          baseShelfLifeDays: 10, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Căpșuni',      baseShelfLifeDays:  3, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Cireșe',       baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Vișine',       baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Struguri',      baseShelfLifeDays: 14, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Pepene verde',  baseShelfLifeDays:  5, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Pepene galben', baseShelfLifeDays:  5, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Piersici',      baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Prune',         baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Caise',         baseShelfLifeDays:  5, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Mango',         baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Ananas',        baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Avocado',       baseShelfLifeDays:  3, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Roșii',        baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Castraveți',   baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Ardei gras',    baseShelfLifeDays: 14, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Vinete',        baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Dovlecei',      baseShelfLifeDays: 10, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Morcovi',       baseShelfLifeDays: 60, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Cartofi',       baseShelfLifeDays: 14, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Ceapă',        baseShelfLifeDays: 60, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Usturoi',       baseShelfLifeDays: 60, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Varză',        baseShelfLifeDays: 21, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Conopidă',     baseShelfLifeDays: 10, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Broccoli',      baseShelfLifeDays: 10, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Spanac',        baseShelfLifeDays:  5, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Salată verde', baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Rucola',        baseShelfLifeDays:  5, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Ciuperci',      baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Păstârnac',    baseShelfLifeDays: 21, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Țelină',       baseShelfLifeDays: 14, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Praz',          baseShelfLifeDays: 10, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
  FreshProduceEntry('Fasole verde',  baseShelfLifeDays:  7, fridgeMultiplier: 1.0, freezerMultiplier: 10.0),
];

const kDefaultFreshEntry = FreshProduceEntry(
  'Generic',
  baseShelfLifeDays: 30,
  fridgeMultiplier: 1.0,
  freezerMultiplier: 10.0,
);

const kRipenessMultipliers = [2.0, 1.5, 1.0, 0.7, 0.4];
const kRipenessLabels = ['Necopt', 'Aproape\ncopt', 'Copt', 'Copt\nbine', 'Foarte\ncopt'];

FreshProduceEntry lookupFreshProduce(String name) {
  final lower = name.toLowerCase().trim();
  if (lower.isEmpty) return kDefaultFreshEntry;
  for (final entry in kFreshProduceTable) {
    if (lower.contains(entry.name.toLowerCase()) ||
        entry.name.toLowerCase().contains(lower)) {
      return entry;
    }
  }
  return kDefaultFreshEntry;
}

double getStorageMultiplier(FreshProduceEntry entry, String storageLocation) {
  switch (storageLocation) {
    case 'frigider':
      return entry.fridgeMultiplier;
    case 'congelator':
      return entry.freezerMultiplier;
    default:
      return 1.0 * 0.4;
  }
}

DateTime calcEstimatedExpiry({
  required int baseShelfLifeDays,
  required double storageMultiplier,
  required int ripenessLevel,
  required bool isBio,
}) {
  final ripMult = kRipenessMultipliers[ripenessLevel];
  final bioMult = isBio ? 0.72 : 1.0;
  final totalDays = baseShelfLifeDays * ripMult * bioMult * storageMultiplier;
  final hours = (totalDays * 24).round().clamp(1, 365 * 24);
  return DateTime.now().add(Duration(hours: hours));
}

double calcCurrentRipeness({
  required int initialRipeness,
  required int baseShelfLifeDays,
  required DateTime addedAt,
  required String storageLocation,
  required FreshProduceEntry entry,
}) {
  final storeMult = getStorageMultiplier(entry, storageLocation);
  final initialRipMult = kRipenessMultipliers[initialRipeness];
  final daysSinceAdded = DateTime.now().difference(addedAt).inHours / 24.0;
  if (initialRipMult <= 0 || storeMult <= 0) return initialRipeness.toDouble();
  final progressPerDay = 4.0 / (baseShelfLifeDays * initialRipMult * storeMult);
  return (initialRipeness + daysSinceAdded * progressPerDay).clamp(0.0, 4.0);
}