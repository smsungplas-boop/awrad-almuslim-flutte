import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/quran.dart';
import '../services/store.dart';
class AudioPanel extends StatefulWidget {
  const AudioPanel({
    super.key,
    required this.id,
    required this.url,
    required this.store,
    this.autoplay=false,
    this.onNext,
    this.onPrevious
  });
  final String id,
  url;
  final Store store;
  final bool autoplay;
  final VoidCallback? onNext,
  onPrevious;
  @override State<AudioPanel> createState()=>_AudioPanelState();
} class _AudioPanelState extends State<AudioPanel> {
  final player=AudioPlayer();
  final subscriptions=<StreamSubscription<dynamic>>[];
  Duration position=Duration.zero,
  duration=Duration.zero;
  Timer? sleep;
  bool playing=false,
  busy=false,
  loaded=false,
  loop=false;
  double speed=1;
  String? error;
  @override void initState(){
    super.initState();
    subscriptions.add(player.onPositionChanged.listen((v){
      if(mounted) {
        setState(()=>position=v);
      }
    }));
    subscriptions.add(player.onDurationChanged.listen((v){
      if(mounted) {
        setState(()=>duration=v);
      }
    }));
    subscriptions.add(player.onPlayerStateChanged.listen((v){
      if(mounted) {
        setState(()=>playing=v==PlayerState.playing);
      }
    }));
    subscriptions.add(player.onPlayerComplete.listen((_){
      widget.store.set('audioPos_${widget.id}',
      0);
      widget.onNext?.call();
    }));
    if(widget.autoplay){
      WidgetsBinding.instance.addPostFrameCallback((_){
        if(mounted){
          act(start);
        }
      });
    }
  } @override void dispose(){
    sleep?.cancel();
    for(final s in subscriptions){
      s.cancel();
    } widget.store.set('audioPos_${widget.id}',
    position.inSeconds);
    player.dispose();
    super.dispose();
  } Future<void> act(Future<void> Function() fn) async {
    setState((){
      busy=true;
      error=null;
    });
    try{
      await fn();
    }catch(e){
      if(mounted) {
        setState(()=>error='تعذر تشغيل أو تنزيل الصوت: $e');
      }
    }finally{
      if(mounted) {
        setState(()=>busy=false);
      }
    }
  } Future<void> start() async {
    if(playing) {
      await player.pause();
      return;
    } if(!loaded) {
      var local=widget.store.get<String>('audioFile_${widget.id}',
      '');
      final cached=File('${(await QuranService().directory).path}/${widget.id}.mp3');
      if(local.isEmpty && await cached.exists()){
        local=cached.path;
      } if(local.isNotEmpty&&await File(local).exists()) {
        await player.setSource(DeviceFileSource(local));
      } else if(widget.url.isNotEmpty) {
        await player.setSource(UrlSource(widget.url));
      } else {
        throw Exception('أضف ملفاً صوتياً من جهازك');
      } loaded=true;
      await player.seek(Duration(seconds:widget.store.get<int>('audioPos_${widget.id}',
      0)));
    } await player.resume();
  } Future<void> download() async {
    if(widget.url.isEmpty) {
      throw Exception('لا يوجد رابط لهذا الورد');
    } final path=await QuranService().downloadAudio(widget.id,
    widget.url);
    await widget.store.set('audioFile_${widget.id}',
    path);
  } String time(Duration d)=>'${d.inMinutes}:${(d.inSeconds%60).toString().padLeft(2,'0')}';
  @override Widget build(BuildContext context) {
    final marks=List<dynamic>.from(widget.store.data['audioMarks_${widget.id}'] as List? ?? []);
    return Card(child:Padding(padding:const EdgeInsets.all(12),
    child:Column(children:[ Row(children:[IconButton(tooltip:playing?'إيقاف مؤقت':'تشغيل',
    onPressed:busy?null:()=>act(start),
    icon:Icon(playing?Icons.pause_circle:Icons.play_circle,
    size:38)),
    Expanded(child:Column(children:[const Text('الاستماع إلى الورد'),
    Text('${time(position)} / ${time(duration)}')])),
    IconButton(tooltip:'حفظ للاستماع دون اتصال',
    onPressed:busy?null:()=>act(download),
    icon:const Icon(Icons.download)),
    IconButton(tooltip:'ملف من الجهاز',
    onPressed:()=>act(()async{
      final r=await FilePicker.platform.pickFiles(type:FileType.audio);
      if(r?.files.single.path!=null){
        await player.stop();
        final path=r!.files.single.path!;
        final dest=File('${(await QuranService().directory).path}/local_${widget.id}.${r.files.single.extension??'mp3'}');
        await File(path).copy(dest.path);
        await widget.store.set('audioFile_${widget.id}',
        dest.path);
        loaded=false;
      }
    }),
    icon:const Icon(Icons.audio_file))]),
    if(busy)const LinearProgressIndicator(),
    Slider(value:position.inMilliseconds.toDouble().clamp(0,
    duration.inMilliseconds.toDouble().clamp(1,
    double.infinity)),
    max:duration.inMilliseconds.toDouble().clamp(1,
    double.infinity),
    onChanged:(v)=>player.seek(Duration(milliseconds:v.round()))),
    Wrap(crossAxisAlignment:WrapCrossAlignment.center,
    children:[if(widget.onPrevious!=null)IconButton(tooltip:'الآية السابقة',
    onPressed:widget.onPrevious,
    icon:const Icon(Icons.skip_previous)),
    if(widget.onNext!=null)IconButton(tooltip:'الآية التالية',
    onPressed:widget.onNext,
    icon:const Icon(Icons.skip_next)),
    IconButton(tooltip:'رجوع ١٥ ثانية',
    onPressed:()=>player.seek(Duration(seconds:(position.inSeconds-15).clamp(0,
    duration.inSeconds))),
    icon:const Icon(Icons.replay_10)),
    TextButton(onPressed:(){
      speed=speed>=2?.75:speed+.25;
      player.setPlaybackRate(speed);
      setState((){
      });
    },
    child:Text('×$speed')),
    IconButton(tooltip:'تكرار',
    onPressed:(){
      setState(()=>loop=!loop);
      player.setReleaseMode(loop?ReleaseMode.loop:ReleaseMode.stop);
    },
    icon:Icon(Icons.repeat,
    color:loop?Theme.of(context).colorScheme.primary:null)),
    PopupMenuButton<int>(tooltip:'مؤقت النوم',
    icon:const Icon(Icons.bedtime_outlined),
    itemBuilder:(_)=>[0,
    15,
    30,
    60].map((m)=>PopupMenuItem(value:m,
    child:Text(m==0?'إلغاء المؤقت':'$m دقيقة'))).toList(),
    onSelected:(m){
      sleep?.cancel();
      if(m>0){
        sleep=Timer(Duration(minutes:m),
        ()=>player.pause());
      }
    }),
    IconButton(tooltip:'علامة صوتية',
    onPressed:()async{
      marks.add(position.inSeconds);
      await widget.store.set('audioMarks_${widget.id}',
      marks);
      if(mounted){
        setState((){
        });
      }
    },
    icon:const Icon(Icons.bookmark_add_outlined))]),
    Wrap(children:marks.asMap().entries.map((m)=>InputChip(label:Text(time(Duration(seconds:m.value as int))),
    onPressed:()=>player.seek(Duration(seconds:m.value as int)),
    onDeleted:(){
      marks.removeAt(m.key);
      widget.store.set('audioMarks_${widget.id}',
      marks);
      setState((){
      });
    })).toList()),
    if(error!=null)Text(error!,
    style:TextStyle(color:Theme.of(context).colorScheme.error)),
    ])));
  }
}
