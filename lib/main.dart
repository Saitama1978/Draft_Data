import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DraftSurveyProApp());
}

class DraftSurveyProApp extends StatelessWidget {
  const DraftSurveyProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Draft Survey Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF131B2E),
        primaryColor: const Color(0xFF38BDF8),
        cardColor: const Color(0xFF1D273D),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const DraftSurveyTab(),
    const HistoryLogTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D273D),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Draft Survey Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Developer: 2/O Renante Fullo', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
          ],
        ),
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1D273D),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.white54,
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
            icon: Icon(Icons.history),
            label: 'History Log',
          ),
        ],
      ),
    );
  }
}

// Global Storage para sa History Logs
List<Map<String, dynamic>> calculationHistory = [];

class DraftSurveyTab extends StatefulWidget {
  const DraftSurveyTab({Key? key}) : super(key: key);

  @override
  State<DraftSurveyTab> createState() => _DraftSurveyTabState();
}

class _DraftSurveyTabState extends State<DraftSurveyTab> {
  final Color bgColor = const Color(0xFF131B2E);
  final Color cardColor = const Color(0xFF1D273D);
  final Color primaryBlue = const Color(0xFF38BDF8);
  final Color buttonBlue = const Color(0xFF2563EB);

  // Controllers
  final _vesselNameController = TextEditingController();
  final _portController = TextEditingController();

  final _fwdPortController = TextEditingController();
  final _fwdStbdController = TextEditingController();
  final _midPortController = TextEditingController();
  final _midStbdController = TextEditingController();
  final _aftPortController = TextEditingController();
  final _aftStbdController = TextEditingController();

  final _dockDensityController = TextEditingController(text: '1.025');
  final _lbpController = TextEditingController();
  final _rawDispController = TextEditingController();
  final _lcfController = TextEditingController();
  final _tpcController = TextEditingController();
  final _dMtcController = TextEditingController();

  final _lightshipController = TextEditingController();
  final _ballastController = TextEditingController();
  final _vlsfoController = TextEditingController();
  final _lsmgoController = TextEditingController();
  final _mgoController = TextEditingController();

  double meanFwd = 0.0, meanMid = 0.0, meanAft = 0.0;
  double apparentTrim = 0.0, quarterMean = 0.0;
  double ftc = 0.0, stc = 0.0, correctedDisplacement = 0.0;
  double totalDeductibles = 0.0, netCargoDeadweight = 0.0;

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

      double rawDisp = double.tryParse(_rawDispController.text) ?? 0.0;
      double lcf = double.tryParse(_lcfController.text) ?? 0.0;
      double tpc = double.tryParse(_tpcController.text) ?? 0.0;
      double lbp = double.tryParse(_lbpController.text) ?? 1.0;
      double dMtc = double.tryParse(_dMtcController.text) ?? 0.0;
      double dockDensity = double.tryParse(_dockDensityController.text) ?? 1.025;

      ftc = (apparentTrim * lcf * tpc * 100) / (lbp == 0 ? 1 : lbp);
      stc = (apparentTrim * apparentTrim * 50 * dMtc) / (lbp == 0 ? 1 : lbp);

      double trimCorrectedDisp = rawDisp + ftc + stc;
      correctedDisplacement = trimCorrectedDisp * (dockDensity / 1.025);

      double lightship = double.tryParse(_lightshipController.text) ?? 0.0;
      double ballast = double.tryParse(_ballastController.text) ?? 0.0;
      double vlsfo = double.tryParse(_vlsfoController.text) ?? 0.0;
      double lsmgo = double.tryParse(_lsmgoController.text) ?? 0.0;
      double mgo = double.tryParse(_mgoController.text) ?? 0.0;

      totalDeductibles = lightship + ballast + vlsfo + lsmgo + mgo;
      netCargoDeadweight = correctedDisplacement - totalDeductibles;

