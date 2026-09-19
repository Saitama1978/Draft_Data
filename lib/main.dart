import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart' as pdf_lib;
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

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ship Stability Calculator',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F2338),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1624),
          foregroundColor: Colors.white,
        ),
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
  final VoidCallback onToggleDarkMode;

  const CalculatorHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<CalculatorHomeScreen> createState() => _CalculatorHomeScreenState();
}

class _CalculatorHomeScreenState extends State<CalculatorHomeScreen> {
  // 1. Ship Particulars
  final TextEditingController _ktmController = TextEditingController();
  final TextEditingController _beamController = TextEditingController();

  // 2. Draft & Hydrostatic Values
  final TextEditingController _draftFwdController = TextEditingController();
  final TextEditingController _draftMidController = TextEditingController();
  final TextEditingController _draftAftController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _kgController = TextEditingController();
  final TextEditingController _fscController = TextEditingController(text: "0");

  // 3. Density Settings
  final TextEditingController _swDensityController = TextEditingController(text: "1.025");
  final TextEditingController _dockDensityController = TextEditingController(text: "1.025");

  // Calculated Results
  String _calculatedMeanDraft = "0.00 m";
  String _calculatedTrim = "0.00 m";
  String _calculatedAirDraft = "0.00 m";
  String _calculatedSolidGM = "0.00 m";
  String _calculatedFluidGM = "0.00 m";
  String _calculatedRollingPeriod = "0.00 s";

  List<Map<String, String>> _historyList = [];

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
    Map<String, String> newEntry = {
      'date': DateTime.now().toString().substring(0, 16),
      'ktm': _ktmController.text,
      'beam': _beamController.text,
      'fwd': _draftFwdController.text,
      'mid': _draftMidController.text,
      'aft': _draftAftController.text,
      'km': _kmController.text,
      'kg': _kgController.text,
      'fsc': _fscController.text,
      'swDensity': _swDensityController.text,
      'dockDensity': _dockDensityController.text,
      'mean': _calculatedMeanDraft,
      'trim': _calculatedTrim,
      'airDraft': _calculatedAirDraft,
      'solidGM': _calculatedSolidGM,
      'fluidGM': _calculatedFluidGM,
      'rollingPeriod': _calculatedRollingPeriod,
    };

    setState(() {
      _historyList.insert(0, newEntry);
    });

