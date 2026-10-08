import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DraftSurveyProApp());
}

class DraftSurveyProApp extends StatelessWidget {
  const DraftSurveyProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Draft Survey Pro',
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            primaryColor: const Color(0xFF0284C7),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: Color(0xFF0284C7),
              unselectedItemColor: Colors.black54,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF131B2E),
            primaryColor: const Color(0xFF38BDF8),
            cardColor: const Color(0xFF1D273D),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1D273D),
              foregroundColor: Colors.white,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1D273D),
              selectedItemColor: Color(0xFF38BDF8),
              unselectedItemColor: Colors.white54,
            ),
          ),
          home: const MainHomeScreen(),
        );
      },
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  void _switchToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = themeNotifier.value == ThemeMode.dark;

    final List<Widget> tabs = [
      const DraftSurveyTab(),
      const TankSoundingTab(),
      HistoryLogTab(onLoadHistoryItem: () => _switchToTab(0)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Draft Survey Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Developer: 2/O Renante Fullo', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
          ],
        ),
        actions: [
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: isDark ? Colors.amber : Colors.orangeAccent,
              ),
              Switch(
                value: isDark,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (bool value) {
                  setState(() {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: 'Draft Survey',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_damage),
            label: 'Tanks Sounding',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History Log',
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> calculationHistory = [];
Function(Map<String, dynamic>)? loadHistoryToSurveyCallback;
Function(double ballast, double vlsfo, double lsmgo, double fw)? updateDeductiblesCallback;

class DraftSurveyTab extends StatefulWidget {
  const DraftSurveyTab({super.key});

  @override
  State<DraftSurveyTab> createState() => _DraftSurveyTabState();
}

class _DraftSurveyTabState extends State<DraftSurveyTab> {
  final _vesselNameController = TextEditingController();
  final _portController = TextEditingController();
  final _chiefOfficerController = TextEditingController();
  final _masterController = TextEditingController();

  final _fwdPortController = TextEditingController();
  final _fwdStbdController = TextEditingController();
  final _midPortController = TextEditingController();
  final _midStbdController = TextEditingController();
  final _aftPortController = TextEditingController();
  final _aftStbdController = TextEditingController();

  final _dockDensityController = TextEditingController(text: '1.025');
  final _waterTempController = TextEditingController(text: '15.0');
  final _lbpController = TextEditingController();
  final _rawDispController = TextEditingController();
  final _lcfController = TextEditingController();
  final _tpcController = TextEditingController();
  final _dMtcController = TextEditingController();

  final _lightshipController = TextEditingController();
  final _ballastController = TextEditingController();
  final _vlsfoController = TextEditingController();
  final _lsmgoController = TextEditingController();
  final _freshWaterController = TextEditingController();

  double meanFwd = 0.0, meanMid = 0.0, meanAft = 0.0;
  double apparentTrim = 0.0, quarterMean = 0.0;
  double ftc = 0.0, stc = 0.0, correctedDisplacement = 0.0;
  double totalDeductibles = 0.0, netCargoDeadweight = 0.0;
  String hullCondition = 'Flat / Normal';
  String surveyStage = 'Initial Survey';

  List<List<double>> _loadedHydroTable = [];
  bool _hasSavedHydroData = false;

  @override
  void initState() {
    super.initState();
    _loadSavedHydrostaticTable();
    loadHistoryToSurveyCallback = _populateFormFromHistory;
    updateDeductiblesCallback = _updateDeductiblesFromTanks;
  }

  void _updateDeductiblesFromTanks(double ballast, double vlsfo, double lsmgo, double fw) {
    setState(() {
      _ballastController.text = ballast.toStringAsFixed(2);
      _vlsfoController.text = vlsfo.toStringAsFixed(2);
      _lsmgoController.text = lsmgo.toStringAsFixed(2);
      _freshWaterController.text = fw.toStringAsFixed(2);
      _calculateSurvey();
    });
  }

  void _populateFormFromHistory(Map<String, dynamic> item) {
    setState(() {
      _vesselNameController.text = item['vessel'] ?? '';
      _portController.text = item['port'] ?? '';
      _chiefOfficerController.text = item['chiefOfficer'] ?? '';
      _masterController.text = item['master'] ?? '';

      _fwdPortController.text = item['fp'] ?? '';
      _fwdStbdController.text = item['fs'] ?? '';
      _midPortController.text = item['mp'] ?? '';
      _midStbdController.text = item['ms'] ?? '';
      _aftPortController.text = item['ap'] ?? '';
      _aftStbdController.text = item['as'] ?? '';

      _rawDispController.text = item['rawDisp'] ?? '';
      _lbpController.text = item['lbp'] ?? '';
      _lcfController.text = item['lcf'] ?? '';
      _tpcController.text = item['tpc'] ?? '';
      _dMtcController.text = item['dMtc'] ?? '';
      _dockDensityController.text = item['dockDensity'] ?? '1.025';

      _lightshipController.text = item['lightship'] ?? '';
      _ballastController.text = item['ballast'] ?? '';
      _vlsfoController.text = item['vlsfo'] ?? '';
      _lsmgoController.text = item['lsmgo'] ?? '';
      _freshWaterController.text = item['fw'] ?? '';

      _calculateSurvey();
    });
  }

  Future<void> _loadSavedHydrostaticTable() async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'saved_hydro_${_vesselNameController.text.trim()}';
    if (key.isEmpty) key = 'saved_hydro_default';

    String? jsonString = prefs.getString(key);
    if (jsonString != null && jsonString.isNotEmpty) {
      List<dynamic> decoded = jsonDecode(jsonString);
      setState(() {
        _loadedHydroTable = decoded.map((row) => List<double>.from(row.map((item) => (item as num).toDouble()))).toList();
        _hasSavedHydroData = _loadedHydroTable.isNotEmpty;
      });
    }
  }

  Future<void> _saveHydrostaticTableToStorage(List<List<double>> table) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'saved_hydro_${_vesselNameController.text.trim()}';
    if (_vesselNameController.text.trim().isEmpty) key = 'saved_hydro_default';

    String jsonString = jsonEncode(table);
    await prefs.setString(key, jsonString);
    setState(() {
      _loadedHydroTable = table;
      _hasSavedHydroData = true;
    });
  }

  void _calculateSurvey() {
    setState(() {
      double fp = double.tryParse(_fwdPortController.text) ?? 0.0;
      double fs = double.tryParse(_fwdStbdController.text) ?? 0.0;
      double mp = double.tryParse(_midPortController.text) ?? 0.0;
      double ms = double.tryParse(_midStbdController.text) ?? 0.0;
      double ap = double.tryParse(_aftPortController.text) ?? 0.0;
      double as = double.tryParse(_aftStbdController.text) ?? 0.0;

      meanFwd = (fp + fs) / 2;
      meanMid = (mp + ms) / 2;
      meanAft = (ap + as) / 2;

      apparentTrim = meanAft - meanFwd;
      quarterMean = (meanFwd + (6 * meanMid) + meanAft) / 8;

      double meanEnds = (meanFwd + meanAft) / 2;
      double hogSagValue = meanMid - meanEnds;
      if (hogSagValue > 0.01) {
        hullCondition = 'Sagging (${hogSagValue.toStringAsFixed(3)} m)';
      } else if (hogSagValue < -0.01) {
        hullCondition = 'Hogging (${hogSagValue.abs().toStringAsFixed(3)} m)';
      } else {
        hullCondition = 'Flat / Normal';
      }

      if (_loadedHydroTable.isNotEmpty) {
        _applyInterpolationFromLoadedTable(quarterMean);
      }

      double rawDisp = double.tryParse(_rawDispController.text) ?? 0.0;
      double lcf = double.tryParse(_lcfController.text) ?? 0.0;
      double tpc = double.tryParse(_tpcController.text) ?? 0.0;
      double lbp = double.tryParse(_lbpController.text) ?? 1.0;
      double dMtc = double.tryParse(_dMtcController.text) ?? 0.0;

      double observedDensity = double.tryParse(_dockDensityController.text) ?? 1.025;
      double temp = double.tryParse(_waterTempController.text) ?? 15.0;
      double tempCorrectedDensity = observedDensity + ((15.0 - temp) * 0.0002);

      ftc = (apparentTrim * lcf * tpc * 100) / (lbp == 0 ? 1 : lbp);
      stc = (apparentTrim * apparentTrim * 50 * dMtc) / (lbp == 0 ? 1 : lbp);

      double trimCorrectedDisp = rawDisp + ftc + stc;
      correctedDisplacement = trimCorrectedDisp * (tempCorrectedDensity / 1.025);

      double lightship = double.tryParse(_lightshipController.text) ?? 0.0;
      double ballast = double.tryParse(_ballastController.text) ?? 0.0;
      double vlsfo = double.tryParse(_vlsfoController.text) ?? 0.0;
      double lsmgo = double.tryParse(_lsmgoController.text) ?? 0.0;
      double fw = double.tryParse(_freshWaterController.text) ?? 0.0;

      totalDeductibles = lightship + ballast + vlsfo + lsmgo + fw;
      netCargoDeadweight = correctedDisplacement - totalDeductibles;

      calculationHistory.insert(0, {
        'timestamp': DateTime.now().toString().substring(0, 16),
        'vessel': _vesselNameController.text.isEmpty ? 'N/A' : _vesselNameController.text,
        'port': _portController.text.isEmpty ? 'N/A' : _portController.text,
        'chiefOfficer': _chiefOfficerController.text,
        'master': _masterController.text,
        'fp': _fwdPortController.text,
        'fs': _fwdStbdController.text,
        'mp': _midPortController.text,
        'ms': _midStbdController.text,
        'ap': _aftPortController.text,
        'as': _aftStbdController.text,
        'rawDisp': _rawDispController.text,
        'lbp': _lbpController.text,
        'lcf': _lcfController.text,
        'tpc': _tpcController.text,
        'dMtc': _dMtcController.text,
        'dockDensity': _dockDensityController.text,
        'lightship': _lightshipController.text,
        'ballast': _ballastController.text,
        'vlsfo': _vlsfoController.text,
        'lsmgo': _lsmgoController.text,
        'fw': _freshWaterController.text,
        'quarterMean': quarterMean,
        'correctedDisp': correctedDisplacement,
        'netCargo': netCargoDeadweight,
      });
    });
  }

  void _resetFields() {
    setState(() {
      _vesselNameController.clear();
      _portController.clear();
      _chiefOfficerController.clear();
      _masterController.clear();
      _fwdPortController.clear();
      _fwdStbdController.clear();
      _midPortController.clear();
      _midStbdController.clear();
      _aftPortController.clear();
      _aftStbdController.clear();
      _rawDispController.clear();
      _lbpController.clear();
      _lcfController.clear();
      _tpcController.clear();
      _dMtcController.clear();
      _lightshipController.clear();
      _ballastController.clear();
      _vlsfoController.clear();
      _lsmgoController.clear();
      _freshWaterController.clear();

      meanFwd = meanMid = meanAft = 0.0;
      apparentTrim = quarterMean = ftc = stc = 0.0;
      correctedDisplacement = totalDeductibles = netCargoDeadweight = 0.0;
    });
  }

  double _interpolate(double x, double x1, double x2, double y1, double y2) {
    if (x2 == x1) return y1;
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
  }

  void _applyInterpolationFromLoadedTable(double targetDraft) {
    if (_loadedHydroTable.isEmpty || targetDraft <= 0) return;

    List<List<double>> table = List.from(_loadedHydroTable);
    table.sort((a, b) => a[0].compareTo(b[0]));

    if (targetDraft <= table.first[0]) {
      var r = table.first;
      _rawDispController.text = r[1].toStringAsFixed(2);
      _lbpController.text = r[2].toStringAsFixed(2);
      _lcfController.text = r[3].toStringAsFixed(2);
      _tpcController.text = r[4].toStringAsFixed(2);
      _dMtcController.text = r[5].toStringAsFixed(2);
    } else if (targetDraft >= table.last[0]) {
      var r = table.last;
      _rawDispController.text = r[1].toStringAsFixed(2);
      _lbpController.text = r[2].toStringAsFixed(2);
      _lcfController.text = r[3].toStringAsFixed(2);
      _tpcController.text = r[4].toStringAsFixed(2);
      _dMtcController.text = r[5].toStringAsFixed(2);
    } else {
      for (int i = 0; i < table.length - 1; i++) {
        double d1 = table[i][0];
        double d2 = table[i + 1][0];

        if (targetDraft >= d1 && targetDraft <= d2) {
          _rawDispController.text = _interpolate(targetDraft, d1, d2, table[i][1], table[i + 1][1]).toStringAsFixed(2);
          _lbpController.text = _interpolate(targetDraft, d1, d2, table[i][2], table[i + 1][2]).toStringAsFixed(2);
          _lcfController.text = _interpolate(targetDraft, d1, d2, table[i][3], table[i + 1][3]).toStringAsFixed(3);
          _tpcController.text = _interpolate(targetDraft, d1, d2, table[i][4], table[i + 1][4]).toStringAsFixed(2);
          _dMtcController.text = _interpolate(targetDraft, d1, d2, table[i][5], table[i + 1][5]).toStringAsFixed(2);
          break;
        }
      }
    }
  }

  Future<void> _importExcelHydrostatic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      List<List<double>> tempTable = [];

      try {
        if (filePath.endsWith('.csv')) {
          final input = File(filePath).readAsStringSync();
          List<String> lines = const LineSplitter().convert(input);
          for (int i = 1; i < lines.length; i++) {
            List<String> cols = lines[i].split(',');
            if (cols.length >= 6) {
              double? d = double.tryParse(cols[0].trim());
              double? disp = double.tryParse(cols[1].trim());
              double? lbp = double.tryParse(cols[2].trim());
              double? lcf = double.tryParse(cols[3].trim());
              double? tpc = double.tryParse(cols[4].trim());
              double? dmtc = double.tryParse(cols[5].trim());
              if (d != null && disp != null && lbp != null && lcf != null && tpc != null && dmtc != null) {
                tempTable.add([d, disp, lbp, lcf, tpc, dmtc]);
              }
            }
          }
        } else {
          var bytes = File(filePath).readAsBytesSync();
          var excel = Excel.decodeBytes(bytes);

          for (var tableName in excel.tables.keys) {
            var sheet = excel.tables[tableName];
            if (sheet != null && sheet.maxRows > 1) {
              for (int i = 1; i < sheet.maxRows; i++) {
                var row = sheet.rows[i];
                if (row.length >= 6) {
                  double? d = double.tryParse(row[0]?.value?.toString() ?? '');
                  double? disp = double.tryParse(row[1]?.value?.toString() ?? '');
                  double? lbp = double.tryParse(row[2]?.value?.toString() ?? '');
                  double? lcf = double.tryParse(row[3]?.value?.toString() ?? '');
                  double? tpc = double.tryParse(row[4]?.value?.toString() ?? '');
                  double? dmtc = double.tryParse(row[5]?.value?.toString() ?? '');
                  if (d != null && disp != null && lbp != null && lcf != null && tpc != null && dmtc != null) {
                    tempTable.add([d, disp, lbp, lcf, tpc, dmtc]);
                  }
                }
              }
              break;
            }
          }
        }

        if (tempTable.isNotEmpty) {
          await _saveHydrostaticTableToStorage(tempTable);
          _calculateSurvey();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hydrostatic table saved to Vessel Profile!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading file: $e')),
        );
      }
    }
  }

  Future<void> _exportExcelReport() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Draft Survey Report'];
    excel.delete('Sheet1');

    sheetObject.appendRow([TextCellValue('DRAFT SURVEY REPORT')]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([TextCellValue('Vessel Name'), TextCellValue(_vesselNameController.text)]);
    sheetObject.appendRow([TextCellValue('Port'), TextCellValue(_portController.text)]);
    sheetObject.appendRow([TextCellValue('Quarter Mean Draft'), TextCellValue(quarterMean.toStringAsFixed(3))]);
    sheetObject.appendRow([TextCellValue('Corrected Displacement'), TextCellValue(correctedDisplacement.toStringAsFixed(2))]);
    sheetObject.appendRow([TextCellValue('Net Cargo Deadweight'), TextCellValue(netCargoDeadweight.toStringAsFixed(2))]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([TextCellValue('Chief Officer'), TextCellValue(_chiefOfficerController.text)]);
    sheetObject.appendRow([TextCellValue('Master'), TextCellValue(_masterController.text)]);

    Directory tempDir = await getTemporaryDirectory();
    String filePath = "${tempDir.path}/Draft_Survey_Export.xlsx";
    File file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(excel.encode()!);

    await Share.shareXFiles([XFile(filePath)], text: 'Draft Survey Excel Export');
  }

  Future<pw.Document> _generatePdfReport() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.1,
                  child: pw.Text(
                    surveyStage.toUpperCase(),
                    style: pw.TextStyle(fontSize: 50, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text('DRAFT SURVEY REPORT', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Center(
                      child: pw.Text(surveyStage, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Vessel: ${_vesselNameController.text}'),
                        pw.Text('Port: ${_portController.text}'),
                        pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
                      ],
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text('1. DRAFT OBSERVATIONS & HULL CONDITION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Bullet(text: 'Quarter Mean Draft: ${quarterMean.toStringAsFixed(3)} m'),
                    pw.Bullet(text: 'Apparent Trim: ${apparentTrim.toStringAsFixed(3)} m'),
                    pw.Bullet(text: 'Hull Condition: $hullCondition'),
                    pw.SizedBox(height: 15),
                    pw.Text('2. DISPLACEMENT & CORRECTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Bullet(text: 'FTC: ${ftc.toStringAsFixed(2)} MT | STC: ${stc.toStringAsFixed(2)} MT'),
                    pw.Bullet(text: 'Corrected Displacement: ${correctedDisplacement.toStringAsFixed(2)} MT'),
                    pw.SizedBox(height: 15),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('NET CARGO DEADWEIGHT:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                          pw.Text('${netCargoDeadweight.toStringAsFixed(2)} MT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    pw.Spacer(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(width: 180, child: pw.Divider(thickness: 1)),
                            pw.SizedBox(height: 4),
                            pw.Text('Chief Officer: ${_chiefOfficerController.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(width: 180, child: pw.Divider(thickness: 1)),
                            pw.SizedBox(height: 4),
                            pw.Text('Master: ${_masterController.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _printReport() async {
    final pdf = await _generatePdfReport();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _saveAndSharePdf() async {
    final pdf = await _generatePdfReport();
    final bytes = await pdf.save();
    Directory tempDir = await getTemporaryDirectory();
    String filePath = "${tempDir.path}/Draft_Survey_Report.pdf";
    File file = File(filePath);
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], text: 'Draft Survey Report');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final primaryBlue = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final buttonBlue = isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            title: '1. Vessel Profile & Survey Stage',
            primaryColor: primaryBlue,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      _vesselNameController,
                      'Vessel Name',
                      primaryBlue,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => _loadSavedHydrostaticTable(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInputField(
                      _portController,
                      'Port',
                      primaryBlue,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: surveyStage,
                decoration: const InputDecoration(labelText: 'Survey Stage / PDF Watermark'),
                items: ['Initial Survey', 'Intermediate Survey', 'Final Survey'].map((stage) {
                  return DropdownMenuItem(value: stage, child: Text(stage));
                }).toList(),
                onChanged: (val) => setState(() => surveyStage = val!),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      _chiefOfficerController,
                      'Chief Officer',
                      primaryBlue,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInputField(
                      _masterController,
                      'Master Name',
                      primaryBlue,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildSectionCard(
            title: '2. Draft Observations (m)',
            primaryColor: primaryBlue,
            children: [
              Row(
                children: [
                  Expanded(child: _buildInputField(_fwdPortController, 'Fwd Port', primaryBlue)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_fwdStbdController, 'Fwd Stbd', primaryBlue)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildInputField(_midPortController, 'Mid Port', primaryBlue)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_midStbdController, 'Mid Stbd', primaryBlue)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildInputField(_aftPortController, 'Aft Port', primaryBlue)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_aftStbdController, 'Aft Stbd', primaryBlue)),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hull Condition:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(hullCondition, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryBlue)),
                  ],
                ),
              ),
            ],
          ),
          _buildSectionCard(
            title: '3. Hydrostatics & Water Density',
            primaryColor: primaryBlue,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _importExcelHydrostatic,
                      icon: const Icon(Icons.file_upload, color: Colors.white),
                      label: Text(_hasSavedHydroData ? 'CHANGE HYDROSTATIC EXCEL' : 'IMPORT HYDROSTATIC EXCEL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasSavedHydroData ? Colors.orange.shade800 : Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildInputField(_dockDensityController, 'Dock Density (t/m³)', primaryBlue)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_waterTempController, 'Water Temp (°C)', primaryBlue)),
                ],
              ),
              _buildInputField(_rawDispController, 'Table Displacement (MT)', primaryBlue),
              _buildInputField(_lbpController, 'LBP (m)', primaryBlue),
              _buildInputField(_lcfController, 'LCF (m)', primaryBlue),
              _buildInputField(_tpcController, 'TPC (Tons/cm)', primaryBlue),
              _buildInputField(_dMtcController, 'dMTC', primaryBlue),
            ],
          ),
          _buildSectionCard(
            title: '4. Deductibles (MT)',
            primaryColor: primaryBlue,
            children: [
              _buildInputField(_lightshipController, 'Lightship / Lightweight', primaryBlue),
              _buildInputField(_ballastController, 'Ballast Water', primaryBlue),
              _buildInputField(_vlsfoController, 'VLSFO / Fuel Oil', primaryBlue),
              _buildInputField(_lsmgoController, 'LSMGO / Diesel Oil', primaryBlue),
              _buildInputField(_freshWaterController, 'Fresh Water', primaryBlue),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _calculateSurvey,
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text('CALCULATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetFields,
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  label: const Text('CLEAR ALL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // PRINT, EXPORT EXCEL, AT SAVE PDF BUTTONS (BINANSA PABALIK DITO)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _printReport,
                  icon: Icon(Icons.print, color: primaryBlue),
                  label: Text('PRINT REPORT', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportExcelReport,
                  icon: const Icon(Icons.download, color: Colors.green),
                  label: const Text('EXPORT EXCEL', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveAndSharePdf,
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  label: const Text('SAVE PDF', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: 'RESULTS OUTPUT',
            primaryColor: primaryBlue,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildResultTile('Quarter Mean', '${quarterMean.toStringAsFixed(3)} m', primaryBlue),
                  _buildResultTile('Apparent Trim', '${apparentTrim.toStringAsFixed(3)} m', primaryBlue),
                  _buildResultTile('1st Correction (FTC)', '${ftc.toStringAsFixed(2)} MT', primaryBlue),
                  _buildResultTile('2nd Correction (STC)', '${stc.toStringAsFixed(2)} MT', primaryBlue),
                  _buildResultTile('Corrected Disp', '${correctedDisplacement.toStringAsFixed(2)} MT', primaryBlue),
                  _buildResultTile('Total Deductibles', '${totalDeductibles.toStringAsFixed(2)} MT', primaryBlue),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NET CARGO DEADWEIGHT', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${netCargoDeadweight.toStringAsFixed(2)} MT',
                      style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Color primaryColor, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    Color primaryColor, {
    TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
    TextCapitalization textCapitalization = TextCapitalization.none,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          filled: true,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: primaryColor)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildResultTile(String title, String value, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: primaryColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class TankSoundingTab extends StatefulWidget {
  const TankSoundingTab({super.key});

  @override
  State<TankSoundingTab> createState() => _TankSoundingTabState();
}

class _TankSoundingTabState extends State<TankSoundingTab> {
  final _ballastController = TextEditingController();
  final _vlsfoController = TextEditingController();
  final _lsmgoController = TextEditingController();
  final _fwController = TextEditingController();

  void _showTankFormatGuide() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text('Tank Excel Format Guide', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Format your Excel (.xlsx) or CSV file with 4 columns starting from Row 2 (Row 1 is Header):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('Col A (1): Ballast Water Total (MT)'),
                Text('Col B (2): VLSFO Total (MT)'),
                Text('Col C (3): LSMGO Total (MT)'),
                Text('Col D (4): Fresh Water Total (MT)'),
                SizedBox(height: 15),
                Text(
                  'Sample Data (Row 2):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                Text('14250.50, 420.25, 85.10, 110.00', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('GOT IT'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importTankExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;

      try {
        if (filePath.endsWith('.csv')) {
          final input = File(filePath).readAsStringSync();
          List<String> lines = const LineSplitter().convert(input);
          if (lines.length > 1) {
            List<String> cols = lines[1].split(',');
            setState(() {
              if (cols.isNotEmpty) _ballastController.text = cols[0].trim();
              if (cols.length > 1) _vlsfoController.text = cols[1].trim();
              if (cols.length > 2) _lsmgoController.text = cols[2].trim();
              if (cols.length > 3) _fwController.text = cols[3].trim();
            });
          }
        } else {
          var bytes = File(filePath).readAsBytesSync();
          var excel = Excel.decodeBytes(bytes);

          for (var tableName in excel.tables.keys) {
            var sheet = excel.tables[tableName];
            if (sheet != null && sheet.maxRows > 1) {
              var row = sheet.rows[1];
              setState(() {
                if (row.isNotEmpty && row[0]?.value != null) _ballastController.text = row[0]!.value.toString();
                if (row.length > 1 && row[1]?.value != null) _vlsfoController.text = row[1]!.value.toString();
                if (row.length > 2 && row[2]?.value != null) _lsmgoController.text = row[2]!.value.toString();
                if (row.length > 3 && row[3]?.value != null) _fwController.text = row[3]!.value.toString();
              });
              break;
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tank quantities imported successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading Excel: $e')),
        );
      }
    }
  }

  void _syncWithSurvey() {
    double totalBallast = double.tryParse(_ballastController.text) ?? 0.0;
    double totalVlsfo = double.tryParse(_vlsfoController.text) ?? 0.0;
    double totalLsmgo = double.tryParse(_lsmgoController.text) ?? 0.0;
    double totalFw = double.tryParse(_fwController.text) ?? 0.0;

    if (updateDeductiblesCallback != null) {
      updateDeductiblesCallback!(totalBallast, totalVlsfo, totalLsmgo, totalFw);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tank totals transferred to Draft Survey Deductibles!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tank Sounding / Deductibles Input (MT)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importTankExcel,
                  icon: const Icon(Icons.file_upload, color: Colors.white),
                  label: const Text('IMPORT TANK SOUNDING EXCEL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showTankFormatGuide,
                icon: const Icon(Icons.info_outline, color: Colors.teal),
                tooltip: 'Format Guide',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          const Text('Or Enter Totals Manually:', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 10),
          TextField(controller: _ballastController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total Ballast Water (MT)')),
          TextField(controller: _vlsfoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total VLSFO / Fuel Oil (MT)')),
          TextField(controller: _lsmgoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total LSMGO / Diesel Oil (MT)')),
          TextField(controller: _fwController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total Fresh Water (MT)')),
          
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _syncWithSurvey,
            icon: const Icon(Icons.sync),
            label: const Text('TRANSFER TOTALS TO DRAFT SURVEY'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF0284C7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryLogTab extends StatefulWidget {
  final VoidCallback onLoadHistoryItem;
  const HistoryLogTab({super.key, required this.onLoadHistoryItem});

  @override
  State<HistoryLogTab> createState() => _HistoryLogTabState();
}

class _HistoryLogTabState extends State<HistoryLogTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation History Log', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () => setState(() => calculationHistory.clear()),
          )
        ],
      ),
      body: calculationHistory.isEmpty
          ? const Center(child: Text('No History Logs Available', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: calculationHistory.length,
              itemBuilder: (context, index) {
                final item = calculationHistory[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    onTap: () {
                      if (loadHistoryToSurveyCallback != null) {
                        loadHistoryToSurveyCallback!(item);
                        widget.onLoadHistoryItem();
                      }
                    },
                    title: Text('${item['vessel']} - ${item['port']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Date: ${item['timestamp']}\nCargo: ${item['netCargo'].toStringAsFixed(2)} MT\n(Tap to Load & Edit)'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => calculationHistory.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}