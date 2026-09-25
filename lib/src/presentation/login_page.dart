import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState()=>_LoginPageState();
}

class _LoginPageState extends State<LoginPage>{
  final email=TextEditingController();
  final password=TextEditingController();
  bool busy=false;
  String? message;

  Future<void> go(bool signUp) async{
    final address=email.text.trim();
    if(address.isEmpty||password.text.isEmpty){setState(()=>message='Enter your email and password.');return;}
    setState((){busy=true;message=null;});
    try{
      if(signUp){
        final response=await Supabase.instance.client.auth.signUp(email:address,password:password.text);
        if(!mounted)return;
        if(response.session==null){
          setState(()=>message='Account created. Check your email for the confirmation link, then return here and sign in.');
        }else{
          setState(()=>message='Account created. Signing you in...');
        }
      }else{
        final response=await Supabase.instance.client.auth.signInWithPassword(email:address,password:password.text);
        if(!mounted)return;
        if(response.session==null){
          setState(()=>message='Supabase did not return a login session. Check that your email is confirmed.');
        }else{
          setState(()=>message='Login successful. Loading your budget...');
        }
      }
    }on AuthException catch(e){
      if(mounted)setState(()=>message='Login error: ${e.message}');
    }catch(e){
      if(mounted)setState(()=>message='Connection error: $e');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  @override void dispose(){email.dispose();password.dispose();super.dispose();}

  @override Widget build(BuildContext context)=>Scaffold(body:Center(child:SingleChildScrollView(
    padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Card(child:Padding(
      padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.account_balance_wallet_rounded,size:54,color:Color(0xFF1976D2)),
        const SizedBox(height:16),
        const Text('MONTHLY BUDGET',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,letterSpacing:2)),
        const SizedBox(height:24),
        TextField(controller:email,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'Email')),
        const SizedBox(height:12),
        TextField(controller:password,obscureText:true,onSubmitted:(_){if(!busy)go(false);},decoration:const InputDecoration(labelText:'Password')),
        if(message!=null)...[const SizedBox(height:12),Text(message!,textAlign:TextAlign.center)],
        const SizedBox(height:20),
        SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:()=>go(false),child:Text(busy?'Please wait...':'Sign in'))),
        TextButton(onPressed:busy?null:()=>go(true),child:const Text('Create account')),
      ]),
    ))),
  )));

}
