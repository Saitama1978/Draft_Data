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
      title: 'Ship Stability Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _controllers = <String, TextEditingController>{};

  final fields = [
    'lightship', 'disp', 'depth', 'mastHeight', 'beam', 'tpc',
    'dfwd', 'daft', 'km', 'kg', 'fsc', 'swDensity', 'dockDensity'
  ];

  // Calculated values
  double meanDraft = 0, trim = 0, freeboard = 0, airDraft = 0;
  double dwt = 0, gm = 0, gom = 0, rollPeriod = 0;
  double draftChangeMeters = 0, newMeanDraft = 0;

  @override
  void initState() {
    super.initState();
    for (var key in fields) {
      _controllers[key] = TextEditingController();
    }
    _controllers['swDensity']?.text = '1.025';
    _controllers['fsc']?.text = '0';
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var key in fields) {
        String? val = prefs.getString('ship_$key');
        if (val != null && val.isNotEmpty) {
          _controllers[key]?.text = val;
        }
      }
    });
    _calculate();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in fields) {
      await prefs.setString('ship_$key', _controllers[key]?.text ?? '');
    }
  }

  void _calculate() {
    _saveData();

    double parse(String key) => double.tryParse(_controllers[key]?.text ?? '') ?? 0.0;

    final lightship = parse('lightship');
    final disp = parse('disp');
    final depth = parse('depth');
    final mastHeight = parse('mastHeight');
    final beam = parse('beam');
    final tpc = parse('tpc');
    final dfwd = parse('dfwd');
    final daft = parse('daft');
    final km = parse('km');
    final kg = parse('kg');
    final fsc = parse('fsc');
    final swDensity = parse('swDensity') == 0 ? 1.025 : parse('swDensity');
    final dockDensity = parse('dockDensity');

    setState(() {
      meanDraft = (dfwd + daft) / 2;
      trim = daft - dfwd;
      freeboard = depth > 0 ? depth - meanDraft : 0;
      airDraft = mastHeight > 0 ? mastHeight - meanDraft : 0;
      dwt = disp > lightship ? disp - lightship : 0;
      gm = km - kg;
      gom = gm - fsc;

      if (beam > 0 && gom > 0) {
        rollPeriod = (0.8 * beam) / sqrt(gom);
      } else {
        rollPeriod = 0;
      }

      if (dockDensity > 0 && tpc > 0 && disp > 0) {
        double draftChangeCm = (disp * (swDensity - dockDensity)) / (tpc * dockDensity);
        draftChangeMeters = draftChangeCm / 100;
        newMeanDraft = meanDraft + draftChangeMeters;
      } else {
        draftChangeMeters = 0;
        newMeanDraft = 0;
      }
    });
  }

  void _reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in fields) {
      await prefs.remove('ship_$key');
      _controllers[key]?.clear();
    }
    _controllers['swDensity']?.text = '1.025';
    _controllers['fsc']?.text = '0';
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ship Stability Calculator'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSectionCard('1. Particulars & Hydrostatics', [
              _buildInput('Lightship / Lightweight (MT)', 'lightship'),
              _buildInput('Current Displacement (MT)', 'disp'),
              _buildInput('Moulded Depth - D (m)', 'depth'),
              _buildInput('Keel to Mast Height - H (m)', 'mastHeight'),
              _buildInput('Beam - B (m)', 'beam'),
              _buildInput('TPC (Tons/cm)', 'tpc'),
            ]),
            _buildSectionCard('2. Draft & Hydrostatic Values', [
              _buildInput('Draft Forward - Fwd (m)', 'dfwd'),
              _buildInput('Draft Aft - Aft (m)', 'daft'),
              _buildInput('KM (m)', 'km'),
              _buildInput('KG (m)', 'kg'),
              _buildInput('Free Surface Correction / FSC (m)', 'fsc'),
            ]),
            _buildSectionCard('3. Density Settings', [
              _buildInput('Standard SW Density (t/m³)', 'swDensity'),
              _buildInput('Dock Water Density (t/m³)', 'dockDensity'),
            ]),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _calculate,
                    child: const Text('CALCULATE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _reset,
                    child: const Text('RESET'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
            const Divider(color: Colors.white24, height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: children),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, String key) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 4),
          TextField(
            controller: _controllers[key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
            onChanged: (_) => _calculate(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RESULTS OUTPUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
            const Divider(color: Colors.white24, height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildResultBox('Mean Draft', '${meanDraft.toStringAsFixed(3)} m'),
                _buildResultBox('Trim (+Aft / -Fwd)', '${trim >= 0 ? "+" : ""}${trim.toStringAsFixed(3)} m'),
                _buildResultBox('Freeboard', '${freeboard.toStringAsFixed(3)} m'),
                _buildResultBox('Air Draft', '${airDraft.toStringAsFixed(3)} m'),
                _buildResultBox('Deadweight (DWT)', '${dwt.toStringAsFixed(2)} MT', isHighlight: true),
                _buildResultBox('Solid GM', '${gm.toStringAsFixed(3)} m'),
                _buildResultBox('Fluid GM (GoM)', '${gom.toStringAsFixed(3)} m', isHighlight: true),
                _buildResultBox('Rolling Period (T)', '${rollPeriod.toStringAsFixed(2)} sec'),
                _buildResultBox('Draft Change (Dock)', '${(draftChangeMeters * 100).toStringAsFixed(2)} cm'),
                _buildResultBox('New Draft in Dock', '${newMeanDraft.toStringAsFixed(3)} m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBox(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: isHighlight ? Colors.greenAccent : const Color(0xFF38BDF8), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: ColorScheme.dark().surface == const Color(0xFF1E293B) ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
