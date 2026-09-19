import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ShipCalculatorApp());
}

class ShipCalculatorApp extends StatefulWidget {
  const ShipCalculatorApp({super.key});

  @override
  State<ShipCalculatorApp> createState() => _ShipCalculatorAppState();
}

class _ShipCalculatorAppState extends State<ShipCalculatorApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ship Stability Calculator',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0284C7),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: CalculatorScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const CalculatorScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _controllers = <String, TextEditingController>{};

  final fields = [
    'lightship', 'disp', 'depth', 'mastHeight', 'beam', 'tpc',
    'dfwd', 'daft', 'km', 'kg', 'fsm', 'swDensity', 'dockDensity'
  ];

  // Calculated values
  double meanDraft = 0, trim = 0, freeboard = 0, airDraft = 0;
  double dwt = 0, gm = 0, gom = 0, rollPeriod = 0;
  double draftChangeMeters = 0, newMeanDraft = 0;

  List<Map<String, String>> _savedHistory = [];

  @override
  void initState() {
    super.initState();
    for (var key in fields) {
      _controllers[key] = TextEditingController();
    }
    _controllers['swDensity']?.text = '1.025';
    _controllers['fsm']?.text = '0';
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('ship_history_records');
    if (historyJson != null) {
      setState(() {
        List<dynamic> decoded = jsonDecode(historyJson);
        _savedHistory = decoded.map((e) => Map<String, String>.from(e)).toList();
      });
    }
    _calculate();
  }

  Future<void> _saveCurrentRecord() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> newRecord = {
      'timestamp': DateTime.now().toString().substring(0, 16),
    };

    for (var key in fields) {
      newRecord[key] = _controllers[key]?.text ?? '';
    }

    setState(() {
      _savedHistory.insert(0, newRecord);
    });

    await prefs.setString('ship_history_records', jsonEncode(_savedHistory));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Successfully saved to history!')),
    );
  }

  Future<void> _deleteRecord(int index, StateSetter setDialogState) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedHistory.removeAt(index);
    });
    setDialogState(() {});
    await prefs.setString('ship_history_records', jsonEncode(_savedHistory));
  }

  void _loadRecordToFields(Map<String, String> record) {
    setState(() {
      for (var key in fields) {
        _controllers[key]?.text = record[key] ?? '';
      }
      _calculate();
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record loaded to calculator!')),
    );
  }

  void _calculate() {
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
    final fsm = parse('fsm'); // Total FSM in MT.m
    final swDensity = parse('swDensity') == 0 ? 1.025 : parse('swDensity');
    final dockDensity = parse('dockDensity');

    setState(() {
      meanDraft = (dfwd + daft) / 2;
      trim = daft - dfwd;
      freeboard = depth > 0 ? depth - meanDraft : 0;
      airDraft = mastHeight > 0 ? mastHeight - meanDraft : 0;
      dwt = disp > lightship ? disp - lightship : 0;
      
      gm = km - kg;
      
      // FSC = Total FSM / Displacement
      double fsc = disp > 0 ? (fsm / disp) : 0.0;
      gom = gm - fsc;

      if (beam > 0 && gom > 0) {
        rollPeriod = (0.8 * beam) / sqrt(gom);
      } else {
        rollPeriod = 0;
      }

      // Draft Change with Fallback
      final effectiveDockDensity = dockDensity > 0 ? dockDensity : swDensity;

      if (disp > 0 && effectiveDockDensity != swDensity) {
        if (tpc > 0) {
          double draftChangeCm = (disp * (swDensity - effectiveDockDensity)) / (tpc * effectiveDockDensity);
          draftChangeMeters = draftChangeCm / 100;
        } else {
          double estimatedFwaMeters = (disp / 10000) * 0.05;
          draftChangeMeters = estimatedFwaMeters * ((swDensity - effectiveDockDensity) / 0.025);
        }
        newMeanDraft = meanDraft + draftChangeMeters;
      } else {
        draftChangeMeters = 0;
        newMeanDraft = meanDraft;
      }
    });
  }

  void _reset() {
    setState(() {
      for (var key in fields) {
        _controllers[key]?.clear();
      }
      _controllers['swDensity']?.text = '1.025';
      _controllers['fsm']?.text = '0';
      _calculate();
    });
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Saved Calculations'),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: _savedHistory.isEmpty
                  ? const Center(child: Text('No saved records found.'))
                  : ListView.builder(
                      itemCount: _savedHistory.length,
                      itemBuilder: (context, index) {
                        final item = _savedHistory[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              'Date: ${item['timestamp']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              'Fwd/Aft: ${item['dfwd'] ?? '0'}m / ${item['daft'] ?? '0'}m | Disp: ${item['disp'] ?? '0'} MT',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.lightBlue),
                                  tooltip: 'Load & Edit',
                                  onPressed: () => _loadRecordToFields(item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteRecord(index, setDialogState),
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
        title: const Text('Ship Stability Calculator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: _showHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Record',
            onPressed: _saveCurrentRecord,
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Light/Dark Mode',
            onPressed: widget.onToggleTheme,
          ),
        ],
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
              _buildInput('Total FSM (MT·m)', 'fsm'), // NABAGO NA ANG LABEL SA FSM
            ]),
            _buildSectionCard('3. Density Settings', [
              _buildInput('Standard SW Density (t/m³)', 'swDensity'),
              _buildInput('Dock Water Density (t/m³)', 'dockDensity'),
            ]),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saveCurrentRecord,
                    icon: const Icon(Icons.save),
                    label: const Text('CALCULATE & SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isDarkMode ? Colors.blueGrey.shade700 : Colors.grey.shade400,
                      foregroundColor: widget.isDarkMode ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('RESET'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultsCard(),
            const SizedBox(height: 24),
            Text(
              'Developed by: Renante Fullo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.white54 : Colors.black45,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title, 
              style: TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 20),
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
          Text(label, style: TextStyle(fontSize: 11, color: widget.isDarkMode ? Colors.white70 : Colors.black87)),
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RESULTS OUTPUT', 
              style: TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 20),
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
        color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: isHighlight 
                ? (widget.isDarkMode ? Colors.greenAccent : Colors.green) 
                : Theme.of(context).colorScheme.primary, 
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
