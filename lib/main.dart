import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ShipCalculatorApp());
}

class ShipCalculatorApp extends StatelessWidget {
  const ShipCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ship Stability Calculator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CalculatorHomeScreen(),
    );
  }
}

class CalculatorHomeScreen extends StatefulWidget {
  const CalculatorHomeScreen({super.key});

  @override
  State<CalculatorHomeScreen> createState() => _CalculatorHomeScreenState();
}

class _CalculatorHomeScreenState extends State<CalculatorHomeScreen> {
  final TextEditingController _draftFwdController = TextEditingController();
  final TextEditingController _draftMidController = TextEditingController();
  final TextEditingController _draftAftController = TextEditingController();
  final TextEditingController _ktmController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _kgController = TextEditingController();
  final TextEditingController _fscController = TextEditingController(text: "0");
  final TextEditingController _beamController = TextEditingController();

  String _calculatedMeanDraft = "0.00 m";
  String _calculatedTrim = "0.00 m";
  String _calculatedAirDraft = "0.00 m";
  String _calculatedSolidGM = "0.00 m";
  String _calculatedFluidGM = "0.00 m";
  String _calculatedRollingPeriod = "0.00 s";

  List<Map<String, String>> _historyList = [];
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('saved_history');
    if (historyJson != null) {
      setState(() {
        List<dynamic> decoded = jsonDecode(historyJson);
        _historyList = decoded.map((item) => Map<String, String>.from(item)).toList();
      });
    }
  }

  Future<void> _saveToHistory() async {
    if (_draftFwdController.text.isEmpty && _draftAftController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maglagay muna ng draft values bago mag-save.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    Map<String, String> entry = {
      'date': DateTime.now().toString().substring(0, 16),
      'fwd': _draftFwdController.text,
      'mid': _draftMidController.text,
      'aft': _draftAftController.text,
      'ktm': _ktmController.text,
      'km': _kmController.text,
      'kg': _kgController.text,
      'fsc': _fscController.text,
      'beam': _beamController.text,
      'mean': _calculatedMeanDraft,
      'trim': _calculatedTrim,
      'airDraft': _calculatedAirDraft,
      'solidGM': _calculatedSolidGM,
      'fluidGM': _calculatedFluidGM,
      'rollingPeriod': _calculatedRollingPeriod,
    };

    setState(() {
      if (_editingIndex != null) {
        _historyList[_editingIndex!] = entry;
        _editingIndex = null;
      } else {
        _historyList.insert(0, entry);
      }
    });

    await prefs.setString('saved_history', jsonEncode(_historyList));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Matagumpay na na-save sa History!')),
    );
  }

  void _editHistoryItem(int index) {
    final item = _historyList[index];
    setState(() {
      _editingIndex = index;
      _draftFwdController.text = item['fwd'] ?? '';
      _draftMidController.text = item['mid'] ?? '';
      _draftAftController.text = item['aft'] ?? '';
      _ktmController.text = item['ktm'] ?? '';
      _kmController.text = item['km'] ?? '';
      _kgController.text = item['kg'] ?? '';
      _fscController.text = item['fsc'] ?? '0';
      _beamController.text = item['beam'] ?? '';
      _calculate();
    });
    Navigator.pop(context);
  }

  Future<void> _deleteHistoryItem(int index, StateSetter setDialogState) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyList.removeAt(index);
      if (_editingIndex == index) _editingIndex = null;
    });
    setDialogState(() {});
    await prefs.setString('saved_history', jsonEncode(_historyList));
  }

  Future<void> _clearAllHistory(StateSetter setDialogState) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyList.clear();
      _editingIndex = null;
    });
    setDialogState(() {});
    await prefs.remove('saved_history');
  }

  void _calculate() {
    double fwd = double.tryParse(_draftFwdController.text) ?? 0.0;
    double mid = double.tryParse(_draftMidController.text) ?? 0.0;
    double aft = double.tryParse(_draftAftController.text) ?? 0.0;
    double ktm = double.tryParse(_ktmController.text) ?? 0.0;
    double km = double.tryParse(_kmController.text) ?? 0.0;
    double kg = double.tryParse(_kgController.text) ?? 0.0;
    double fsc = double.tryParse(_fscController.text) ?? 0.0;
    double beam = double.tryParse(_beamController.text) ?? 0.0;

    double meanDraft = (fwd + (4 * mid) + aft) / 6;
    double trim = aft - fwd;
    double airDraft = ktm > 0 ? (ktm - meanDraft) : 0.0;

    double solidGM = km - kg;
    double fluidGM = solidGM - fsc;

    double rollingPeriod = 0.0;
    if (beam > 0 && fluidGM > 0) {
      rollingPeriod = (0.8 * beam) / sqrt(fluidGM);
    }

    setState(() {
      _calculatedMeanDraft = "${meanDraft.toStringAsFixed(2)} m";
      _calculatedTrim = "${trim.toStringAsFixed(2)} m";
      _calculatedAirDraft = "${airDraft.toStringAsFixed(2)} m";
      _calculatedSolidGM = "${solidGM.toStringAsFixed(2)} m";
      _calculatedFluidGM = "${fluidGM.toStringAsFixed(2)} m";
      _calculatedRollingPeriod = "${rollingPeriod.toStringAsFixed(2)} s";
    });
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saved History', style: TextStyle(fontSize: 18)),
                if (_historyList.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () {
                      _clearAllHistory(setDialogState);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: _historyList.isEmpty
                  ? const Center(child: Text('Walang naka-save na history.'))
                  : ListView.builder(
                      itemCount: _historyList.length,
                      itemBuilder: (context, index) {
                        final item = _historyList[index];
                        return Card(
                          child: ListTile(
                            title: Text('Date: ${item['date']}'),
                            subtitle: Text('Fluid GM: ${item['fluidGM']} | Roll: ${item['rollingPeriod']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editHistoryItem(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteHistoryItem(index, setDialogState),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ship Stability Calculator'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _showHistoryDialog),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveToHistory),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Draft & Particulars', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextField(controller: _draftFwdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Draft Fwd (m)'), onChanged: (_) => _calculate()),
            TextField(controller: _draftMidController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Draft Mid (m)'), onChanged: (_) => _calculate()),
            TextField(controller: _draftAftController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Draft Aft (m)'), onChanged: (_) => _calculate()),
            TextField(controller: _ktmController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'KTM (m)'), onChanged: (_) => _calculate()),
            TextField(controller: _beamController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ship Beam / Width (m)'), onChanged: (_) => _calculate()),

            const SizedBox(height: 15),
            const Text('2. Stability Hydrostatics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextField(controller: _kmController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'KM (m)'), onChanged: (_) => _calculate()),
            TextField(controller: _kgController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'KG (m)'), onChanged: (_) => _calculate()),
            TextField(controller: _fscController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'FSC (m)'), onChanged: (_) => _calculate()),

            const SizedBox(height: 20),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Calculated Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    Text('Mean Draft: $_calculatedMeanDraft'),
                    Text('Trim: $_calculatedTrim'),
                    Text('Air Draft: $_calculatedAirDraft'),
                    const SizedBox(height: 5),
                    Text('Solid GM: $_calculatedSolidGM', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Fluid GM (GoM): $_calculatedFluidGM', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text('Est. Rolling Period: $_calculatedRollingPeriod', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: _saveToHistory, icon: const Icon(Icons.save), label: const Text('Save Record'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(onPressed: _showHistoryDialog, icon: const Icon(Icons.history), label: const Text('History'))),
              ],
            ),
            const SizedBox(height: 20),
            const Center(child: Text('Developer: Renante Fullo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          ],
        ),
      ),
    );
  }
}
