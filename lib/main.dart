import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models/content.dart';
import 'services/store.dart';
import 'services/quran.dart';
import 'services/reminders.dart';
import 'screens/wird_reader.dart';
import 'screens/quran_reader.dart';
import 'screens/counter.dart';
import 'screens/card_editor.dart';
import 'screens/downloads.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HijriCalendar.setLocal('ar');
  final store=Store();
  try {
    await store.load();
    runApp(AwradApp(store:store));
  } catch(e){
    runApp(MaterialApp(home:Scaffold(body:Center(child:Text('تعذر فتح بيانات التطبيق: $e')))));
  }
} class AwradApp extends StatelessWidget {
  const AwradApp({
    super.key,
    required this.store
  });
  final Store store;
  @override Widget build(BuildContext context)=>ListenableBuilder(listenable:store,
  builder:(c,
  _) {
    const seeds=[Color(0xffa87826),
    Color(0xff167454),
    Color(0xff415ac7),
    Color(0xffae3b5b),
    Color(0xff444444)];
    final seed=seeds[store.get<int>('skin',
    0).clamp(0,
    4)];
    ThemeData theme(Brightness b){
      final scheme=ColorScheme.fromSeed(seedColor:seed,
      brightness:b);
      return ThemeData(useMaterial3:true,
      colorScheme:scheme,
      scaffoldBackgroundColor:b==Brightness.light?const Color(0xfffaf7ef):const Color(0xff151812),
      appBarTheme:const AppBarTheme(centerTitle:false),
      inputDecorationTheme:InputDecorationTheme(filled:true,
      fillColor:scheme.surfaceContainerLow,
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),
      borderSide:BorderSide.none)),
      cardTheme:CardThemeData(color:scheme.surfaceContainerLow,
      elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24))));
    } return MaterialApp(debugShowCheckedModeBanner:false,
    title:'أوراد المسلم',
    locale:const Locale('ar'),
    supportedLocales:const [Locale('ar')],
    localizationsDelegates:GlobalMaterialLocalizations.delegates,
    theme:theme(Brightness.light),
    darkTheme:theme(Brightness.dark),
    themeMode:store.get<bool>('dark',
    false)?ThemeMode.dark:ThemeMode.light,
    home:HomeScreen(store:store));
  });
} class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store
  });
  final Store store;
  @override State<HomeScreen> createState()=>_HomeScreenState();
} class _HomeScreenState extends State<HomeScreen> {
  int tab=0;
  String query='';
  final reminders=Reminders();
  bool reminderReady=false,
  downloading=false,
  cancelDownload=false;
  String downloadStatus='';
  static const native=MethodChannel('org.awrad.almuslim/native');
  Store get s=>widget.store;
  static const titles=['الرئيسية',
  'القرآن الكريم',
  'أذكاري',
  'أورادي',
  'المفضلة'];
  @override void initState(){
    super.initState();
    initReminders();
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(s.get<bool>('splash',
      true)){
        dedication();
      }
    });
  } Future<void> initReminders() async {
    try{
      await reminders.init();
      reminderReady=true;
      for(var i=0;i<2;i++){
        if(s.get<bool>('reminder$i',
        false)){
          final t=s.get<String>('time$i',
          i==0?'05:00':'16:30').split(':');
          await reminders.schedule(i,
          i==0?'أذكار الصباح':'أذكار المساء',
          int.parse(t[0]),
          int.parse(t[1]),
          true);
        }
      }
    }catch(e){
      if(mounted){
        message('تعذر تهيئة التذكير: $e');
      }
    }
  } void message(String text){
    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
    }
  } Future<void> safe(Future<void> Function() action)async{
    try{
      await action();
    }catch(e){
      message('تعذرت العملية: $e');
    }
  } void open(Wird g){
    if(g.id=='w8'){
      Navigator.push<void>(context,
      MaterialPageRoute(builder:(c)=>Scaffold(appBar:AppBar(title:const Text('دلائل الخيرات')),
      body:ListView(padding:const EdgeInsets.all(20),
      children:s.groups.where((g)=>RegExp(r'^dl[1-7]$').hasMatch(g.id)).map(groupTile).toList()))));
      return;
    }Navigator.push<void>(context,
    MaterialPageRoute(builder:(_)=>WirdReader(wird:g,
    store:s)));
  } void quran({
    int? surah,
    int? page
  })=>Navigator.push<void>(context,
  MaterialPageRoute(builder:(_)=>QuranReader(store:s,
  surah:surah,
  page:page??s.get<int>('lastPage',
  1))));
  Widget tile(String title,
  String subtitle,
  IconData icon,
  VoidCallback tap,
  {
    Widget? trailing
  })=>Card(margin:const EdgeInsets.only(bottom:10),
  child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,
  vertical:8),
  leading:Container(padding:const EdgeInsets.all(12),
  decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,
  borderRadius:BorderRadius.circular(16)),
  child:Icon(icon,
  color:Theme.of(context).colorScheme.primary)),
  title:Text(title,
  style:const TextStyle(fontWeight:FontWeight.bold)),
  subtitle:subtitle.isEmpty?null:Text(subtitle),
  trailing:trailing??const Icon(Icons.chevron_left),
  onTap:tap));
  Widget section(String t)=>Padding(padding:const EdgeInsets.only(top:20,
  bottom:12),
  child:Text(t,
  style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)));
  Widget groupTile(Wird g)=>tile(g.title,
  g.subtitle,
  Icons.auto_awesome_outlined,
  ()=>open(g),
  trailing:Row(mainAxisSize:MainAxisSize.min,
  children:[if(g.id.startsWith('custom'))PopupMenuButton<String>(onSelected:(v)=>editCustom(g,
  remove:v=='delete'),
  itemBuilder:(_)=>const [PopupMenuItem(value:'edit',
  child:Text('تعديل الورد')),
  PopupMenuItem(value:'delete',
  child:Text('حذف الورد'))]),
  IconButton(tooltip:'المفضلة',
  onPressed:()=>s.toggle(g.id),
  icon:Icon(s.favorite(g.id)?Icons.star:Icons.star_border,
  color:Theme.of(context).colorScheme.primary))]));
  List<Widget> home(){
    final h=HijriCalendar.now();
    final date='${ar(h.hDay)} ${h.longMonthName} ${ar(h.hYear)} هـ';
    final today=DateTime.now().toIso8601String().substring(0,
    10);
    return [ Text('السلام عليكم ورحمة الله',
    style:Theme.of(context).textTheme.titleLarge),
    Text(date,
    style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:20),
    Container(padding:const EdgeInsets.all(24),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff164b3f),
    Color(0xff277865)],
    begin:Alignment.topRight,
    end:Alignment.bottomLeft),
    borderRadius:BorderRadius.circular(30)),
    child:const Row(children:[Icon(Icons.nightlight_round,
    size:48,
    color:Color(0xffebc878)),
    SizedBox(width:20),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
    children:[Text('طمأنينة لقلبك',
    style:TextStyle(color:Colors.white,
    fontWeight:FontWeight.bold,
    fontSize:24)),
    SizedBox(height:8),
    Text('فَاذْكُرُونِي أَذْكُرْكُمْ',
    style:TextStyle(color:Color(0xfff2dfb2),
    fontSize:22))]))])),
    const SizedBox(height:18),
    LayoutBuilder(builder:(c,
    b)=>Wrap(spacing:12,
    runSpacing:12,
    children:[for(final id in ['a3',
    'a4'])SizedBox(width:(b.maxWidth-12)/2,
    child:Card(color:id=='a3'?const Color(0xffb48637):const Color(0xff243751),
    child:InkWell(borderRadius:BorderRadius.circular(24),
    onTap:()=>open(s.groups.firstWhere((g)=>g.id==id)),
    child:Padding(padding:const EdgeInsets.all(18),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,
    children:[Icon(id=='a3'?Icons.wb_sunny_outlined:Icons.dark_mode_outlined,
    color:Colors.white,
    size:30),
    const SizedBox(height:22),
    Text(id=='a3'?'أذكار الصباح':'أذكار المساء',
    style:const TextStyle(color:Colors.white,
    fontWeight:FontWeight.bold,
    fontSize:19)),
    const Text('نورٌ ليومك وسكينة',
    style:TextStyle(color:Colors.white70,
    fontSize:12))])))))])),
    section('رفيقك اليومي'),
    tile('تابع القراءة',
    'صفحة ${ar(s.get<int>('lastPage',1))}',
    Icons.menu_book,
    ()=>quran()),
    khatma(),
    tile('التسبيح',
    'دورات وأهداف وأذكار خاصة',
    Icons.touch_app_outlined,
    counters),
    if(s.groups.any((g)=>g.id=='k1'))groupTile(s.groups.firstWhere((g)=>g.id=='k1')),
    tile('آية اليوم',
    'تأمل وشارك الخير',
    Icons.wb_twilight,
    ()=>safe(()async{
      final refs=[[2,
      152],
      [13,
      28],
      [94,
      5],
      [39,
      53],
      [2,
      286],
      [2,
      186],
      [20,
      114]];
      final ref=refs[DateTime.now().difference(DateTime(2024)).inDays%refs.length];
      final data=await QuranService().fetch('surah/${ref[0]}');
      final text=(data['ayahs'] as List)[ref[1]-1]['text'] as String;
      if(mounted){
        Navigator.push<void>(context,
        MaterialPageRoute(builder:(_)=>CardEditor(text:text,
        title:'آية اليوم • سورة ${s.names[ref[0]-1]}')));
      }
    })),
    section('حصيلة الذكر'),
    Text('اليوم: ${ar(s.get<int>('daily_$today',0))} • الإجمالي: ${ar(s.get<int>('total',0))}'),
    TextButton(onPressed:dedication,
    child:const Text('الإهداء • أوراد المسلم')),
    ];
  } Widget khatma(){
    final k=s.data['khatma'] as Map?;
    if(k==null){
      return tile('ختمة ذكية',
      'حدّد المدة ووزّع وردك اليومي',
      Icons.auto_stories_outlined,
      setupKhatma);
    }final p=k['page'] as int;
    final elapsed=DateTime.now().difference(DateTime.parse(k['start'] as String)).inDays;
    final left=((k['days'] as int)-elapsed).clamp(1,
    365);
    final date=DateTime.now().toIso8601String().substring(0,
    10);
    final base=k['date']==date?k['base'] as int:p;
    final target=(base+dailyPages(base,
    left)).clamp(0,
    604);
    return Card(child:Padding(padding:const EdgeInsets.all(20),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,
    children:[Row(children:[const Expanded(child:Text('ختمتي',
    style:TextStyle(fontSize:20,
    fontWeight:FontWeight.bold))),
    PopupMenuButton<String>(onSelected:(v){
      if(v=='stop'){
        s.set('khatma',
        null);
      }else if(v=='days'){
        setupKhatma();
      }else{
        editPosition();
      }
    },
    itemBuilder:(_)=>['page',
    'days',
    'stop'].map((v)=>PopupMenuItem(value:v,
    child:Text({
      'page':'تعديل الموضع',
      'days':'خطة جديدة',
      'stop':'إغلاق الختمة'
    }[v]!))).toList())]),
    const SizedBox(height:12),
    LinearProgressIndicator(value:p/604),
    const SizedBox(height:12),
    Text(p>=604?'تقبّل الله، أتممت الختمة':'ورد اليوم: صفحة ${ar((base+1).clamp(1,604))} إلى ${ar(target)} • المتبقي $left يوم'),
    Wrap(spacing:8,
    children:[TextButton(onPressed:()=>quran(page:(p+1).clamp(1,
    604)),
    child:const Text('تابع القراءة')),
    if(p<604)FilledButton.tonal(onPressed:(){
      final next=Map<String,
      dynamic>.from(k);
      next['date']=date;
      next['base']=base;
      next['page']=target;
      s.set('khatma',
      next);
    },
    child:const Text('أتممت وردي'))])])));
  } Future<int?> number(String title,
  int initial,
  int min,
  int max)async{
    final t=TextEditingController(text:'$initial');
    final result=await showDialog<int>(context:context,
    builder:(c)=>AlertDialog(title:Text(title),
    content:TextField(controller:t,
    keyboardType:TextInputType.number,
    decoration:InputDecoration(helperText:'$min – $max')),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),
    child:const Text('إلغاء')),
    FilledButton(onPressed:(){
      final n=int.tryParse(t.text);
      if(n!=null&&n>=min&&n<=max){
        Navigator.pop(c,
        n);
      }
    },
    child:const Text('حفظ'))]));
    t.dispose();
    return result;
  } Future<void> setupKhatma()async{
    final days=await number('مدة الختمة بالأيام',
    30,
    1,
    365);
    if(days!=null){
      s.set('khatma',
      {
        'days':days,
        'start':DateTime.now().toIso8601String().substring(0,
        10),
        'page':0,
        'base':0,
        'date':DateTime.now().toIso8601String().substring(0,
        10)
      });
    }
  } Future<void> editPosition()async{
    final k=Map<String,
    dynamic>.from(s.data['khatma'] as Map);
    final p=await number('آخر صفحة أتممتها',
    k['page'] as int,
    0,
    604);
    if(p!=null){
      k['page']=p;
      k['base']=p;
      s.set('khatma',
      k);
    }
  } List<Widget> quranTab(){
    final results=List.generate(114,
    (i)=>i).where((i)=>normalize(s.names[i]).contains(normalize(query)));
    return [ tile('المصحف الشريف',
    '٦٠٤ صفحات • متابعة آخر موضع',
    Icons.menu_book,
    ()=>quran()),
    tile('مكتبة التلاوات',
    'تنزيل السور • ١٠ قرّاء • استماع دون اتصال',
    Icons.headphones,
    ()=>Navigator.push<void>(context,
    MaterialPageRoute(builder:(_)=>DownloadsScreen(store:s)))),
    tile('تنزيل القرآن كاملاً',
    'حفظ النصوص للقراءة دون اتصال',
    Icons.download,
    ()=>safe(()=>downloadQuran())),
    if(downloading)...[const LinearProgressIndicator(),
    Text(downloadStatus),
    TextButton(onPressed:()=>cancelDownload=true,
    child:const Text('إلغاء التنزيل'))],
    tile('الأجزاء الثلاثون',
    'اختر جزءاً للقراءة',
    Icons.book_outlined,
    chooseJuz),
    DropdownButtonFormField<int>(value:s.get<int>('reader',
    0),
    decoration:const InputDecoration(labelText:'القارئ'),
    items:List.generate(readers.length,
    (i)=>DropdownMenuItem(value:i,
    child:Text(readers[i][0]))),
    onChanged:(v){
      if(v!=null){
        s.set('reader',
        v);
      }
    }),
    const SizedBox(height:14),
    TextField(decoration:const InputDecoration(hintText:'ابحث عن سورة أو نص آية',
    prefixIcon:Icon(Icons.search)),
    onChanged:(v)=>setState(()=>query=v)),
    if(query.trim().length>2)TextButton(onPressed:()=>searchVerses(query),
    child:const Text('بحث في نص القرآن')),
    const SizedBox(height:14),
    ...results.map((i)=>tile(s.names[i],
    '${ar((s.content['counts'] as List)[i])} آية',
    Icons.menu_book_outlined,
    ()=>quran(surah:i+1),
    trailing:IconButton(tooltip:'مفضلة',
    onPressed:()=>s.toggle('s${i+1}'),
    icon:Icon(s.favorite('s${i+1}')?Icons.star:Icons.star_border)))),
    ];
  } Future<void> downloadQuran()async{
    if(downloading){
      return;
    }setState((){
      downloading=true;
      cancelDownload=false;
    });
    try{
      for(var n=1;n<=114;n++){
        if(cancelDownload){
          break;
        }await QuranService().fetch('surah/$n');
        if(mounted){
          setState(()=>downloadStatus='حفظ ${ar(n)} / ١١٤ سورة');
        }
      }for(var n=1;n<=604;n++){
        if(cancelDownload){
          break;
        }await QuranService().fetch('page/$n');
        if(mounted){
          setState(()=>downloadStatus='حفظ ${ar(n)} / ٦٠٤ صفحة');
        }
      }message(cancelDownload?'أُوقف التنزيل مع الاحتفاظ بالمحفوظ':'حُفظ القرآن للقراءة دون اتصال');
    }finally{
      if(mounted){
        setState(()=>downloading=false);
      }
    }
  } Future<void> chooseJuz()async{
    const starts=[1,
    22,
    42,
    62,
    82,
    102,
    121,
    142,
    162,
    182,
    201,
    222,
    242,
    262,
    282,
    302,
    322,
    342,
    362,
    382,
    402,
    422,
    442,
    462,
    482,
    502,
    522,
    542,
    562,
    582];
    await showModalBottomSheet<void>(context:context,
    showDragHandle:true,
    builder:(c)=>ListView(children:List.generate(30,
    (i)=>ListTile(title:Text('الجزء ${ar(i+1)}'),
    subtitle:Text('صفحة ${ar(starts[i])}'),
    onTap:(){
      Navigator.pop(c);
      quran(page:starts[i]);
    }))));
  } Future<void> searchVerses(String query)async{
    await safe(()async{
      final matches=<Map<String,
      dynamic>>[];
      final dir=await QuranService().directory;
      int cached=0;
      for(var n=1;n<=114;n++){
        final f=File('${dir.path}/surah_$n.json');
        if(!await f.exists()){
          continue;
        }cached++;
        final j=jsonDecode(await f.readAsString()) as Map;
        for(final a in j['ayahs'] as List){
          if(normalize(a['text'] as String).contains(normalize(query))){
            matches.add({
              's':n,
              'a':a['numberInSurah'],
              'text':a['text']
            });
          }
        }
      } if(cached<114){
        message('جارٍ البحث في القرآن…');
        try{
          final r=await http.get(Uri.https('api.alquran.cloud',
          '/v1/search/$query/all/quran-simple-clean')).timeout(const Duration(seconds:25));
          if(r.statusCode!=200){
            throw Exception('HTTP ${r.statusCode}');
          } final j=jsonDecode(r.body) as Map;
          for(final a in (j['data'] as Map)['matches'] as List){
            final sn=(a['surah'] as Map)['number'];
            if(!matches.any((m)=>m['s']==sn&&m['a']==a['numberInSurah'])){
              matches.add({
                's':sn,
                'a':a['numberInSurah'],
                'text':a['text']
              });
            }
          }
        }catch(e){
          message('تعذر البحث عبر الإنترنت؛ النتائج التالية من النصوص المحفوظة فقط.');
        }
      } if(!mounted){
        return;
      } showModalBottomSheet<void>(context:context,
      showDragHandle:true,
      isScrollControlled:true,
      builder:(c)=>SizedBox(height:MediaQuery.sizeOf(c).height*.75,
      child:matches.isEmpty?const Center(child:Text('لا نتائج. تأكد من الاتصال أو نزّل القرآن للبحث دون اتصال.')):ListView(children:matches.map((a)=>ListTile(title:Text(a['text'] as String),
      subtitle:Text('${s.names[(a['s'] as int)-1]} • ${ar(a['a'])}'),
      onTap:(){
        Navigator.pop(c);
        Navigator.push<void>(context,
        MaterialPageRoute(builder:(_)=>QuranReader(store:s,
        surah:a['s'] as int,
        initialAyah:a['a'] as int)));
      })).toList())));
    });
  } List<Widget> groups(bool awrad){
    final list=s.groups.where((g)=>awrad?!g.id.startsWith('a')||g.id.startsWith('custom'):g.id.startsWith('a')&&!g.id.startsWith('custom')).where((g)=>normalize('${g.title} ${g.subtitle} ${g.items.map((e)=>e.parts is String?e.parts:'').join(' ')}').contains(normalize(query)));
    return [TextField(decoration:const InputDecoration(hintText:'بحث في الأذكار والأوراد',
    prefixIcon:Icon(Icons.search)),
    onChanged:(v)=>setState(()=>query=v)),
    const SizedBox(height:16),
    ...list.map(groupTile),
    OutlinedButton.icon(onPressed:addWird,
    icon:const Icon(Icons.add),
    label:const Text('إنشاء ورد خاص'))];
  } List<Widget> favorites()=>[...s.groups.where((g)=>s.favorite(g.id)).map(groupTile),
  ...List.generate(114,
  (i)=>i).where((i)=>s.favorite('s${i+1}')).map((i)=>tile(s.names[i],
  'سورة مفضلة',
  Icons.star,
  ()=>quran(surah:i+1))),
  section('علاماتي في القرآن'),
  for(var i=0;i<3;i++)if(s.data['bookmark$i'] is Map)tile(['القراءة',
  'الحفظ',
  'المراجعة'][i],
  'سورة ${s.names[(s.data['bookmark$i']['s'] as int)-1]} • الآية ${ar(s.data['bookmark$i']['a'])}',
  Icons.bookmark,
  ()=>quran(page:s.data['bookmark$i']['p'] as int),
  trailing:IconButton(tooltip:'حذف العلامة',
  onPressed:()=>s.set('bookmark$i',
  null),
  icon:const Icon(Icons.close))),
  if((s.data['favorites'] as List? ?? []).isEmpty)const Padding(padding:EdgeInsets.all(24),
  child:Text('أضف مفضلاتك من النجمة بجانب السور والأوراد.'))];
  Future<List<String>?> form(String title,
  {
    String name='',
    String text='',
    String repeat='33',
    bool body=true
  })async{
    final a=TextEditingController(text:name),
    b=TextEditingController(text:text),
    n=TextEditingController(text:repeat);
    final r=await showDialog<List<String>>(context:context,
    builder:(c)=>AlertDialog(title:Text(title),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
    children:[TextField(controller:a,
    decoration:const InputDecoration(labelText:'الاسم / الذكر')),
    if(body)TextField(controller:b,
    maxLines:5,
    decoration:const InputDecoration(labelText:'النص')),
    TextField(controller:n,
    keyboardType:TextInputType.number,
    decoration:const InputDecoration(labelText:'عدد التكرار'))])),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),
    child:const Text('إلغاء')),
    FilledButton(onPressed:(){
      if(a.text.trim().isNotEmpty&&(!body||b.text.trim().isNotEmpty)&&(int.tryParse(n.text)??0)>0){
        Navigator.pop(c,
        [a.text.trim(),
        b.text.trim(),
        n.text]);
      }
    },
    child:const Text('حفظ'))]));
    a.dispose();
    b.dispose();
    n.dispose();
    return r;
  } Future<void> editCustom(Wird g,
  {
    bool remove=false
  })async{
    final customs=List<dynamic>.from(s.data['custom'] as List? ?? []);
    if(remove){
      final yes=await showDialog<bool>(context:context,
      builder:(c)=>AlertDialog(title:const Text('حذف الورد الخاص؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,
      false),
      child:const Text('إلغاء')),
      TextButton(onPressed:()=>Navigator.pop(c,
      true),
      child:const Text('حذف'))]));
      if(yes!=true){
        return;
      }customs.removeWhere((v)=>v[0]==g.id);
    }else{
      final t=TextEditingController(text:g.title);
      final name=await showDialog<String>(context:context,
      builder:(c)=>AlertDialog(title:const Text('اسم الورد'),
      content:TextField(controller:t),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),
      child:const Text('إلغاء')),
      FilledButton(onPressed:(){
        if(t.text.trim().isNotEmpty){
          Navigator.pop(c,
          t.text.trim());
        }
      },
      child:const Text('حفظ'))]));
      t.dispose();
      if(name==null){
        return;
      } final index=customs.indexWhere((v)=>v[0]==g.id);
      customs[index][1]=name;
    } s.data['custom']=customs;
    s.rebuild();
    await s.save();
  } Future<void> addWird()async{
    final r=await form('ورد خاص',
    repeat:'1');
    if(r!=null){
      await s.addWird(r[0],
      r[1],
      int.parse(r[2]));
    }
  } Future<void> counters()async{
    await Navigator.push<void>(context,
    MaterialPageRoute(builder:(c)=>StatefulBuilder(builder:(c,
    refresh){
      final items=List<dynamic>.from(s.data['tasbih'] as List? ?? [['سبحان الله',
      33,
      0],
      ['الحمد لله',
      33,
      0],
      ['ختم سورة الإخلاص',
      100,
      0]]);
      return Scaffold(appBar:AppBar(title:const Text('التسبيح والختم'),
      actions:[IconButton(tooltip:'إضافة تسبيحة',
      onPressed:()async{
        final r=await form('إضافة تسبيحة',
        body:false);
        if(r!=null){
          final goal=await number('الهدف الإجمالي (٠ بدون هدف)',
          0,
          0,
          10000000);
          if(goal!=null){
            items.add([r[0],
            int.parse(r[2]),
            goal]);
            await s.set('tasbih',
            items);
            refresh((){
            });
          }
        }
      },
      icon:const Icon(Icons.add))]),
      body:ListView(padding:const EdgeInsets.all(16),
      children:items.asMap().entries.map((e)=>tile(e.value[0] as String,
      'الدورة ${ar(e.value[1])} • الهدف ${ar(e.value[2])}',
      Icons.touch_app,
      ()=>Navigator.push<void>(context,
      MaterialPageRoute(builder:(_)=>CounterScreen(store:s,
      id:e.value[0] as String,
      name:e.value[0] as String,
      round:e.value[1] as int,
      goal:e.value[2] as int))),
      trailing:PopupMenuButton<String>(onSelected:(v)async{
        if(v=='delete'){
          items.removeAt(e.key);
        }else{
          final r=await form('تعديل التسبيحة',
          name:e.value[0] as String,
          repeat:'${e.value[1]}',
          body:false);
          if(r==null){
            return;
          }items[e.key]=[r[0],
          int.parse(r[2]),
          e.value[2]];
        }await s.set('tasbih',
        items);
        refresh((){
        });
      },
      itemBuilder:(_)=>const [PopupMenuItem(value:'edit',
      child:Text('تعديل')),
      PopupMenuItem(value:'delete',
      child:Text('حذف'))]))).toList()));
    })));
  } Future<void> dedication()async{
    await showDialog<void>(context:context,
    builder:(c)=>AlertDialog(title:const Text('إهداء'),
    content:SingleChildScrollView(child:Column(children:[if(s.get<String>('photo',
    '').isNotEmpty&&File(s.get<String>('photo',
    '')).existsSync())ClipRRect(borderRadius:BorderRadius.circular(24),
    child:Image.file(File(s.get<String>('photo',
    '')),
    height:200))else Image.asset('assets/images/dedication.jpg',
    height:200,
    errorBuilder:(_,
    error,
    stack)=>const Icon(Icons.favorite,
    size:64)),
    const SizedBox(height:20),
    Text(s.get<String>('dedication',
    'إلى روح عمّي الشيخ الحاج إبراهيم أمين منصور الطائي، رحمه الله. اللهم اجعل هذا العمل في ميزان حسناته، وارحمه واغفر له.'),
    textAlign:TextAlign.center,
    style:const TextStyle(height:1.9))])),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),
    child:const Text('رحمه الله'))]));
  } Future<void> backup()async{
    final bytes=utf8.encode(jsonEncode({
      'version':1,
      'data':s.data
    }));
    await FilePicker.platform.saveFile(fileName:'awrad-backup.json',
    type:FileType.custom,
    allowedExtensions:['json'],
    bytes:Uint8List.fromList(bytes));
  } Future<void> restore()async{
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,
    allowedExtensions:['json'],
    withData:true);
    if(result==null){
      return;
    }final bytes=result.files.single.bytes;
    if(bytes==null||bytes.length>10000000){
      throw const FormatException('ملف النسخة غير صالح');
    }final j=jsonDecode(utf8.decode(bytes));
    if(j is! Map||j['version']!=1||j['data'] is! Map){
      throw const FormatException('صيغة النسخة غير مدعومة');
    }final data=Map<String,
    dynamic>.from(j['data'] as Map);
    if(data['custom']!=null){
      for(final g in data['custom'] as List){
        final parsed=Wird.fromJson(List<dynamic>.from(g as List));
        if(parsed.items.any((e)=>e.repeat<1)){
          throw const FormatException('تكرار غير صالح');
        }
      }
    }if(!mounted){
      return;
    }final yes=await showDialog<bool>(context:context,
    builder:(c)=>AlertDialog(title:const Text('استعادة النسخة؟'),
    content:const Text('ستستبدل إعداداتك الحالية. احتفظ بنسخة منها أولاً.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,
    false),
    child:const Text('إلغاء')),
    FilledButton(onPressed:()=>Navigator.pop(c,
    true),
    child:const Text('استعادة'))]));
    if(yes==true){
      data.removeWhere((k,
      v)=>k.startsWith('audioFile_')||k=='photo');
      s.data=data;
      s.rebuild();
      await s.save();
      message('تمت الاستعادة');
    }
  } Future<void> settings()async{
    await Navigator.push<void>(context,
    MaterialPageRoute(builder:(c)=>ListenableBuilder(listenable:s,
    builder:(c,
    _)=>Scaffold(appBar:AppBar(title:const Text('الإعدادات')),
    body:ListView(padding:const EdgeInsets.all(20),
    children:[ section('المظهر والقراءة'),
    SwitchListTile(title:const Text('الوضع الليلي'),
    value:s.get<bool>('dark',
    false),
    onChanged:(v)=>s.set('dark',
    v)),
    Wrap(spacing:8,
    children:List.generate(5,
    (i)=>ChoiceChip(label:Text(['ذهبي',
    'زمردي',
    'أزرق',
    'وردي',
    'بسيط'][i]),
    selected:s.get<int>('skin',
    0)==i,
    onSelected:(_)=>s.set('skin',
    i)))),
    Slider(value:s.get<num>('size',
    26).toDouble().clamp(18,
    60),
    min:18,
    max:60,
    label:'حجم الخط',
    onChanged:(v)=>s.set('size',
    v)),
    SwitchListTile(title:const Text('اهتزاز العدّاد'),
    value:s.get<bool>('vibration',
    true),
    onChanged:(v)=>s.set('vibration',
    v)),
    SwitchListTile(title:const Text('صوت اكتمال الدورة'),
    value:s.get<bool>('sound',
    true),
    onChanged:(v)=>s.set('sound',
    v)),
    SwitchListTile(title:const Text('عرض الإهداء عند البدء'),
    value:s.get<bool>('splash',
    true),
    onChanged:(v){
      s.data['welcomed']=false;
      s.set('splash',
      v);
    }),
    section('التذكيرات اليومية'),
    for(var i=0;i<2;i++)...[ SwitchListTile(title:Text(i==0?'أذكار الصباح':'أذكار المساء'),
    subtitle:const Text('قد يتأخر الإشعار حسب توفير البطارية'),
    value:s.get<bool>('reminder$i',
    false),
    onChanged:(v)=>safe(()async{
      if(!reminderReady){
        await reminders.init();
        reminderReady=true;
      }final t=s.get<String>('time$i',
      i==0?'05:00':'16:30').split(':');
      await reminders.schedule(i,
      i==0?'أذكار الصباح':'أذكار المساء',
      int.parse(t[0]),
      int.parse(t[1]),
      v);
      await s.set('reminder$i',
      v);
    })),
    ListTile(title:const Text('وقت التذكير'),
    trailing:Text(s.get<String>('time$i',
    i==0?'05:00':'16:30')),
    onTap:()=>safe(()async{
      final raw=s.get<String>('time$i',
      i==0?'05:00':'16:30').split(':');
      final t=await showTimePicker(context:c,
      initialTime:TimeOfDay(hour:int.parse(raw[0]),
      minute:int.parse(raw[1])));
      if(t==null){
        return;
      }await s.set('time$i',
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
      if(s.get<bool>('reminder$i',
      false)){
        await reminders.schedule(i,
        i==0?'أذكار الصباح':'أذكار المساء',
        t.hour,
        t.minute,
        true);
      }
    })),
    ],
    section('الذكر العائم'),
    SwitchListTile(title:const Text('إظهار الذكر فوق التطبيقات'),
    subtitle:const Text('يتطلب إذن الظهور فوق التطبيقات في Android'),
    value:s.get<bool>('overlay',
    false),
    onChanged:(v)=>safe(()async{
      final ok=await native.invokeMethod<bool>('overlay',
      {
        'enabled':v,
        'seconds':s.get<int>('floatSeconds',
        10),
        'texts':s.get<List>('floatList',
        ['سبحان الله',
        'الحمد لله',
        'الله أكبر'])
      });
      if(ok==true){
        await s.set('overlay',
        v);
      }else{
        message('امنح إذن الظهور فوق التطبيقات، ثم فعّل الخيار مجدداً');
      }
    })),
    tile('قائمة الأذكار العائمة',
    'تخصيص الأذكار والفاصل الزمني',
    Icons.edit_outlined,
    editFloating),
    section('الإهداء'),
    tile('تعديل نص الإهداء',
    '',
    Icons.edit,
    ()async{
      final t=TextEditingController(text:s.get<String>('dedication',
      ''));
      final value=await showDialog<String>(context:c,
      builder:(d)=>AlertDialog(title:const Text('نص الإهداء'),
      content:TextField(controller:t,
      maxLines:5),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,
      t.text.trim()),
      child:const Text('حفظ'))]));
      t.dispose();
      if(value!=null){
        s.set('dedication',
        value);
      }
    }),
    tile('تغيير صورة الإهداء',
    'صورة من جهازك',
    Icons.photo,
    ()=>safe(()async{
      final file=await ImagePicker().pickImage(source:ImageSource.gallery,
      maxWidth:1000,
      maxHeight:1000);
      if(file!=null){
        final path='${(await getApplicationSupportDirectory()).path}/dedication.jpg';
        await File(file.path).copy(path);
        await s.set('photo',
        path);
      }
    })),
    section('البيانات'),
    tile('تصدير نسخة احتياطية',
    'الإعدادات والمفضلة والأوراد والتقدم',
    Icons.upload_file,
    ()=>safe(backup)),
    tile('استيراد نسخة احتياطية',
    '',
    Icons.restore_page_outlined,
    ()=>safe(restore)),
    tile('إدارة الملفات المحفوظة',
    'القرآن والتسجيلات الصوتية',
    Icons.folder_outlined,
    cacheManager),
    const Padding(padding:EdgeInsets.all(20),
    child:Text('أوراد المسلم ١.٠\nتطبيق Flutter أصلي • يعمل المحتوى المضمّن دون اتصال، ويتطلب تنزيل القرآن والصوت اتصالاً أولياً.',
    textAlign:TextAlign.center)),
    ])))));
  } Future<void> editFloating()async{
    final t=TextEditingController(text:s.get<List>('floatList',
    ['سبحان الله',
    'الحمد لله',
    'الله أكبر']).join('\n'));
    final n=TextEditingController(text:'${s.get<int>('floatSeconds',10)}');
    final ok=await showDialog<bool>(context:context,
    builder:(c)=>AlertDialog(title:const Text('أذكار عائمة'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
    children:[TextField(controller:t,
    maxLines:6,
    decoration:const InputDecoration(labelText:'ذكر واحد في كل سطر')),
    TextField(controller:n,
    keyboardType:TextInputType.number,
    decoration:const InputDecoration(labelText:'الفاصل بالثواني (٥ فأكثر)'))])),
    actions:[FilledButton(onPressed:(){
      if(t.text.trim().isNotEmpty&&(int.tryParse(n.text)??0)>=5){
        Navigator.pop(c,
        true);
      }
    },
    child:const Text('حفظ'))]));
    if(ok==true){
      await s.set('floatList',
      t.text.split('\n').where((v)=>v.trim().isNotEmpty).toList());
      await s.set('floatSeconds',
      int.parse(n.text));
      if(s.get<bool>('overlay',
      false)){
        await safe(()=>native.invokeMethod<void>('overlay',
        {
          'enabled':true,
          'seconds':int.parse(n.text),
          'texts':s.data['floatList']
        }));
      }
    }t.dispose();
    n.dispose();
  } Future<void> cacheManager()async{
    await safe(()async{
      final dir=await QuranService().directory;
      final files=await dir.list().where((f)=>f is File).cast<File>().toList();
      if(!mounted){
        return;
      }await Navigator.push<void>(context,
      MaterialPageRoute(builder:(c)=>StatefulBuilder(builder:(c,
      refresh)=>Scaffold(appBar:AppBar(title:const Text('الملفات المحفوظة')),
      body:ListView(children:files.map((f)=>ListTile(title:Text(f.uri.pathSegments.last),
      subtitle:Text('${(f.lengthSync()/1024).round()} KB'),
      trailing:IconButton(tooltip:'حذف',
      icon:const Icon(Icons.delete_outline),
      onPressed:()async{
        await f.delete();
        files.remove(f);
        refresh((){
        });
      }))).toList())))));
    });
  } @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,
  children:[Text(tab==0?'أوراد المسلم':titles[tab],
  style:const TextStyle(fontWeight:FontWeight.bold)),
  Text('سكينةٌ ترافق يومك',
  style:Theme.of(context).textTheme.bodySmall)]),
  actions:[IconButton(tooltip:'الوضع الليلي',
  onPressed:()=>s.set('dark',
  !s.get<bool>('dark',
  false)),
  icon:Icon(s.get<bool>('dark',
  false)?Icons.light_mode_outlined:Icons.dark_mode_outlined)),
  IconButton(tooltip:'الإعدادات',
  onPressed:settings,
  icon:const Icon(Icons.tune))]),
  body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:850),
  child:ListView(key:ValueKey(tab),
  padding:const EdgeInsets.all(20),
  children:switch(tab){
    0=>home(),
    1=>quranTab(),
    2=>groups(false),
    3=>groups(true),
    _=>favorites()
  }))),
  bottomNavigationBar:NavigationBar(selectedIndex:tab,
  onDestinationSelected:(v)=>setState((){
    tab=v;
    query='';
  }),
  destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),
  selectedIcon:Icon(Icons.home),
  label:'الرئيسية'),
  NavigationDestination(icon:Icon(Icons.menu_book_outlined),
  label:'القرآن'),
  NavigationDestination(icon:Icon(Icons.auto_awesome_outlined),
  label:'أذكاري'),
  NavigationDestination(icon:Icon(Icons.library_books_outlined),
  label:'أورادي'),
  NavigationDestination(icon:Icon(Icons.star_outline),
  label:'المفضلة')]));
}
