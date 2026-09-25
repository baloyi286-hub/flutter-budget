import 'dart:async';
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

class BudgetApp extends StatefulWidget{
  const BudgetApp({super.key});
  @override State<BudgetApp> createState()=>_BudgetAppState();
}

class _BudgetAppState extends State<BudgetApp>{
  BudgetService? service;
  StreamSubscription<AuthState>? _authSubscription;
  bool loading=false;
  String? loadError;

  @override void initState(){
    super.initState();
    _authSubscription=Supabase.instance.client.auth.onAuthStateChange.listen((data){
      if(data.event==AuthChangeEvent.signedIn||data.event==AuthChangeEvent.initialSession||data.event==AuthChangeEvent.tokenRefreshed){
        _load();
      }else if(data.event==AuthChangeEvent.signedOut){
        service?.dispose();
        if(mounted)setState((){service=null;loading=false;loadError=null;});
      }
    });
    _load();
  }

  Future<void> _load() async{
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null){
      service?.dispose();
      if(mounted)setState((){service=null;loading=false;loadError=null;});
      return;
    }
    if(loading)return;
    if(mounted)setState((){loading=true;loadError=null;});
    try{
      final prefs=await SharedPreferences.getInstance();
      final s=BudgetService(LocalBudgetRepository(prefs,user.id),cloud:CloudBudgetStore(Supabase.instance.client));
      await s.initialize();
      if(mounted){service?.dispose();setState((){service=s;loading=false;});}
    }catch(e){
      if(mounted)setState((){loading=false;loadError='Signed in successfully, but the budget could not load. Error: $e';});
    }
  }

  @override void dispose(){_authSubscription?.cancel();service?.dispose();super.dispose();}

  @override Widget build(BuildContext context){
    final user=Supabase.instance.client.auth.currentUser;
    return MaterialApp(
      debugShowCheckedModeBanner:false,title:'Budget',
      theme:ThemeData(useMaterial3:true,brightness:Brightness.light,scaffoldBackgroundColor:const Color(0xFFF4F7FA),
        colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF1976D2),primary:const Color(0xFF1976D2),secondary:const Color(0xFFFF654E),surface:Colors.white),
        appBarTheme:const AppBarTheme(backgroundColor:Color(0xFFFF654E),foregroundColor:Colors.white),
        cardTheme:CardThemeData(color:Colors.white,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
        inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:const Color(0xFFF7F9FC),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)))),
      home:user==null
        ?const LoginPage()
        :service!=null
          ?BudgetPage(service:service!,onSignedOut:(){})
          :Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
              if(loading)...[const CircularProgressIndicator(),const SizedBox(height:16),const Text('Signing in and loading your budget...')]
              else...[const Icon(Icons.cloud_off,size:48),const SizedBox(height:12),Text(loadError??'Unable to load budget.',textAlign:TextAlign.center),const SizedBox(height:16),FilledButton(onPressed:_load,child:const Text('Retry')),TextButton(onPressed:()=>Supabase.instance.client.auth.signOut(),child:const Text('Sign out'))]
            ])))),
    );
  }
}
