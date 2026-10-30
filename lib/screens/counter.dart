import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/content.dart';
import '../services/store.dart';
class CounterScreen extends StatefulWidget {
  const CounterScreen({
    super.key,
    required this.store,
    required this.id,
    required this.name,
    required this.round,
    required this.goal
  });
  final Store store;
  final String id,
  name;
  final int round,
  goal;
  @override State<CounterScreen> createState()=>_CounterScreenState();
} class _CounterScreenState extends State<CounterScreen> {
  late int count;
  @override void initState(){
    super.initState();
    count=widget.store.get<int>('counter_${widget.id}',
    0);
  } void change(int n){
    setState(()=>count=(count+n).clamp(0,
    1<<31));
    widget.store.set('counter_${widget.id}',
    count);
    if(n>0&&widget.store.get<bool>('sound',true)){SystemSound.play(SystemSoundType.click);}
    if(n>0&&widget.store.get<bool>('vibration',
    true)){
      HapticFeedback.lightImpact();
    }if(n>0&&count%widget.round==0){
      if(widget.store.get<bool>('sound',
      true)){
        SystemSound.play(SystemSoundType.alert);
      }ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تقبّل الله • اكتملت دورة')));
    }
  } @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.name),
  actions:[IconButton(tooltip:'إعادة الضبط',
  onPressed:()async{
    final yes=await showDialog<bool>(context:context,
    builder:(c)=>AlertDialog(title:const Text('تصفير العدّاد؟'),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,
    false),
    child:const Text('إلغاء')),
    TextButton(onPressed:()=>Navigator.pop(c,
    true),
    child:const Text('تصفير'))]));
    if(yes==true){
      change(-count);
    }
  },
  icon:const Icon(Icons.refresh))]),
  body:LayoutBuilder(builder:(c,
  box)=>SingleChildScrollView(child:ConstrainedBox(constraints:BoxConstraints(minHeight:box.maxHeight),
  child:Padding(padding:const EdgeInsets.all(24),
  child:Column(mainAxisAlignment:MainAxisAlignment.center,
  children:[Text(widget.name,
  textAlign:TextAlign.center,
  style:Theme.of(context).textTheme.headlineSmall),
  const SizedBox(height:24),
  Wrap(spacing:32,
  children:[Text('الدورات: ${ar(count~/widget.round)}'),
  Text('الإجمالي: ${ar(count)}')]),
  const SizedBox(height:36),
  Semantics(button:true,
  label:'إضافة تسبيحة',
  child:GestureDetector(onTap:()=>change(1),
  child:SizedBox(width:260,
  height:260,
  child:Stack(alignment:Alignment.center,
  children:[SizedBox.expand(child:CircularProgressIndicator(value:(count%widget.round)/widget.round,
  strokeWidth:10,
  backgroundColor:Theme.of(context).colorScheme.primaryContainer)),
  Container(width:220,
  height:220,
  decoration:BoxDecoration(shape:BoxShape.circle,
  color:Theme.of(context).colorScheme.primaryContainer),
  child:Column(mainAxisAlignment:MainAxisAlignment.center,
  children:[Text(ar(count%widget.round),
  style:Theme.of(context).textTheme.displayLarge),
  Text('من ${ar(widget.round)}')]))])))),
  const SizedBox(height:30),
  if(widget.goal>0)...[LinearProgressIndicator(value:(count/widget.goal).clamp(0,
  1)),
  Text('الهدف: ${ar(widget.goal)} • ${ar((count/widget.goal*100).clamp(0,100).round())}٪')],
  TextButton.icon(onPressed:count>0?()=>change(-1):null,
  icon:const Icon(Icons.undo),
  label:const Text('تراجع')),
  ]))))));
}
