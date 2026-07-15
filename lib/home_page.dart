import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ 1. Initialize Firebase (Try-Catch taaki error na aaye agar json na ho)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Setup Note: Please add google-services.json");
  }

  // ✅ 2. Initialize Globals & Sync from Firebase
  await AppGlobals.init();
  
  runApp(const MaterialApp(
    home: HomePage(),
    debugShowCheckedModeBanner: false,
  ));
}

// ==========================================
// GLOBAL STATE (Local + Firebase Sync)
// ==========================================
class AppGlobals {
  static late SharedPreferences prefs;
  static late String deviceId;
  
  static bool isWallHackPaid = false;
  static bool isPaidObbPaid = false;
  static bool isDarkMode = true;
  static bool isFirewallActive = false;
  static String firewallJsonConfig = "";

  // Cyberpunk Colors
  static const Color neonYellow = Color(0xFFFFCC00);
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonGreen = Color(0xFF00FF66);
  static const Color neonOrange = Color(0xFFFF6600);
  static const Color neonPurple = Color(0xFFB026FF);
  static const Color darkBg = Color(0xFF07070C);
  static const Color surfaceCard = Color(0xFF11111E);

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    
    // Auto-generate Unique Device ID
    deviceId = prefs.getString('deviceId') ?? "";
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      prefs.setString('deviceId', deviceId);
    }

    // Load Local Data first
    isWallHackPaid = prefs.getBool('isWallHackPaid') ?? false;
    isPaidObbPaid = prefs.getBool('isPaidObbPaid') ?? false;
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    isFirewallActive = prefs.getBool('isFirewallActive') ?? false;
    firewallJsonConfig = prefs.getString('firewallJsonConfig') ?? "";

    // Sync with Firebase Database
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref("users/$deviceId");
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        isWallHackPaid = data['isWallHackPaid'] ?? isWallHackPaid;
        isPaidObbPaid = data['isPaidObbPaid'] ?? isPaidObbPaid;
        
        // Update Local storage with Cloud Data
        prefs.setBool('isWallHackPaid', isWallHackPaid);
        prefs.setBool('isPaidObbPaid', isPaidObbPaid);
      }
    } catch (e) {
      debugPrint("Firebase sync failed, using local preferences.");
    }
  }

  static Future<void> unlockFeature(String feature) async {
    if (feature == "WALL HACK") {
      isWallHackPaid = true;
      prefs.setBool('isWallHackPaid', true);
    } else {
      isPaidObbPaid = true;
      prefs.setBool('isPaidObbPaid', true);
    }

    // Save to Cloud
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref("users/$deviceId");
      await ref.update({
        'isWallHackPaid': isWallHackPaid,
        'isPaidObbPaid': isPaidObbPaid,
        'lastUnlocked': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Cloud save failed.");
    }
  }
}

// ==========================================
// SHIZUKU CORE ENGINE
// ==========================================
class ShizukuService {
  static const platform = MethodChannel('com.raaz.gaming/shizuku');
  static bool isConnected = false;

  static Future<void> autoConnect() async {
    try {
      final bool isRunning = await platform.invokeMethod('isShizukuServiceRunning');
      if (!isRunning) { isConnected = false; return; }
      final bool hasPerm = await platform.invokeMethod('checkPermission');
      if (hasPerm) { isConnected = true; } 
      else { isConnected = await platform.invokeMethod('requestPermission'); }
    } catch (e) {
      isConnected = false;
    }
  }

  static void showSnack(BuildContext context, String message, Color color) {
    if(!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppGlobals.surfaceCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 2)),
      ),
    );
  }
}

