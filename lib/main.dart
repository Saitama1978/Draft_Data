import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DraftSurveyTab extends StatefulWidget {
  const DraftSurveyTab({Key? key}) : super(key: key);

  @override
  State<DraftSurveyTab> createState() => _DraftSurveyTabState();
}

class _DraftSurveyTabState extends State<DraftSurveyTab> {
  // Color Palette mula sa iyong UI
  final Color bgColor = const Color(0xFF131B2E);
  final Color cardColor = const Color(0xFF1D273D);
  final Color primaryBlue = const Color(0xFF38BDF8);
  final Color buttonBlue = const Color(0xFF2563EB);

  // Controllers
  final _fwdPortController = TextEditingController();
  final _fwdStbdController = TextEditingController();
  final _midPortController = TextEditingController();
  final _midStbdController = TextEditingController();
  final _aftPortController = TextEditingController();
  final _aftStbdController = TextEditingController();

  final _vesselNameController = TextEditingController();
  final _portController = TextEditingController();
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

  // Results Variables
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
    });
  }

  void _resetFields() {
    setState(() {
      _fwdPortController.clear();
      _fwdStbdController.clear();
      _midPortController.clear();
      _midStbdController.clear();
      _aftPortController.clear();
      _aftStbdController.clear();
      _rawDispController.clear();
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

  // PDF Report Generation (Walang Developer Name)
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
                  child: pw.Text(
                    'DRAFT SURVEY REPORT',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
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
                pw.TableHelper.fromTextArray(
                  headers: ['Location', 'Port (m)', 'Stbd (m)', 'Mean (m)'],
                  data: [
                    ['Forward', _fwdPortController.text, _fwdStbdController.text, meanFwd.toStringAsFixed(3)],
                    ['Midship', _midPortController.text, _midStbdController.text, meanMid.toStringAsFixed(3)],
                    ['Aft', _aftPortController.text, _aftStbdController.text, meanAft.toStringAsFixed(3)],
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Text('2. DISPLACEMENT & CORRECTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Bullet(text: 'Quarter Mean Draft: ${quarterMean.toStringAsFixed(3)} m'),
                pw.Bullet(text: 'Apparent Trim: ${apparentTrim.toStringAsFixed(3)} m'),
                pw.Bullet(text: 'Trim Corrected Displacement: ${correctedDisplacement.toStringAsFixed(2)} MT'),
                pw.SizedBox(height: 15),
                pw.Text('3. DEDUCTIBLES & CARGO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Bullet(text: 'Total Deductibles: ${totalDeductibles.toStringAsFixed(2)} MT'),
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
    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // SECTION 1: DRAFT OBSERVATIONS
            _buildSectionCard(
              title: '1. Draft Observations (m)',
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

            // SECTION 2: HYDROSTATICS & DENSITY
            _buildSectionCard(
              title: '2. Hydrostatics & Density',
              children: [
                _buildInputField(_rawDispController, 'Table Displacement (MT)'),
                _buildInputField(_lbpController, 'LBP (m)'),
                _buildInputField(_lcfController, 'LCF (m)'),
                _buildInputField(_tpcController, 'TPC (Tons/cm)'),
                _buildInputField(_dMtcController, 'dMTC'),
                _buildInputField(_dockDensityController, 'Dock Water Density (t/m³)'),
              ],
            ),

            // SECTION 3: DEDUCTIBLES
            _buildSectionCard(
              title: '3. Deductibles (MT)',
              children: [
                _buildInputField(_lightshipController, 'Lightship / Lightweight'),
                _buildInputField(_ballastController, 'Ballast Water'),
                _buildInputField(_vlsfoController, 'VLSFO / Fuel Oil'),
                _buildInputField(_lsmgoController, 'LSMGO / Diesel Oil'),
              ],
            ),

            const SizedBox(height: 10),

            // ACTION BUTTONS: CALCULATE, RESET, PRINT, SAVE
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetFields,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('RESET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    label: Text('PRINT REPORT', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveAndSharePdf,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    label: const Text('SAVE PDF', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

            // RESULTS OUTPUT GRID (Gaya ng UI mo)
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
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
          Text(
            title,
            style: TextStyle(color: primaryBlue, fontSize: 16, fontWeight: FontWeight.bold),
          ),
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