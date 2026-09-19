import 'dart:convert';
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
      title: 'Ship Stability & Draft Calculator',
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

  String _calculatedAirDraft = "0.00 m";
  String _calculatedMeanDraft = "0.00 m";
  String _calculatedTrim = "0.00 m";

  List<Map<String, String>> _historyList = [];
  int? _editingIndex; // Nag-o-orbit kapag nag-e-edit ng lumang record

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // I-load ang History mula sa Local Storage
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

  // I-save o I-update ang History Item
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
      'mean': _calculatedMeanDraft,
      'trim': _calculatedTrim,
      'airDraft': _calculatedAirDraft,
    };

    setState(() {
      if (_editingIndex != null) {
        // Kapag nasa Edit Mode, i-update ang napiling record
        _historyList[_editingIndex!] = entry;
        _editingIndex = null;
      } else {
        // Kapag bagong save, idagdag sa pinakataas
        _historyList.insert(0, entry);
      }
    });

    await prefs.setString('saved_history', jsonEncode(_historyList));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Matagumpay na na-save sa History!')),
    );
  }

  // I-load ang Record pabalik sa Form para ma-Edit
  void _editHistoryItem(int index) {
    final item = _historyList[index];
    setState(() {
      _editingIndex = index;
      _draftFwdController.text = item['fwd'] ?? '';
      _draftMidController.text = item['mid'] ?? '';
      _draftAftController.text = item['aft'] ?? '';
      _ktmController.text = item['ktm'] ?? '';
      _calculate();
    });
    Navigator.pop(context); // Isara ang History Popup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Na-load ang entry #${index + 1}. Pwede mo na itong i-edit at i-save ulit.')),
    );
  }

  // Burahin ang Single Record sa History
  Future<void> _deleteHistoryItem(int index, StateSetter setDialogState) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyList.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
      }
    });
    setDialogState(() {});
    await prefs.setString('saved_history', jsonEncode(_historyList));
  }

  // Burahin ang Lahat ng History Records
  Future<void> _clearAllHistory(StateSetter setDialogState) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyList.clear();
      _editingIndex = null;
    });
    setDialogState(() {});
    await prefs.remove('saved_history');
  }

  // Kalkulasyon para sa Draft, Trim, at Air Draft
  void _calculate() {
    double fwd = double.tryParse(_draftFwdController.text) ?? 0.0;
    double mid = double.tryParse(_draftMidController.text) ?? 0.0;
    double aft = double.tryParse(_draftAftController.text) ?? 0.0;
    double ktm = double.tryParse(_ktmController.text) ?? 0.0;

    double meanDraft = (fwd + (4 * mid) + aft) / 6;
    double trim = aft - fwd;
    double airDraft = ktm > 0 ? (ktm - meanDraft) : 0.0;

    setState(() {
      _calculatedMeanDraft = "${meanDraft.toStringAsFixed(2)} m";
      _calculatedTrim = "${trim.toStringAsFixed(2)} m";
      _calculatedAirDraft = "${airDraft.toStringAsFixed(2)} m";
    });
  }

  // Pop-up Dialog para sa History List
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
                    tooltip: 'Clear All History',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear All History?'),
                          content: const Text('Sigurado ka bang gusto mong burahin ang lahat ng na-save na records?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                _clearAllHistory(setDialogState);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Delete All', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
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
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text('Date: ${item['date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('F/M/A: ${item['fwd']}/${item['mid']}/${item['aft']}m\nMean: ${item['mean']} | Air: ${item['airDraft']}'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // EDIT BUTTON
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit Entry',
                                  onPressed: () => _editHistoryItem(index),
                                ),
                                // DELETE BUTTON
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete Entry',
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
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: _showHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Data',
            onPressed: _saveToHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicator Bar kapag nasa Edit Mode
            if (_editingIndex != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.only(bottom: 12.0),
                color: Colors.orange.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Editing Record #${_editingIndex! + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _editingIndex = null;
                          _draftFwdController.clear();
                          _draftMidController.clear();
                          _draftAftController.clear();
                          _ktmController.clear();
                          _calculate();
                        });
                      },
                    )
                  ],
                ),
              ),

            const Text('Draft Inputs (Meters)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextField(
              controller: _draftFwdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Draft Forward (Fwd)'),
              onChanged: (_) => _calculate(),
            ),
            TextField(
              controller: _draftMidController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Draft Midship (Mid)'),
              onChanged: (_) => _calculate(),
            ),
            TextField(
              controller: _draftAftController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Draft Aft'),
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 15),
            const Text('Ship Particulars', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextField(
              controller: _ktmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Keel to Mast Head / KTM (m)'),
              onChanged: (_) => _calculate(),
            ),
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
                    Text('Quarter Mean Draft: $_calculatedMeanDraft'),
                    Text('Trim: $_calculatedTrim'),
                    Text('Air Draft: $_calculatedAirDraft'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveToHistory,
                    icon: const Icon(Icons.save),
                    label: Text(_editingIndex != null ? 'Update Record' : 'Save to History'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showHistoryDialog,
                    icon: const Icon(Icons.history),
                    label: const Text('View History'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            const Center(
              child: Text(
                'Developer: Renante Fullo',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
