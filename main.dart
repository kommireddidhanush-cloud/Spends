import 'dart:math';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:another_telephony/telephony.dart';
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) {
  final body = message.body ?? '';
  final parsed = SpendsModel.extractDebit(body);
  if (parsed != null) {
    debugPrint("Auto SMS Captured: ${parsed['amount']} at ${parsed['vendor']}");
  }
}

void main() {
  runApp(const SpendsApp());
}

class SpendsApp extends StatelessWidget {
  const SpendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF06070A),
      ),
      home: const SpendsHome(),
    );
  }
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final String time;

  TransactionItem({required this.id, required this.title, required this.amount, required this.time});
}

class SpendsHome extends StatefulWidget {
  const SpendsHome({super.key});

  @override
  State<SpendsHome> createState() => _SpendsHomeState();
}

class _SpendsHomeState extends State<SpendsHome> with SingleTickerProviderStateMixin {
  final Telephony telephony = Telephony.instance;
  final PageController _pageController = PageController();

  double salary = 50000;
  double fixedCommitments = 18000;
  List<TransactionItem> transactions = [];

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    initSmsListener();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void initSmsListener() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted == true) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          final body = message.body ?? '';
          final parsed = SpendsModel.extractDebit(body);
          if (parsed != null) {
            setState(() {
              transactions.insert(
                0,
                TransactionItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: parsed['vendor'] as String,
                  amount: parsed['amount'] as double,
                  time: DateFormat('hh:mm a').format(DateTime.now()),
                ),
              );
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                content: Text("Auto-Logged: ₹${parsed['amount']} at ${parsed['vendor']}"),
              ),
            );
          }
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
    }
  }

  double get totalDailySpent => transactions.fold(0, (sum, t) => sum + t.amount);
  double get safeCash => salary - fixedCommitments - totalDailySpent;
  double get tankFillPercent {
    final pool = salary - fixedCommitments;
    if (pool <= 0) return 0;
    return (safeCash / pool).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Spends",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      TextButton(
                        onPressed: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                        child: const Text("Analytics ➔", style: TextStyle(color: Color(0xFF8B5CF6))),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showConfigModal,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F1118),
                        border: Border.all(color: Colors.white12, width: 2),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.15), blurRadius: 40),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(220, 220),
                                  painter: LiquidPainter(
                                    waveProgress: _waveController.value,
                                    fillPercent: tankFillPercent,
                                  ),
                                );
                              },
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("IN-HAND FUEL", style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.white70)),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(safeCash),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                                ),
                                Text(
                                  "${(tankFillPercent * 100).toInt()}% Capacity",
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _telemetryTile("CAPACITY", currency.format(salary), const Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _telemetryTile("FIXED FLOOR", currency.format(fixedCommitments), const Color(0xFFF43F5E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("RECENT SPENDS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: transactions.isEmpty
                        ? const Center(child: Text("No spends logged. SMS will auto-sync.", style: TextStyle(color: Colors.white24, fontSize: 13)))
                        : ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, i) {
                              final t = transactions[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1118),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        Text(t.time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                      ],
                                    ),
                                    Text("-${currency.format(t.amount)}", style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      ),
                      const Text("Financial Rings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1118),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(value: (totalDailySpent / (salary == 0 ? 1 : salary)).clamp(0.0, 1.0), strokeWidth: 8, color: const Color(0xFFF43F5E)),
                              CircularProgressIndicator(value: (fixedCommitments / (salary == 0 ? 1 : salary)).clamp(0.0, 1.0), strokeWidth: 8, color: const Color(0xFF38BDF8)),
                              CircularProgressIndicator(value: tankFillPercent, strokeWidth: 8, color: const Color(0xFF10B981)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ringLegend("Burned", currency.format(totalDailySpent), const Color(0xFFF43F5E)),
                            const SizedBox(height: 6),
                            _ringLegend("Fixed", currency.format(fixedCommitments), const Color(0xFF38BDF8)),
                            const SizedBox(height: 6),
                            _ringLegend("In-Hand", currency.format(safeCash), const Color(0xFF10B981)),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _telemetryTile(String title, String val, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFF0F1118), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }

  Widget _ringLegend(String label, String amount, Color c) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.white70)),
        Text(amount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showConfigModal() {
    final salCtrl = TextEditingController(text: salary.toInt().toString());
    final fixCtrl = TextEditingController(text: fixedCommitments.toInt().toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12141C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Calibrate Tank", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: salCtrl, decoration: const InputDecoration(labelText: "Monthly Salary (₹)"), keyboardType: TextInputType.number),
            TextField(controller: fixCtrl, decoration: const InputDecoration(labelText: "Fixed EMI + Rent (₹)"), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: const Color(0xFF8B5CF6)),
              onPressed: () {
                setState(() {
                  salary = double.tryParse(salCtrl.text) ?? salary;
                  fixedCommitments = double.tryParse(fixCtrl.text) ?? fixedCommitments;
                });
                Navigator.pop(ctx);
              },
              child: const Text("Save Physics", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class SpendsModel {
  static Map<String, dynamic>? extractDebit(String body) {
    final amtRegex = RegExp(r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);
    final amtMatch = amtRegex.firstMatch(body);
    if (amtMatch == null) return null;

    final rawAmt = amtMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(rawAmt) ?? 0.0;

    final vendorRegex = RegExp(r'(?:to|at|info)\s+([A-Za-z0-9\s&*-]{3,20})', caseSensitive: false);
    final vendorMatch = vendorRegex.firstMatch(body);
    final vendor = vendorMatch?.group(1)?.trim() ?? "Auto Debit";

    return {'amount': amount, 'vendor': vendor};
  }
}

class LiquidPainter extends CustomPainter {
  final double waveProgress;
  final double fillPercent;

  LiquidPainter({required this.waveProgress, required this.fillPercent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: fillPercent > 0.5
            ? [const Color(0xFF8B5CF6), const Color(0xFF3B82F6)]
            : (fillPercent > 0.2
                ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                : [const Color(0xFFF43F5E), const Color(0xFFBE123C)]),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final baseHeight = size.height * (1.0 - fillPercent);

    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        baseHeight + sin((i / size.width * 2 * pi) + (waveProgress * 2 * pi)) * 6,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidPainter oldDelegate) => true;
}
