import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const ShipCalculatorApp());
}

class ShipCalculatorApp extends StatefulWidget {
  const ShipCalculatorApp({super.key});

  @override
  State<ShipCalculatorApp> createState() => _ShipCalculatorAppState();
}

class _ShipCalculatorAppState extends State<ShipCalculatorApp> {
  bool _isDarkMode = false;

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ship Stability & Draft Calculator',
      // Dynamic Theme Switcher (Light vs Dark)
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: CalculatorHomeScreen(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: _toggleDarkMode,
      ),
    );
  }
}

class CalculatorHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const CalculatorHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Load Saved History List
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

  // Save Current Entry to History
  Future<void> _saveToHistory() async {
    if (_draftFwdController.text.isEmpty && _draftAftController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter draft values before saving.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    Map<String, String> newEntry = {
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
      _historyList.insert(0, newEntry);
    });

    await prefs.setString('saved_history', jsonEncode(_historyList));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculation saved to History!')),
    );
  }

  // Print PDF Function
  Future<void> _printReport() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Ship Stability & Draft Calculation Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Date: ${DateTime.now().toString().substring(0, 16)}'),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text('Draft Inputs (Meters)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Draft Forward (Fwd): ${_draftFwdController.text} m'),
                pw.Text('Draft Midship (Mid): ${_draftMidController.text} m'),
                pw.Text('Draft Aft: ${_draftAftController.text} m'),
                pw.SizedBox(height: 10),
                pw.Text('Ship Particulars', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Keel to Mast Head / KTM: ${_ktmController.text} m'),
                pw.SizedBox(height: 15),
                pw.Text('Calculated Results', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Quarter Mean Draft: $_calculatedMeanDraft'),
                pw.Text('Trim: $_calculatedTrim'),
                pw.Text('Air Draft: $_calculatedAirDraft'),
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text('Developer: Renante Fullo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Load Selected History Item Back to Form
  void _editHistoryItem(Map<String, String> item) {
    setState(() {
      _draftFwdController.text = item['fwd'] ?? '';
      _draftMidController.text = item['mid'] ?? '';
      _draftAftController.text = item['aft'] ?? '';
      _ktmController.text = item['ktm'] ?? '';
      _calculate();
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data loaded! You can now edit and re-calculate.')),
    );
  }

  // Delete Item from History
  Future<void> _deleteHistoryItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyList.removeAt(index);
    });
    await prefs.setString('saved_history', jsonEncode(_historyList));
  }

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

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Saved Calculations History'),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: _historyList.isEmpty
                  ? const Center(child: Text('No saved history yet.'))
                  : ListView.builder(
                      itemCount: _historyList.length,
                      itemBuilder: (context, index) {
                        final item = _historyList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text('Date: ${item['date']}'),
                            subtitle: Text('Drafts: ${item['fwd']}/${item['mid']}/${item['aft']}m | Air: ${item['airDraft']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _deleteHistoryItem(index);
                                setDialogState(() {});
                              },
                            ),
                            onTap: () => _editHistoryItem(item),
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
          // Dark Mode Toggle Switch / Icon
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
            tooltip: 'Toggle Dark/Light Mode',
            onPressed: () => widget.onToggleDarkMode(!widget.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print / Export PDF',
            onPressed: _printReport,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
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
              color: widget.isDarkMode ? Colors.grey.shade800 : Colors.blue.shade50,
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
                    label: const Text('Save to History'),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _printReport,
                icon: const Icon(Icons.print),
                label: const Text('Print Calculation Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Developer Credit
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