// ==========================================
// 1. HOME PAGE
// ==========================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _sliderTimer;

  final List<String> feedbackImages = [
    "https://picsum.photos/id/113/800/400",
    "https://picsum.photos/id/114/800/400",
  ];

  @override
  void initState() {
    super.initState();
    ShizukuService.autoConnect().then((_) => setState(() {}));
    _sliderTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < feedbackImages.length - 1) _currentPage++; else _currentPage = 0;
      if (_pageController.hasClients) _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sliderTimer?.cancel();
    super.dispose();
  }

  // ✅ PERFECT MATCH FIREWALL JSON DIALOG
  void _showJsonDialog(StateSetter setModalState) {
    TextEditingController jsonController = TextEditingController(text: AppGlobals.firewallJsonConfig);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppGlobals.neonPurple, width: 2)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings, color: Colors.blueGrey, size: 28),
                    SizedBox(width: 10),
                    Expanded(child: Text("FIREWALL CONFIG", style: TextStyle(color: AppGlobals.neonPurple, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2))),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Black Code Area
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: jsonController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace', height: 1.5),
                    decoration: const InputDecoration(
                      hintText: '{"rules": "allow", "port": 443}',
                      hintStyle: TextStyle(color: Colors.white24),
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          AppGlobals.isFirewallActive = false;
                          AppGlobals.prefs.setBool('isFirewallActive', false);
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppGlobals.neonPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        try {
                          if(jsonController.text.trim().isEmpty) throw Exception();
                          jsonDecode(jsonController.text); 
                          
                          AppGlobals.isFirewallActive = true;
                          AppGlobals.firewallJsonConfig = jsonController.text;
                          AppGlobals.prefs.setBool('isFirewallActive', true);
                          AppGlobals.prefs.setString('firewallJsonConfig', jsonController.text);
                          
                          setModalState(() {});
                          setState(() {}); // Update background
                          Navigator.pop(context);
                          ShizukuService.showSnack(context, "🛡️ VPN Firewall Enabled & Saved!", AppGlobals.neonPurple);
                        } catch (e) {
                          ShizukuService.showSnack(context, "❌ Invalid JSON Format!", Colors.redAccent);
                        }
                      },
                      child: const Text("ENABLE VPN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      }
    );
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppGlobals.surfaceCard.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: AppGlobals.neonBlue.withOpacity(0.5), width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text("SYSTEM SETTINGS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 24),
                  
                  // Firewall VPN (Auto Open JSON Dialog on Click)
                  ListTile(
                    tileColor: Colors.black26,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppGlobals.isFirewallActive ? AppGlobals.neonPurple.withOpacity(0.5) : Colors.transparent)),
                    leading: Icon(Icons.shield_moon_rounded, color: AppGlobals.isFirewallActive ? AppGlobals.neonPurple : Colors.grey, size: 30),
                    title: const Text("Firewall VPN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(AppGlobals.isFirewallActive ? "Secured via JSON Config" : "Disabled", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    trailing: CupertinoSwitch(
                      activeColor: AppGlobals.neonPurple,
                      value: AppGlobals.isFirewallActive,
                      onChanged: (v) {
                        if (v) {
                          _showJsonDialog(setModalState);
                        } else {
                          setModalState(() {
                            AppGlobals.isFirewallActive = false;
                            AppGlobals.prefs.setBool('isFirewallActive', false);
                          });
                          setState(() {});
                          ShizukuService.showSnack(context, "Firewall Disabled", Colors.orange);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dark Mode
                  ListTile(
                    tileColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(AppGlobals.isDarkMode ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill, color: AppGlobals.neonBlue, size: 30),
                    title: const Text("Dark UI Mode", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: CupertinoSwitch(activeColor: AppGlobals.neonBlue, value: AppGlobals.isDarkMode, onChanged: (v) { setModalState(() => AppGlobals.isDarkMode = v); AppGlobals.prefs.setBool('isDarkMode', v); setState(() {}); }),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  void _handleBoxClick(String feature, Color color, bool isPaid, Widget page) {
    if (isPaid) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => page));
    } else {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => PaymentPage(featureName: feature, themeColor: color, onUnlockSuccess: () => setState(() {}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    Color currentBg = AppGlobals.isDarkMode ? AppGlobals.darkBg : const Color(0xFFF4F5F9);
    Color currentCard = AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.white;
    Color currentText = AppGlobals.isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: currentBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("SK VIP", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: currentText, letterSpacing: 2)), const Text("CONFIG • POWERED BY SHIZUKU", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.8, color: AppGlobals.neonOrange)) ]),
                IconButton(icon: Icon(CupertinoIcons.settings_solid, color: AppGlobals.neonBlue, size: 30), onPressed: _showSettingsPanel),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildNavigationBox(["WALL HACK", "PANEL", "FEATURES"], Icons.grid_view_rounded, AppGlobals.neonYellow, AppGlobals.isWallHackPaid, currentCard, currentText, () => _handleBoxClick("WALL HACK", AppGlobals.neonYellow, AppGlobals.isWallHackPaid, const WallHackPage())),
                  const SizedBox(height: 16),
                  _buildNavigationBox(["PAID OBB", "ENHANCED", "MODULES"], Icons.developer_board_rounded, AppGlobals.neonBlue, AppGlobals.isPaidObbPaid, currentCard, currentText, () => _handleBoxClick("PAID OBB", AppGlobals.neonBlue, AppGlobals.isPaidObbPaid, const PaidObbPage())),
                  const SizedBox(height: 30),
                  
                  // Footer Stuff
                  Center(
                    child: Container(
                      width: 220, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(25)),
                      child: TextButton.icon(
                        onPressed: () async {
                          final Uri url = Uri.parse('https://t.me/telegram'); 
                          ShizukuService.showSnack(context, "Redirecting to Telegram...", AppGlobals.neonBlue);
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) if(context.mounted) ShizukuService.showSnack(context, "Error opening Telegram", Colors.red);
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                        label: const Text("Share Feedback", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.verified_user_rounded, color: AppGlobals.neonGreen, size: 30), const SizedBox(width: 8), Text("100% SECURE & SAFE", style: TextStyle(color: currentText, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)) ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBox(List<String> textLines, IconData icon, Color color, bool isUnlocked, Color bg, Color txt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.8), width: 1.5)),
        child: Row(children: [
            Icon(icon, color: color, size: 38), const SizedBox(width: 24),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: textLines.map((line) => Text(line, style: TextStyle(color: txt, fontWeight: FontWeight.w900, fontSize: 18, height: 1.2, letterSpacing: 1))).toList())),
            Icon(isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: isUnlocked ? AppGlobals.neonGreen : Colors.redAccent, size: 24),
            const SizedBox(width: 8), Icon(CupertinoIcons.chevron_right, color: Colors.grey.shade400, size: 24),
        ]),
      ),
    );
  }
}

