import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';
import 'consultation_request_screen.dart';

class ConsultantsListScreen extends StatefulWidget {
  const ConsultantsListScreen({super.key});
  @override
  State<ConsultantsListScreen> createState() => _ConsultantsListScreenState();
}

class _ConsultantsListScreenState extends State<ConsultantsListScreen> {
  List _all = [];
  List _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final token = await TokenStorage.getAccessToken();
    final res = await http.get(Uri.parse("${ApiConfig.baseUrl}/api/consultants/"), headers: {"Authorization": "Bearer $token"});
    if (res.statusCode == 200) {
      setState(() {
        _all = _filtered = jsonDecode(res.body);
        _loading = false;
      });
    }
  }

  void _search(String val) {
    setState(() => _filtered = _all.where((c) => c['name'].toLowerCase().contains(val.toLowerCase()) || c['specialization'].toLowerCase().contains(val.toLowerCase())).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Consultants"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Column(children: [
        Padding(padding: EdgeInsets.all(15), child: TextField(onChanged: _search, decoration: InputDecoration(hintText: "Search name or specialty...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))))),
        Expanded(child: ListView.builder(itemCount: _filtered.length, itemBuilder: (c, i) => ListTile(
          leading: CircleAvatar(backgroundImage: NetworkImage(_filtered[i]['profile_picture_url'])),
          title: Text(_filtered[i]['name']), subtitle: Text(_filtered[i]['specialization']),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => ConsultationRequestScreen(consultant: _filtered[i]))),
        )))
      ]),
    );
  }
}