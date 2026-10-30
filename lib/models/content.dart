class Dhikr {
  Dhikr(this.parts,
  this.repeat,
  this.source);
  final dynamic parts;
  final int repeat;
  final String source;
  factory Dhikr.fromJson(List<dynamic> j) => Dhikr(j[0],
  j[1] as int,
  j[2] as String);
  List<dynamic> toJson() => [parts,
  repeat,
  source];
} class Wird {
  Wird(this.id,
  this.title,
  this.subtitle,
  this.items);
  final String id,
  title,
  subtitle;
  final List<Dhikr> items;
  factory Wird.fromJson(List<dynamic> j) => Wird(j[0] as String,
  j[1] as String,
  j[2] as String,
  (j[3] as List).map((e) => Dhikr.fromJson(List<dynamic>.from(e as List))).toList());
  List<dynamic> toJson() => [id,
  title,
  subtitle,
  items.map((e) => e.toJson()).toList()];
} String normalize(String text) => text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06EDـ]'),
'').replaceAll(RegExp('[أإآٱ]'),
'ا').replaceAll('ى',
'ي').replaceAll('ة',
'ه');
String ar(Object n) => n.toString().replaceAllMapped(RegExp('[0-9]'),
(m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);
int dailyPages(int page,
int days) => ((604 - page) / days).ceil();