    await prefs.setString('saved_history', jsonEncode(_historyList));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Na-save sa History!')),
    );
  }

  void _editHistoryItem(Map<String, String> item) {
    setState(() {
      _ktmController.text = item['ktm'] ?? '';
      _beamController.text = item['beam'] ?? '';
      _draftFwdController.text = item['fwd'] ?? '';
      _draftMidController.text = item['mid'] ?? '';
      _draftAftController.text = item['aft'] ?? '';
      _kmController.text = item['km'] ?? '';
      _kgController.text = item['kg'] ?? '';
      _fscController.text = item['fsc'] ?? '0';
      _swDensityController.text = item['swDensity'] ?? '1.025';
      _dockDensityController.text = item['dockDensity'] ?? '1.025';
      _calculate();
    });
    Navigator.pop(context);
  }

  Future<void> _deleteHistoryItem(int index, StateSetter setDialogState) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyList.removeAt(index);
    });
    setDialogState(() {});
    await prefs.setString('saved_history', jsonEncode(_historyList));
  }

  void _calculate() {
    double fwd = double.tryParse(_draftFwdController.text) ?? 0.0;
    double mid = double.tryParse(_draftMidController.text) ?? 0.0;
    double aft = double.tryParse(_draftAftController.text) ?? 0.0;
    double ktm = double.tryParse(_ktmController.text) ?? 0.0;
    double beam = double.tryParse(_beamController.text) ?? 0.0;
    double km = double.tryParse(_kmController.text) ?? 0.0;
    double kg = double.tryParse(_kgController.text) ?? 0.0;
    double fsc = double.tryParse(_fscController.text) ?? 0.0;

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

  void _resetFields() {
    setState(() {
      _ktmController.clear();
      _beamController.clear();
      _draftFwdController.clear();
      _draftMidController.clear();
      _draftAftController.clear();
      _kmController.clear();
      _kgController.clear();
      _fscController.text = "0";
      _swDensityController.text = "1.025";
      _dockDensityController.text = "1.025";
      _calculate();
    });
  }

  Future<void> _printReport() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Ship Stability & Draft Calculation Report',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Date: ${DateTime.now().toString().substring(0, 16)}'),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text('1. Ship Particulars', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('KTM: ${_ktmController.text} m | Beam: ${_beamController.text} m'),
                pw.SizedBox(height: 8),
                pw.Text('2. Draft & Hydrostatic Values', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Fwd: ${_draftFwdController.text} m | Mid: ${_draftMidController.text} m | Aft: ${_draftAftController.text} m'),
                pw.Text('KM: ${_kmController.text} m | KG: ${_kgController.text} m | FSC: ${_fscController.text} m'),
                pw.SizedBox(height: 8),
                pw.Text('3. Density Settings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('SW Density: ${_swDensityController.text} | Dock Density: ${_dockDensityController.text}'),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.Text('Calculated Results', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Quarter Mean Draft: $_calculatedMeanDraft'),
                pw.Text('Trim: $_calculatedTrim'),
                pw.Text('Air Draft: $_calculatedAirDraft'),
                pw.Text('Solid GM: $_calculatedSolidGM'),
                pw.Text('Fluid GM (GoM): $_calculatedFluidGM'),
                pw.Text('Est. Rolling Period: $_calculatedRollingPeriod'),
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

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Saved History'),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: _historyList.isEmpty
                  ? const Center(child: Text('No saved history.'))
                  : ListView.builder(
                      itemCount: _historyList.length,
                      itemBuilder: (context, index) {
                        final item = _historyList[index];
                        return Card(
                          child: ListTile(
                            title: Text('Date: ${item['date']}'),
                            subtitle: Text('F/M/A: ${item['fwd']}/${item['mid']}/${item['aft']}m\nFluid GM: ${item['fluidGM']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteHistoryItem(index, setDialogState),
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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1377A6),
              ),
            ),
            const SizedBox(height: 6),
            const Divider(color: Colors.black26),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String labelText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(labelText, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black87),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black87),
              ),
            ),
            onChanged: (_) => _calculate(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Ship Stability Calculator',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
            tooltip: 'Dark / Light Mode',
            onPressed: widget.onToggleDarkMode,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Report',
            onPressed: _printReport,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: _showHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveToHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Ship Particulars
            _buildSectionCard(
              title: '1. Ship Particulars',
              children: [
                _buildInputField(_ktmController, 'Keel to Mast Head / KTM (m)'),
                _buildInputField(_beamController, 'Ship Beam / Width (m)'),
              ],
            ),

            // 2. Draft & Hydrostatic Values
            _buildSectionCard(
              title: '2. Draft & Hydrostatic Values',
              children: [
                _buildInputField(_draftFwdController, 'Draft Forward - Fwd (m)'),
                _buildInputField(_draftMidController, 'Draft Midship - Mid (m)'),
                _buildInputField(_draftAftController, 'Draft Aft - Aft (m)'),
                _buildInputField(_kmController, 'KM (m)'),
                _buildInputField(_kgController, 'KG (m)'),
                _buildInputField(_fscController, 'Free Surface Correction / FSC (m)'),
              ],
            ),

            // 3. Density Settings
            _buildSectionCard(
              title: '3. Density Settings',
              children: [
                _buildInputField(_swDensityController, 'Standard SW Density (t/m³)'),
                _buildInputField(_dockDensityController, 'Dock Water Density (t/m³)'),
              ],
            ),

            // Calculated Results Card
            Card(
              elevation: 0,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Calculated Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1377A6))),
                    const Divider(),
                    Text('Quarter Mean Draft: $_calculatedMeanDraft'),
                    Text('Trim: $_calculatedTrim'),
                    Text('Air Draft: $_calculatedAirDraft'),
                    const SizedBox(height: 4),
                    Text('Solid GM: $_calculatedSolidGM'),
                    Text('Fluid GM (GoM): $_calculatedFluidGM', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text('Est. Rolling Period: $_calculatedRollingPeriod', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveToHistory,
                    icon: const Icon(Icons.save),
                    label: const Text('CALCULATE & SAVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2338),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetFields,
                    icon: const Icon(Icons.refresh),
                    label: const Text('RESET'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Developer Name Footer
            const Center(
              child: Text(
                'Developer: Renante Fullo',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
