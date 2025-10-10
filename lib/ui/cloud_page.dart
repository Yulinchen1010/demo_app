import 'package:flutter/material.dart';

import '../data/cloud_api.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  final _urlCtrl = TextEditingController(text: CloudApi.baseUrl);
  final _workerCtrl = TextEditingController(text: 'worker_1');
  final _mvcCtrl = TextEditingController(text: '20');

  String _log = '';
  bool _busy = false;

  void _append(Object msg) {
    setState(() => _log = '${DateTime.now().toIso8601String()}\n$msg\n\n' + _log);
  }

  Future<void> _saveBaseUrl() async {
    CloudApi.setBaseUrl(_urlCtrl.text);
    _append('Base URL set to: ${CloudApi.baseUrl}');
  }

  Future<void> _upload() async {
    final worker = _workerCtrl.text.trim();
    final mvc = double.tryParse(_mvcCtrl.text.trim()) ?? 0;
    if (worker.isEmpty || CloudApi.baseUrl.isEmpty) {
      _append('Please set Base URL and Worker ID');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await CloudApi.upload(workerId: worker, percentMvc: mvc);
      _append('Upload OK: $res');
    } catch (e) {
      _append('Upload error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _status() async {
    final worker = _workerCtrl.text.trim();
    if (worker.isEmpty || CloudApi.baseUrl.isEmpty) {
      _append('Please set Base URL and Worker ID');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await CloudApi.status(worker);
      _append('Status: $res');
    } catch (e) {
      _append('Status error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _predict() async {
    final worker = _workerCtrl.text.trim();
    if (worker.isEmpty || CloudApi.baseUrl.isEmpty) {
      _append('Please set Base URL and Worker ID');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await CloudApi.predict(worker);
      _append('Predict: $res');
    } catch (e) {
      _append('Predict error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud API')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Base URL (e.g. https://api.example.com)',
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _workerCtrl,
                  decoration: const InputDecoration(labelText: 'Worker ID'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _mvcCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'MVC %'),
                ),
              )
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: _busy ? null : _saveBaseUrl,
                child: const Text('Save Base URL'),
              ),
              ElevatedButton(
                onPressed: _busy ? null : _upload,
                child: const Text('Upload'),
              ),
              ElevatedButton(
                onPressed: _busy ? null : _status,
                child: const Text('Status'),
              ),
              ElevatedButton(
                onPressed: _busy ? null : _predict,
                child: const Text('Predict'),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

