import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/data/budget_repository.dart';
import 'src/data/cloud_budget_store.dart';
import 'src/domain/budget_service.dart';
import 'src/presentation/budget_page.dart';
import 'src/presentation/login_page.dart';

const supabaseUrl='https://axmztbdppmenjbdxjyew.supabase.co';
const supabasePublishableKey='sb_publishable_v26yCutaz81WrWFj92sdlg_BxgAdM7h';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url:supabaseUrl,anonKey:supabasePublishableKey);
  runApp(const BudgetApp());
}
class BudgetApp extends StatefulWidget{const BudgetApp({super.key});@override State<BudgetApp> createState()=>_BudgetAppState();}
class _BudgetAppState extends State<BudgetApp>{
  BudgetService? service;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async{
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null){service?.dispose();if(mounted)setState(()=>service=null);return;}
    final prefs=await SharedPreferences.getInstance();
    final s=BudgetService(LocalBudgetRepository(prefs,user.id),cloud:CloudBudgetStore(Supabase.instance.client));
    await s.initialize();
    if(mounted){service?.dispose();setState(()=>service=s);}
  }
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'Budget',
    theme:ThemeData(useMaterial3:true,brightness:Brightness.light,scaffoldBackgroundColor:const Color(0xFFF4F7FA),
      colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF1976D2),primary:const Color(0xFF1976D2),secondary:const Color(0xFFFF654E),surface:Colors.white),
      appBarTheme:const AppBarTheme(backgroundColor:Color(0xFFFF654E),foregroundColor:Colors.white),
      cardTheme:CardThemeData(color:Colors.white,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:const Color(0xFFF7F9FC),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)))),
    home:Supabase.instance.client.auth.currentUser==null?LoginPage(onSignedIn:_load):service==null?const Scaffold(body:Center(child:CircularProgressIndicator())):BudgetPage(service:service!),
  );
}
