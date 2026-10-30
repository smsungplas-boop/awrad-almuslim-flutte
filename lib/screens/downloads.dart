import 'dart:io';
import 'package:flutter/material.dart';
import '../models/content.dart';
import '../services/quran.dart';
import '../services/store.dart';
import 'quran_reader.dart';
/// Sequential downloads avoid exhausting storage or opening thousands of requests.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    required this.store
  });
  final Store store;
  @override State<DownloadsScreen> createState() => _DownloadsScreenState();
} class _DownloadsScreenState extends State<DownloadsScreen> {
  final service = QuranService();
  bool busy = false,
  cancel = false;
  String status = '';
  int reader = 0;
  Map<int,
  int> saved = {
  };
  @override void initState() {
    super.initState();
    reader = widget.store.get<int>('reader',
    0);
    refresh();
  } String key(int s,
  int a) => '${readers[reader][1]}_${s}_$a';
  String url(int s,
  int a) => 'https://everyayah.com/data/${readers[reader][1]}/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3';
  Future<void> refresh() async {
    final dir = await service.directory;
    final result = <int,
    int>{
    };
    await for (final f in dir.list()) {
      final name = f.uri.pathSegments.last;
      final prefix = '${readers[reader][1]}_';
      if (name.startsWith(prefix) && name.endsWith('.mp3')) {
        final s = int.tryParse(name.substring(prefix.length).split('_').first);
        if (s != null) {
          result[s] = (result[s] ?? 0) + 1;
        }
      }
    } if (mounted) {
      setState(() => saved = result);
    }
  } Future<void> download(List<int> surahs) async {
    if (busy) {
      return;
    } setState(() {
      busy = true;
      cancel = false;
    });
    try {
      for (final s in surahs) {
        final count = (widget.store.content['counts'] as List)[s - 1] as int;
        for (var a = 1; a <= count; a++) {
          if (cancel || !mounted) {
            return;
          } setState(() => status = '${widget.store.names[s - 1]} • ${ar(a)} / ${ar(count)}');
          final path = await service.downloadAudio(key(s,
          a),
          url(s,
          a));
          // Cache filename is deterministic; no large preference write per verse.
          if (path.isEmpty) {
            throw const FileSystemException('ملف غير متاح');
          }
        } await refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('توقف التنزيل: $e. يمكنك استكمال المحفوظ لاحقاً.')));
      }
    } finally {
      await refresh();
      if (mounted) {
        setState(() {
          busy = false;
          status = '';
        });
      }
    }
  } Future<void> remove(int s) async {
    final yes = await showDialog<bool>(context: context,
    builder: (c) => AlertDialog( title: Text('حذف تسجيل سورة ${widget.store.names[s - 1]}؟'),
    actions: [TextButton(onPressed: () => Navigator.pop(c,
    false),
    child: const Text('إلغاء')),
    TextButton(onPressed: () => Navigator.pop(c,
    true),
    child: const Text('حذف'))],
    ));
    if (yes != true) {
      return;
    } final dir = await service.directory;
    await for (final f in dir.list()) {
      if (f.uri.pathSegments.last.startsWith('${readers[reader][1]}_${s}_')) {
        await f.delete();
      }
    } await refresh();
  } @override void dispose() {
    cancel = true;
    super.dispose();
  } @override Widget build(BuildContext context) => Scaffold( appBar: AppBar(title: const Text('مكتبة التلاوات')),
  body: Column(children: [ Padding(padding: const EdgeInsets.all(16),
  child: DropdownButtonFormField<int>( value: reader,
  decoration: const InputDecoration(labelText: 'القارئ'),
  items: List.generate(readers.length,
  (i) => DropdownMenuItem(value: i,
  child: Text(readers[i][0]))),
  onChanged: busy ? null : (i) {
    if (i != null) {
      setState(() => reader = i);
      refresh();
    }
  },
  )),
  if (busy) ...[ const LinearProgressIndicator(),
  Text(status),
  TextButton(onPressed: () => setState(() => cancel = true),
  child: const Text('إيقاف بعد الملف الحالي')),
  ] else TextButton.icon( onPressed: () async {
    final yes = await showDialog<bool>(context: context,
    builder: (c) => AlertDialog( title: const Text('تنزيل تلاوة القرآن كاملة؟'),
    content: const Text('قد تستهلك مساحة كبيرة ووقتاً طويلاً. تُحفظ الملفات المكتملة ويمكن استكمالها.'),
    actions: [TextButton(onPressed: () => Navigator.pop(c),
    child: const Text('إلغاء')),
    FilledButton(onPressed: () => Navigator.pop(c,
    true),
    child: const Text('تنزيل'))],
    ));
    if (yes == true) {
      download(List.generate(114,
      (i) => i + 1));
    }
  },
  icon: const Icon(Icons.download),
  label: const Text('تنزيل القرآن كاملاً لهذا القارئ'),
  ),
  Expanded(child: ListView.builder(itemCount: 114,
  itemBuilder: (c,
  i) {
    final n = i + 1,
    count = (widget.store.content['counts'] as List)[i] as int;
    final complete = saved[n] == count;
    return ListTile(title: Text(widget.store.names[i]),
    subtitle: Text('${ar(saved[n] ?? 0)} / ${ar(count)} آية محفوظة'),
    leading: Icon(complete ? Icons.offline_pin : Icons.cloud_download_outlined),
    onTap: () => Navigator.push<void>(context,
    MaterialPageRoute(builder: (_) => QuranReader(store: widget.store,
    surah: n))),
    trailing: Wrap(children: [ if (!complete) IconButton(tooltip: 'تنزيل السورة',
    onPressed: busy ? null : () => download([n]),
    icon: const Icon(Icons.download)),
    if ((saved[n] ?? 0) > 0) IconButton(tooltip: 'حذف',
    onPressed: busy ? null : () => remove(n),
    icon: const Icon(Icons.delete_outline)),
    ]),
    );
  })),
  ]),
  );
}
