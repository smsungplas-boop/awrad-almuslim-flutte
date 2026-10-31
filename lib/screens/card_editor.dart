import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
class CardEditor extends StatefulWidget {
  const CardEditor({
    super.key,
    required this.text,
    required this.title
  });
  final String text,
  title;
  @override State<CardEditor> createState()=>_CardEditorState();
} class _CardEditorState extends State<CardEditor> {
  final key=GlobalKey();
  double size=26,
  ratio=1;
  int palette=0,
  pattern=0;
  bool footer=true,
  busy=false;
  Uint8List? background;
  static const colors=[Color(0xfffaf1de),
  Color(0xff123c32),
  Color(0xff18243e),
  Color(0xfffae5eb),
  Color(0xff161616)];
  Color get ink=>palette==0||palette==3?const Color(0xff392f22):const Color(0xfff5e7c6);
  Future<void> run(Future<void> Function() action) async {
    setState(()=>busy=true);
    try {
      await action();
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذرت العملية: $e')));
      }
    } finally {
      if(mounted) {
        setState(()=>busy=false);
      }
    }
  } Future<Uint8List> capture() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image=await boundary.toImage(pixelRatio:3);
    final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  } Future<void> save() async {
    final bytes=await capture();
    await FilePicker.platform.saveFile(dialogTitle:'حفظ البطاقة',
    fileName:'awrad-card.png',
    type:FileType.custom,
    allowedExtensions:['png'],
    bytes:bytes);
  } Future<void> share() async {
    final f=File('${(await getTemporaryDirectory()).path}/awrad-card.png');
    await f.writeAsBytes(await capture());
    await Share.shareXFiles([XFile(f.path)],
    text:widget.title);
  } Future<void> printCard() async {
    final bytes=await capture();
    final doc=pw.Document();
    doc.addPage(pw.Page(pageFormat:PdfPageFormat.a4,
    build:(_)=>pw.Center(child:pw.Image(pw.MemoryImage(bytes),
    fit:pw.BoxFit.contain))));
    await Printing.layoutPdf(onLayout:(_)=>doc.save());
  } Future<void> pick() async {
    final file=await ImagePicker().pickImage(source:ImageSource.gallery,
    maxWidth:1600,
    maxHeight:1600);
    if(file==null) {
      return;
    } final decoded=img.decodeImage(await file.readAsBytes());
    if(decoded==null) {
      throw const FormatException('الصورة غير مدعومة');
    } final bytes=Uint8List.fromList(img.encodeJpg(img.copyResize(decoded,
    width:1200),
    quality:85));
    if(mounted) {
      setState(()=>background=bytes);
    }
  } @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('استوديو البطاقات')),
  body:ListView(padding:const EdgeInsets.all(20),
  children:[ RepaintBoundary(key:key,
  child:Container(constraints:BoxConstraints(minHeight:320/ratio),
  padding:const EdgeInsets.all(28),
  decoration:BoxDecoration(color:colors[palette],
  image:background==null?null:DecorationImage(image:MemoryImage(background!),
  fit:BoxFit.cover,
  colorFilter:ColorFilter.mode(colors[palette].withValues(alpha:.85),
  BlendMode.srcOver)),
  border:Border.all(color:ink.withValues(alpha:.45),
  width:pattern==0?2:8),
  borderRadius:BorderRadius.circular(pattern==2?60:16)),
  child:Column(mainAxisSize:MainAxisSize.min,
  children:[ Icon(pattern==1?Icons.auto_awesome:Icons.nightlight_round,
  color:ink,
  size:32),
  const SizedBox(height:16),
  Text(widget.title,
  style:TextStyle(color:ink,
  fontWeight:FontWeight.bold)),
  const SizedBox(height:20),
  Text(widget.text,
  textAlign:TextAlign.center,
  style:TextStyle(color:ink,
  fontSize:size,
  height:1.9)),
  if(footer)...[const SizedBox(height:24),
  Text('أوراد المسلم • الدال على الخير كفاعله',
  style:TextStyle(color:ink,
  fontSize:12))],
  ]))),
  const SizedBox(height:20),
  Wrap(spacing:12,
  children:List.generate(colors.length,
  (i)=>ChoiceChip(label:Text(['ذهبي',
  'زمردي',
  'ليلي',
  'وردي',
  'أسود'][i]),
  selected:palette==i,
  onSelected:(_)=>setState(()=>palette=i)))),
  Slider(value:size,
  min:16,
  max:48,
  divisions:16,
  label:'حجم الخط',
  onChanged:(v)=>setState(()=>size=v)),
  Wrap(spacing:8,
  children:List.generate(3,
  (i)=>ChoiceChip(label:Text(['إطار',
  'نجوم',
  'محراب'][i]),
  selected:pattern==i,
  onSelected:(_)=>setState(()=>pattern=i)))),
  SegmentedButton<double>(segments:const [ButtonSegment(value:1,
  label:Text('مربع')),
  ButtonSegment(value:.65,
  label:Text('طولي')),
  ButtonSegment(value:1.6,
  label:Text('عرضي'))],
  selected:{
    ratio
  },
  onSelectionChanged:(s)=>setState(()=>ratio=s.first)),
  SwitchListTile(title:const Text('إضافة تذييل البطاقة'),
  value:footer,
  onChanged:(v)=>setState(()=>footer=v)),
  OutlinedButton.icon(onPressed:busy?null:()=>run(pick),
  icon:const Icon(Icons.image_outlined),
  label:const Text('صورة خلفية')),
  if(background!=null) TextButton(onPressed:()=>setState(()=>background=null),
  child:const Text('إزالة الصورة')),
  Wrap(spacing:8,
  children:[FilledButton.icon(onPressed:busy?null:()=>run(share),
  icon:const Icon(Icons.share),
  label:const Text('مشاركة')),
  FilledButton.tonalIcon(onPressed:busy?null:()=>run(save),
  icon:const Icon(Icons.download),
  label:const Text('حفظ PNG')),
  OutlinedButton.icon(onPressed:busy?null:()=>run(printCard),
  icon:const Icon(Icons.print),
  label:const Text('طباعة / PDF'))]),
  if(busy)const LinearProgressIndicator(),
  ]));
}