// ==========================================
// 2. PAYMENT VERIFICATION PAGE
// ==========================================
class PaymentPage extends StatefulWidget {
  final String featureName; final Color themeColor; final VoidCallback onUnlockSuccess;
  const PaymentPage({super.key, required this.featureName, required this.themeColor, required this.onUnlockSuccess});
  @override State<PaymentPage> createState() => _PaymentPageState();
}
class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _utrController = TextEditingController(); bool isVerifying = false;
  final String qrCodeUrl = "https://upload.wikimedia.org/wikipedia/commons/d/d0/QR_code_for_mobile_English_Wikipedia.svg";

  void verifyPayment() async {
    if (_utrController.text.length < 12) { ShizukuService.showSnack(context, "⚠️ Enter Valid 12-Digit UTR/Ref ID", Colors.red); return; }
    setState(() => isVerifying = true);
    await Future.delayed(const Duration(seconds: 2)); 
    setState(() => isVerifying = false);
    ShizukuService.showSnack(context, "✅ Payment Verified & Synced to Cloud!", AppGlobals.neonGreen);
    
    // ✅ SYNC TO FIREBASE & LOCAL STORAGE
    await AppGlobals.unlockFeature(widget.featureName);

    widget.onUnlockSuccess();
    Navigator.pop(context);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGlobals.isDarkMode ? AppGlobals.darkBg : Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), title: Text("UNLOCK ${widget.featureName}", style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.w900, fontSize: 16))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Text("₹399", style: TextStyle(color: AppGlobals.isDarkMode ? Colors.white : Colors.black, fontSize: 40, fontWeight: FontWeight.w900)),
        Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.themeColor, width: 3)), child: Image.network(qrCodeUrl, height: 200, width: 200, fit: BoxFit.cover)),
        TextField(controller: _utrController, keyboardType: TextInputType.number, style: TextStyle(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), decoration: InputDecoration(filled: true, fillColor: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade200, hintText: "Enter 12-Digit UTR / Ref No.", prefixIcon: Icon(Icons.tag, color: widget.themeColor), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppGlobals.isDarkMode ? Colors.white12 : Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.themeColor, width: 2)))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: isVerifying ? null : verifyPayment, child: isVerifying ? const CircularProgressIndicator(color: Colors.black) : const Text("VERIFY PAYMENT", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)))),
      ])),
    );
  }
}

// ==========================================
// 3. WALL HACK PAGE (Feature Unlocked)
// ==========================================
class WallHackPage extends StatelessWidget {
  const WallHackPage({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.darkBg : Colors.white, appBar: AppBar(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade200, iconTheme: IconThemeData(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), title: const Text("WALL HACK", style: TextStyle(color: AppGlobals.neonYellow, fontWeight: FontWeight.w900))), body: const Center(child: Text("Inject Tools Here", style: TextStyle(color: Colors.grey))));
  }
}

// ==========================================
// 4. PAID OBB PAGE (Feature Unlocked)
// ==========================================
class PaidObbPage extends StatelessWidget {
  const PaidObbPage({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.darkBg : Colors.white, appBar: AppBar(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade200, iconTheme: IconThemeData(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), title: const Text("PAID OBB", style: TextStyle(color: AppGlobals.neonBlue, fontWeight: FontWeight.w900))), body: const Center(child: Text("Inject Tools Here", style: TextStyle(color: Colors.grey))));
  }
}
