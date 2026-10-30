import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/content.dart';
import '../services/store.dart';
import '../services/quran.dart';
import 'audio_panel.dart';
import 'card_editor.dart';
class WirdReader extends StatefulWidget {
  const WirdReader({
    super.key,
    required this.wird,
    required this.store
  });
  final Wird wird;
  final Store store;
  @override State<WirdReader> createState()=>_WirdReaderState();
} class _WirdReaderState extends State<WirdReader> {
  final scroll=ScrollController();
  final futures=<int,
  Future<String>>{
  };
  Timer? timer;
  late List<int> remaining;
  late double size;
  int shape=0,
  color=0;
  String variant='';
  static const shapes=['الكلاسيكي',
  'العصري',
  'الناعم',
  'الجانبي',
  'البيئي',
  'الإسلامي',
  'المعلّق'];
  Store get store=>widget.store;
  String get progressKey=>'progress_${widget.wird.id}';
  @override void initState(){
    super.initState();
    size=store.get<num>('size',
    26).toDouble();
    shape=store.get<int>('shape',
    0);
    color=store.get<int>('cardColor',
    0);
    remaining=List<int>.from(store.data[progressKey] as List? ?? widget.wird.items.map((e)=>e.repeat).toList());
    if(remaining.length!=widget.wird.items.length){
      remaining=widget.wird.items.map((e)=>e.repeat).toList();
    }WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(scroll.hasClients){
        scroll.jumpTo(store.get<num>('scroll_${widget.wird.id}',
        0).toDouble().clamp(0,
        scroll.position.maxScrollExtent));
      }
    });
  } @override void dispose(){
    timer?.cancel();
    store.set('scroll_${widget.wird.id}',
    scroll.hasClients?scroll.offset:0);
    scroll.dispose();
    WakelockPlus.disable();
    super.dispose();
  } Future<String> text(int i)=>futures.putIfAbsent(i,
  ()=>QuranService().resolve(widget.wird.items[i].parts));
  void count(int i){
    if(remaining[i]<=0){
      return;
    }if(store.get<bool>('vibration',
    true)){
      HapticFeedback.lightImpact();
    }setState(()=>remaining[i]--);
    store.data[progressKey]=remaining;
    store.data['total']=store.get<int>('total',
    0)+1;
    final today=DateTime.now().toIso8601String().substring(0,
    10);
    store.data['daily_$today']=store.get<int>('daily_$today',
    0)+1;
    store.save();
    if(remaining.every((v)=>v==0)){
      showDialog<void>(context:context,
      builder:(c)=>AlertDialog(title:const Text('تقبّل الله منك'),
      content:Text('أتممت ${widget.wird.title}\nإجمالي أذكارك: ${ar(store.get<int>('total',0))}'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),
      child:const Text('الحمد لله'))]));
    }
  } Future<void> options(int i) async {
    try {
      final t=await text(i);
      if(!mounted){
        return;
      } showModalBottomSheet<void>(context:context,
      showDragHandle:true,
      builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,
      children:[ if(editable(i))ListTile(leading:const Icon(Icons.edit_outlined),
      title:const Text('تعديل الذكر الخاص'),
      onTap:(){
        Navigator.pop(c);
        editItem(i);
      }),
      if(editable(i))ListTile(leading:const Icon(Icons.delete_outline),
      title:const Text('حذف الذكر الخاص'),
      onTap:(){
        Navigator.pop(c);
        editItem(i,
        remove:true);
      }),
      ListTile(leading:const Icon(Icons.copy),
      title:const Text('نسخ'),
      onTap:(){
        Clipboard.setData(ClipboardData(text:t));
        Navigator.pop(c);
      }),
      ListTile(leading:const Icon(Icons.share),
      title:const Text('مشاركة النص'),
      onTap:(){
        Navigator.pop(c);
        Share.share('$t\n${widget.wird.title} • أوراد المسلم');
      }),
      ListTile(leading:const Icon(Icons.palette_outlined),
      title:const Text('بطاقة / صورة / طباعة'),
      onTap:(){
        Navigator.pop(c);
        Navigator.push<void>(context,
        MaterialPageRoute(builder:(_)=>CardEditor(text:t,
        title:widget.wird.title)));
      }),
      ListTile(leading:const Icon(Icons.refresh),
      title:const Text('إعادة عد هذا الذكر'),
      onTap:(){
        setState(()=>remaining[i]=widget.wird.items[i].repeat);
        store.set(progressKey,
        remaining);
        Navigator.pop(c);
      }),
      ])));
    }catch(e){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل النص: $e')));
      }
    }
  } int get extraCount=>((store.data['extras'] as Map? ?? {
  })[widget.wird.id] as List? ?? []).length;
  bool editable(int i)=>widget.wird.id.startsWith('custom')||i>=widget.wird.items.length-extraCount;
  Future<void> editItem(int i,
  {
    bool remove=false
  })async{
    final current=widget.wird.items[i];
    Dhikr? next;
    if(remove){
      final yes=await showDialog<bool>(context:context,
      builder:(c)=>AlertDialog(title:const Text('حذف الذكر الخاص؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,
      false),
      child:const Text('إلغاء')),
      TextButton(onPressed:()=>Navigator.pop(c,
      true),
      child:const Text('حذف'))]));
      if(yes!=true){
        return;
      }
    }else{
      final t=TextEditingController(text:current.parts as String),
      n=TextEditingController(text:'${current.repeat}');
      final ok=await showDialog<bool>(context:context,
      builder:(c)=>AlertDialog(title:const Text('تعديل الذكر'),
      content:Column(mainAxisSize:MainAxisSize.min,
      children:[TextField(controller:t,
      maxLines:4),
      TextField(controller:n,
      keyboardType:TextInputType.number)]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),
      child:const Text('إلغاء')),
      FilledButton(onPressed:(){
        if(t.text.trim().isNotEmpty&&(int.tryParse(n.text)??0)>0){
          Navigator.pop(c,
          true);
        }
      },
      child:const Text('حفظ'))]));
      if(ok==true){
        next=Dhikr(t.text.trim(),
        int.parse(n.text),
        current.source);
      }t.dispose();
      n.dispose();
      if(next==null){
        return;
      }
    } final baseCount=widget.wird.items.length-extraCount;
    if(i>=baseCount){
      final extras=Map<String,
      dynamic>.from(store.data['extras'] as Map? ?? {
      });
      final list=List<dynamic>.from(extras[widget.wird.id] as List? ?? []);
      if(remove){
        list.removeAt(i-baseCount);
      }else{
        list[i-baseCount]=next!.toJson();
      }extras[widget.wird.id]=list;
      store.data['extras']=extras;
    }else{
      final customs=List<dynamic>.from(store.data['custom'] as List? ?? []);
      final index=customs.indexWhere((g)=>g[0]==widget.wird.id);
      final g=List<dynamic>.from(customs[index] as List);
      final list=List<dynamic>.from(g[3] as List);
      if(remove){
        list.removeAt(i);
      }else{
        list[i]=next!.toJson();
      }g[3]=list;
      customs[index]=g;
      store.data['custom']=customs;
    } futures.clear();
    if(remove){
      widget.wird.items.removeAt(i);
      remaining.removeAt(i);
    }else{
      widget.wird.items[i]=next!;
      remaining[i]=next.repeat;
    } await store.set(progressKey,
    remaining);
    if(mounted){
      setState((){
      });
    }
  } Future<void> add() async {
    final t=TextEditingController(),
    n=TextEditingController(text:'1');
    final ok=await showDialog<bool>(context:context,
    builder:(c)=>AlertDialog(title:const Text('إضافة ذكر خاص'),
    content:Column(mainAxisSize:MainAxisSize.min,
    children:[TextField(controller:t,
    maxLines:4,
    decoration:const InputDecoration(labelText:'النص')),
    TextField(controller:n,
    keyboardType:TextInputType.number,
    decoration:const InputDecoration(labelText:'التكرار'))]),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,
    false),
    child:const Text('إلغاء')),
    FilledButton(onPressed:(){
      if(t.text.trim().isNotEmpty&&(int.tryParse(n.text)??0)>0){
        Navigator.pop(c,
        true);
      }
    },
    child:const Text('إضافة'))]));
    if(ok==true){
      final d=Dhikr(t.text.trim(),
      int.parse(n.text),
      'إضافة شخصية');
      final extras=Map<String,
      dynamic>.from(store.data['extras'] as Map? ?? {
      });
      extras[widget.wird.id]=[...(extras[widget.wird.id] as List? ?? []),
      d.toJson()];
      store.data['extras']=extras;
      widget.wird.items.add(d);
      remaining.add(d.repeat);
      await store.set(progressKey,
      remaining);
      if(mounted){
        setState((){
        });
      }
    } t.dispose();
    n.dispose();
  } @override Widget build(BuildContext context){
    final scheme=Theme.of(context).colorScheme;
    final bg=[scheme.surfaceContainerLow,
    const Color(0xfff8efd9),
    const Color(0xff143e33),
    const Color(0xff1b2740),
    const Color(0xfff7dfe7)][color];
    final ink=color==2||color==3?const Color(0xfffaf1dc):color==0?scheme.onSurface:const Color(0xff33291c);
    return Scaffold(appBar:AppBar(title:Text(widget.wird.title),
    actions:[IconButton(tooltip:'إضافة ذكر',
    onPressed:add,
    icon:const Icon(Icons.add)),
    IconButton(tooltip:'إعادة الورد',
    onPressed:()async{
      final ok=await showDialog<bool>(context:context,
      builder:(c)=>AlertDialog(title:const Text('إعادة عد الورد؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,
      false),
      child:const Text('إلغاء')),
      TextButton(onPressed:()=>Navigator.pop(c,
      true),
      child:const Text('إعادة'))]));
      if(ok==true){
        setState(()=>remaining=widget.wird.items.map((e)=>e.repeat).toList());
        store.set(progressKey,
        remaining);
      }
    },
    icon:const Icon(Icons.restart_alt))]),
    body:Column(children:[ SingleChildScrollView(scrollDirection:Axis.horizontal,
    padding:const EdgeInsets.symmetric(horizontal:12),
    child:Row(children:[IconButton(tooltip:'تصغير',
    onPressed:(){
      setState(()=>size=(size-2).clamp(18,
      60));
      store.set('size',
      size);
    },
    icon:const Icon(Icons.text_decrease)),
    IconButton(tooltip:'تكبير',
    onPressed:(){
      setState(()=>size=(size+2).clamp(18,
      60));
      store.set('size',
      size);
    },
    icon:const Icon(Icons.text_increase)),
    TextButton.icon(onPressed:(){
      setState(()=>color=(color+1)%5);
      store.set('cardColor',
      color);
    },
    icon:const Icon(Icons.color_lens_outlined),
    label:const Text('اللون')),
    PopupMenuButton<int>(initialValue:shape,
    onSelected:(v){
      setState(()=>shape=v);
      store.set('shape',
      v);
    },
    itemBuilder:(_)=>List.generate(7,
    (i)=>PopupMenuItem(value:i,
    child:Text(shapes[i]))),
    child:Padding(padding:const EdgeInsets.all(12),
    child:Text(shapes[shape]))),
    IconButton(tooltip:'تمرير تلقائي',
    onPressed:(){
      if(timer!=null){
        timer?.cancel();
        timer=null;
      }else{
        timer=Timer.periodic(const Duration(milliseconds:100),
        (_){
          if(scroll.hasClients){
            scroll.jumpTo((scroll.offset+1).clamp(0,
            scroll.position.maxScrollExtent));
          }
        });
      }setState((){
      });
    },
    icon:Icon(timer==null?Icons.play_arrow:Icons.pause))])),
    Expanded(child:ListView.builder(controller:scroll,
    padding:const EdgeInsets.all(16),
    itemCount:widget.wird.items.length+1,
    itemBuilder:(c,
    index){
      if(index==0){
        final id=variant.isEmpty?widget.wird.id:variant;
        return Column(children:[if(widget.wird.id=='k1')DropdownButtonFormField<String>(value:id,
        decoration:const InputDecoration(labelText:'صوت ختم الإخلاص'),
        items:const [DropdownMenuItem(value:'k1',
        child:Text('محمد الحادي')),
        DropdownMenuItem(value:'k1b',
        child:Text('عامر الديري')),
        DropdownMenuItem(value:'k1c',
        child:Text('عمار النعيمي'))],
        onChanged:(v){
          if(v!=null){
            setState(()=>variant=v);
          }
        }),
        AudioPanel(key:ValueKey(id),
        id:id,
        url:store.audio[id] as String? ?? '',
        store:store)]);
      } final i=index-1,
      item=widget.wird.items[i];
      return AnimatedOpacity(opacity:remaining[i]==0?.45:1,
      duration:const Duration(milliseconds:200),
      child:Container(margin:const EdgeInsets.only(top:18),
      decoration:BoxDecoration(color:bg,
      borderRadius:shape==5?const BorderRadius.vertical(top:Radius.circular(90),
      bottom:Radius.circular(20)):shape==4?const BorderRadius.only(topRight:Radius.circular(60),
      bottomLeft:Radius.circular(60),
      topLeft:Radius.circular(12),
      bottomRight:Radius.circular(12)):BorderRadius.circular(shape==1?16:32),
      border:Border.all(color:ink.withValues(alpha:.16),
      width:shape==0?5:1),
      boxShadow:shape==2?[BoxShadow(color:Colors.black.withValues(alpha:.09),
      blurRadius:14,
      offset:const Offset(4,
      5))]:null),
      child:InkWell(borderRadius:BorderRadius.circular(32),
      onTap:()=>count(i),
      onLongPress:()=>options(i),
      child:Padding(padding:const EdgeInsets.all(22),
      child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
      children:[Text('${ar(i+1)} / ${ar(widget.wird.items.length)}',
      style:TextStyle(color:ink)),
      IconButton(tooltip:'خيارات الذكر',
      onPressed:()=>options(i),
      icon:Icon(Icons.more_horiz,
      color:ink))]),
      FutureBuilder<String>(future:text(i),
      builder:(c,
      s){
        if(s.hasError){
          return Column(children:[Text('تعذر تحميل الآيات. النصوص العادية متاحة دون اتصال.',
          style:TextStyle(color:ink)),
          TextButton(onPressed:(){
            futures.remove(i);
            setState((){
            });
          },
          child:const Text('إعادة المحاولة'))]);
        }if(!s.hasData){
          return const Padding(padding:EdgeInsets.all(24),
          child:CircularProgressIndicator());
        }return Text(s.data!,
        textAlign:shape==3?TextAlign.start:TextAlign.center,
        style:TextStyle(fontSize:size,
        height:2,
        color:ink));
      }),
      const SizedBox(height:20),
      Semantics(button:true,
      label:'المتبقي ${remaining[i]}',
      child:Container(padding:const EdgeInsets.all(18),
      decoration:BoxDecoration(shape:shape==1?BoxShape.rectangle:BoxShape.circle,
      color:ink.withValues(alpha:.08)),
      child:Text(remaining[i]==0?'✓':ar(remaining[i]),
      style:TextStyle(fontSize:30,
      fontWeight:FontWeight.bold,
      color:ink)))),
      const SizedBox(height:12),
      LinearProgressIndicator(value:1-remaining[i]/item.repeat,
      color:ink,
      backgroundColor:ink.withValues(alpha:.1)),
      if(item.source.isNotEmpty)ExpansionTile(title:Text('المصدر والمعلومات',
      style:TextStyle(color:ink,
      fontSize:13)),
      children:[Padding(padding:const EdgeInsets.all(12),
      child:Text(item.source,
      style:TextStyle(color:ink,
      height:1.8)))]),
      ])))));
    })),
    ]));
  }
}
