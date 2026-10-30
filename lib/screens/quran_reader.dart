import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/content.dart';
import '../services/quran.dart';
import '../services/store.dart';
import 'audio_panel.dart';
import 'card_editor.dart';
const readers=[['العفاسي',
'Alafasy_64kbps'],
['السديس',
'Abdurrahmaan_As-Sudais_64kbps'],
['الشريم',
'Saood_ash-Shuraym_64kbps'],
['المعيقلي',
'Maher_AlMuaiqly_64kbps'],
['عبد الباسط',
'Abdul_Basit_Murattal_64kbps'],
['الحصري',
'Husary_64kbps'],
['المنشاوي',
'Minshawy_Murattal_128kbps'],
['الغامدي',
'Ghamadi_40kbps'],
['الشاطري',
'Abu_Bakr_Ash-Shaatree_64kbps'],
['الحذيفي',
'Hudhaify_64kbps']];
class QuranReader extends StatefulWidget {
  const QuranReader({
    super.key,
    required this.store,
    this.page=1,
    this.surah,
    this.initialAyah
  });
  final Store store;
  final int page;
  final int? surah;
  final int? initialAyah;
  @override State<QuranReader> createState()=>_QuranReaderState();
} class _QuranReaderState extends State<QuranReader> {
  final service=QuranService();
  late Future<Map<String,
  dynamic>> future;
  late int page;
  bool bySurah=false;
  double size=26;
  String? audioUrl,
  audioId;
  int audioSurah=1,
  audioAyah=1;
  final scroll=ScrollController();
  final target=GlobalKey();
  bool jumped=false;
  @override void initState(){
    super.initState();
    page=widget.page;
    bySurah=widget.surah!=null;
    size=widget.store.get<num>('size',
    26).toDouble();
    load();
    WakelockPlus.enable();
  } void load(){
    future=service.fetch(bySurah?'surah/${widget.surah}':'page/$page');
    if(!bySurah){
      widget.store.set('lastPage',
      page);
    }
  } void move(int n){
    if(n<1||n>604){
      return;
    }setState((){
      bySurah=false;
      page=n;
      audioId=null;
      load();
    });
    if(scroll.hasClients){
      scroll.jumpTo(0);
    }
  } @override void dispose(){
    scroll.dispose();
    WakelockPlus.disable();
    super.dispose();
  } Future<void> options(Map<String,
  dynamic> ay) async {
    final s=bySurah?widget.surah!:(ay['surah'] as Map)['number'] as int;
    final a=ay['numberInSurah'] as int,
    t=ay['text'] as String;
    await showModalBottomSheet<void>(context:context,
    showDragHandle:true,
    builder:(c)=>SafeArea(child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
    children:[ ListTile(title:Text('${widget.store.names[s-1]} • ${ar(a)}')),
    ListTile(leading:const Icon(Icons.copy),
    title:const Text('نسخ الآية'),
    onTap:(){
      Clipboard.setData(ClipboardData(text:'﴿$t﴾ [${widget.store.names[s-1]}:$a]'));
      Navigator.pop(c);
    }),
    ListTile(leading:const Icon(Icons.share),
    title:const Text('مشاركة'),
    onTap:(){
      Navigator.pop(c);
      Share.share('﴿$t﴾ [${widget.store.names[s-1]}:$a]');
    }),
    ListTile(leading:const Icon(Icons.palette_outlined),
    title:const Text('تصميم بطاقة وطباعتها'),
    onTap:(){
      Navigator.pop(c);
      Navigator.push<void>(context,
      MaterialPageRoute(builder:(_)=>CardEditor(text:t,
      title:'سورة ${widget.store.names[s-1]} • الآية ${ar(a)}')));
    }),
    ...List.generate(3,
    (i)=>ListTile(leading:Icon(Icons.bookmark,
    color:[Colors.amber,
    Colors.green,
    Colors.blue][i]),
    title:Text(['علامة القراءة',
    'علامة الحفظ',
    'علامة المراجعة'][i]),
    onTap:(){
      widget.store.set('bookmark$i',
      {
        's':s,
        'a':a,
        'p':ay['page']??page
      });
      Navigator.pop(c);
      setState((){
      });
    })),
    ListTile(leading:const Icon(Icons.play_arrow),
    title:const Text('استماع إلى الآية'),
    onTap:(){
      Navigator.pop(c);
      play(s,
      a);
    }),
    ]))));
  } void play(int s,
  int a){
    if(s<1||s>114){
      return;
    } final count=(widget.store.content['counts'] as List)[s-1] as int;
    if(a>count){
      play(s+1,
      1);
      return;
    } if(a<1){
      if(s>1){
        play(s-1,
        (widget.store.content['counts'] as List)[s-2] as int);
      }return;
    } final r=widget.store.get<int>('reader',
    0);
    setState((){
      audioSurah=s;
      audioAyah=a;
      audioId='${readers[r][1]}_${s}_$a';
      audioUrl='https://everyayah.com/data/${readers[r][1]}/${s.toString().padLeft(3,'0')}${a.toString().padLeft(3,'0')}.mp3';
    });
  } @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(bySurah?'سورة ${widget.store.names[widget.surah!-1]}':'المصحف • صفحة ${ar(page)}'),
  actions:[IconButton(tooltip:'تكبير الخط',
  onPressed:()=>setState(()=>size=size>=40?20:size+2),
  icon:const Icon(Icons.text_increase)),
  IconButton(tooltip:'الانتقال لصفحة',
  icon:const Icon(Icons.find_in_page_outlined),
  onPressed:()async{
    final t=TextEditingController(text:'$page');
    final n=await showDialog<int>(context:context,
    builder:(c)=>AlertDialog(title:const Text('رقم الصفحة ١–٦٠٤'),
    content:TextField(controller:t,
    keyboardType:TextInputType.number),
    actions:[TextButton(onPressed:(){
      final n=int.tryParse(t.text);
      if(n!=null&&n>=1&&n<=604){
        Navigator.pop(c,
        n);
      }
    },
    child:const Text('انتقال'))]));
    t.dispose();
    if(n!=null){
      move(n);
    }
  })]),
  body:Column(children:[ if(audioId!=null)AudioPanel(key:ValueKey(audioId),
  id:audioId!,
  url:audioUrl!,
  store:widget.store,
  autoplay:true,
  onNext:()=>play(audioSurah,
  audioAyah+1),
  onPrevious:()=>play(audioSurah,
  audioAyah-1)),
  Expanded(child:FutureBuilder<Map<String,
  dynamic>>(future:future,
  builder:(c,
  s){
    if(s.hasError){
      return Center(child:Column(mainAxisSize:MainAxisSize.min,
      children:[const Icon(Icons.cloud_off,
      size:48),
      const Text('تعذر تحميل الصفحة. تحقق من الاتصال.'),
      TextButton(onPressed:()=>setState(load),
      child:const Text('إعادة المحاولة'))]));
    }if(!s.hasData){
      return const Center(child:CircularProgressIndicator());
    }final ayahs=List<Map<String,
    dynamic>>.from((s.data!['ayahs'] as List).map((e)=>Map<String,
    dynamic>.from(e as Map)));
    if(!jumped&&widget.initialAyah!=null){
      jumped=true;
      WidgetsBinding.instance.addPostFrameCallback((_){
        final ctx=target.currentContext;
        if(ctx!=null){
          Scrollable.ensureVisible(ctx,
          alignment:.15);
        }
      });
    } return SingleChildScrollView(controller:scroll,
    padding:const EdgeInsets.all(20),
    child:Column(children:List.generate(ayahs.length,
    (i){
      final a=ayahs[i];
      final first=i==0||a['numberInSurah']==1;
      return Column(key:a['numberInSurah']==widget.initialAyah?target:null,
      children:[if(first)Container(width:double.infinity,
      margin:const EdgeInsets.symmetric(vertical:16),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,
      borderRadius:BorderRadius.circular(24)),
      child:Text('سورة ${bySurah?widget.store.names[widget.surah!-1]:(a['surah'] as Map)['name']} • الجزء ${ar(a['juz'])}',
      textAlign:TextAlign.center)),
      InkWell(onTap:()=>options(a),
      borderRadius:BorderRadius.circular(16),
      child:Padding(padding:const EdgeInsets.symmetric(vertical:12,
      horizontal:8),
      child:Text('${a['text']} ﴿${ar(a['numberInSurah'])}﴾',
      textAlign:TextAlign.center,
      style:TextStyle(fontSize:size,
      height:2.2))))]);
    })));
  })),
  if(!bySurah)SafeArea(top:false,
  child:Padding(padding:const EdgeInsets.all(12),
  child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
  children:[FilledButton.tonal(onPressed:page>1?()=>move(page-1):null,
  child:const Text('السابقة')),
  Text('${ar(page)} / ٦٠٤'),
  FilledButton(onPressed:page<604?()=>move(page+1):null,
  child:const Text('التالية'))]))),
  ]));
}