      // Save to History Log
      calculationHistory.insert(0, {
        'timestamp': DateTime.now().toString().substring(0, 16),
        'vessel': _vesselNameController.text.isEmpty ? 'N/A' : _vesselNameController.text,
        'port': _portController.text.isEmpty ? 'N/A' : _portController.text,
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
      _mgoController.clear();

      meanFwd = meanMid = meanAft = 0.0;
      apparentTrim = quarterMean = ftc = stc = 0.0;
      correctedDisplacement = totalDeductibles = netCargoDeadweight = 0.0;
    });
  }

  // Hydrostatic Table Excel Import
  Future<void> _importExcelHydrostatic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet != null && sheet.maxRows > 1) {
          var row = sheet.rows[1];
          setState(() {
            if (row.length > 0 && row[0]?.value != null) _rawDispController.text = row[0]!.value.toString();
            if (row.length > 1 && row[1]?.value != null) _lbpController.text = row[1]!.value.toString();
            if (row.length > 2 && row[2]?.value != null) _lcfController.text = row[2]!.value.toString();
            if (row.length > 3 && row[3]?.value != null) _tpcController.text = row[3]!.value.toString();
            if (row.length > 4 && row[4]?.value != null) _dMtcController.text = row[4]!.value.toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hydrostatic data loaded successfully!')),
          );
          break;
        }
      }
    }
  }

  // Export Data to Excel
  Future<void> _exportExcelReport() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Draft Survey Report'];
    excel.delete('Sheet1');

    sheetObject.appendRow([TextCellValue('Draft Survey Report - Draft Survey Pro')]);
    sheetObject.appendRow([TextCellValue('Developer: 2/O Renante Fullo')]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([TextCellValue('Vessel Name'), TextCellValue(_vesselNameController.text)]);
    sheetObject.appendRow([TextCellValue('Port'), TextCellValue(_portController.text)]);
    sheetObject.appendRow([TextCellValue('Quarter Mean Draft'), TextCellValue(quarterMean.toStringAsFixed(3))]);
    sheetObject.appendRow([TextCellValue('Corrected Displacement'), TextCellValue(correctedDisplacement.toStringAsFixed(2))]);
    sheetObject.appendRow([TextCellValue('Net Cargo Deadweight'), TextCellValue(netCargoDeadweight.toStringAsFixed(2))]);

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
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('DRAFT SURVEY REPORT', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text('Draft Survey Pro | Dev: 2/O Renante Fullo', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
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
                pw.Text('1. DRAFT OBSERVATIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Bullet(text: 'Quarter Mean Draft: ${quarterMean.toStringAsFixed(3)} m'),
                pw.Bullet(text: 'Apparent Trim: ${apparentTrim.toStringAsFixed(3)} m'),
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
              ],
            ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            title: '1. Vessel Particulars & Port',
            children: [
              Row(
                children: [
                  Expanded(child: _buildInputField(_vesselNameController, 'Vessel Name')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_portController, 'Port')),
                ],
              ),
            ],
          ),
          _buildSectionCard(
            title: '2. Draft Observations (m)',
            children: [
              Row(
                children: [
                  Expanded(child: _buildInputField(_fwdPortController, 'Fwd Port')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_fwdStbdController, 'Fwd Stbd')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildInputField(_midPortController, 'Mid Port')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_midStbdController, 'Mid Stbd')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildInputField(_aftPortController, 'Aft Port')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField(_aftStbdController, 'Aft Stbd')),
                ],
              ),
            ],
          ),
          _buildSectionCard(
            title: '3. Hydrostatics & Density',
            children: [
              ElevatedButton.icon(
                onPressed: _importExcelHydrostatic,
                icon: const Icon(Icons.file_upload, color: Colors.white),
                label: const Text('IMPORT HYDROSTATIC EXCEL'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
              const SizedBox(height: 10),
              _buildInputField(_rawDispController, 'Table Displacement (MT)'),
              _buildInputField(_lbpController, 'LBP (m)'),
              _buildInputField(_lcfController, 'LCF (m)'),
              _buildInputField(_tpcController, 'TPC (Tons/cm)'),
              _buildInputField(_dMtcController, 'dMTC'),
              _buildInputField(_dockDensityController, 'Dock Water Density (t/m³)'),
            ],
          ),
          _buildSectionCard(
            title: '4. Deductibles (MT)',
            children: [
              _buildInputField(_lightshipController, 'Lightship / Lightweight'),
              _buildInputField(_ballastController, 'Ballast Water'),
              _buildInputField(_vlsfoController, 'VLSFO / Fuel Oil'),
              _buildInputField(_lsmgoController, 'LSMGO / Diesel Oil'),
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
                  icon: const Icon(Icons.download, color: Colors.greenAccent),
                  label: const Text('EXPORT EXCEL', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.greenAccent),
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
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildResultTile('Quarter Mean', '${quarterMean.toStringAsFixed(3)} m'),
                  _buildResultTile('Apparent Trim', '${apparentTrim.toStringAsFixed(3)} m'),
                  _buildResultTile('1st Correction (FTC)', '${ftc.toStringAsFixed(2)} MT'),
                  _buildResultTile('2nd Correction (STC)', '${stc.toStringAsFixed(2)} MT'),
                  _buildResultTile('Corrected Disp', '${correctedDisplacement.toStringAsFixed(2)} MT'),
                  _buildResultTile('Total Deductibles', '${totalDeductibles.toStringAsFixed(2)} MT'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NET CARGO DEADWEIGHT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                      '${netCargoDeadweight.toStringAsFixed(2)} MT',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: primaryBlue, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24, height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          filled: true,
          fillColor: bgColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryBlue),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildResultTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: primaryBlue, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class HistoryLogTab extends StatefulWidget {
  const HistoryLogTab({Key? key}) : super(key: key);

  @override
  State<HistoryLogTab> createState() => _HistoryLogTabState();
}

class _HistoryLogTabState extends State<HistoryLogTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131B2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D273D),
        title: const Text('Calculation History Log', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () {
              setState(() {
                calculationHistory.clear();
              });
            },
          )
        ],
      ),
      body: calculationHistory.isEmpty
          ? const Center(child: Text('No History Logs Available', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              itemCount: calculationHistory.length,
              itemBuilder: (context, index) {
                final item = calculationHistory[index];
                return Card(
                  color: const Color(0xFF1D273D),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('${item['vessel']} - ${item['port']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Date: ${item['timestamp']}\nCargo: ${item['netCargo'].toStringAsFixed(2)} MT', style: const TextStyle(color: Colors.white70)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          calculationHistory.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}