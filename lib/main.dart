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
      'beam': _beamController.text,
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
      if (_editingIndex == index) _editingIndex = null;
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
      _draftFwdController.clear();
      _draftMidController.clear();
      _draftAftController.clear();
      _ktmController.clear();
      _beamController.clear();
      _kmController.clear();
      _kgController.clear();
      _fscController.text = "0";
      _dockDensityController.text = "1.025";
      _editingIndex = null;
      _calculate();
    });
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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onChanged: (_) => _calculate(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ship Stability Calculator', style: TextStyle(fontSize: 18)),
            Text('Developer: Renante Fullo', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _showHistoryDialog),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveToHistory),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_editingIndex != null)
              Container(
                color: Colors.orange.shade100,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Editing Record #${_editingIndex! + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: _resetFields)
                  ],
                ),
              ),

            // 1. Ship Particulars
            _buildSectionCard(
              title: '1. Ship Particulars',
              children: [
                _buildInput(_ktmController, 'Keel to Mast Head / KTM (m)'),
                _buildInput(_beamController, 'Ship Beam / Width (m)'),
              ],
            ),

            // 2. Draft & Hydrostatic Values
            _buildSectionCard(
              title: '2. Draft & Hydrostatic Values',
              children: [
                _buildInput(_draftFwdController, 'Draft Forward - Fwd (m)'),
                _buildInput(_draftMidController, 'Draft Midship - Mid (m)'),
                _buildInput(_draftAftController, 'Draft Aft - Aft (m)'),
                _buildInput(_kmController, 'KM (m)'),
                _buildInput(_kgController, 'KG (m)'),
                _buildInput(_fscController, 'Free Surface Correction / FSC (m)'),
              ],
            ),

            // 3. Density Settings
            _buildSectionCard(
              title: '3. Density Settings',
              children: [
                _buildInput(_swDensityController, 'Standard SW Density (t/m³)'),
                _buildInput(_dockDensityController, 'Dock Water Density (t/m³)'),
              ],
            ),

            // Calculated Results Card
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    const SizedBox(height: 5),
                    Text('Solid GM: $_calculatedSolidGM'),
                    Text('Fluid GM (GoM): $_calculatedFluidGM', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text('Est. Rolling Period: $_calculatedRollingPeriod', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Buttons: Calculate & Reset
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveToHistory,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('CALCULATE & SAVE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetFields,
                    child: const Text('RESET'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Developer Banner
            const Center(
              child: Text(
                'Developer: Renante Fullo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
