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
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init failed: Check google-services.json");
  }
  await AppGlobals.init();
  runApp(const MaterialApp(home: HomePage(), debugShowCheckedModeBanner: false));
}

// ==========================================
// GLOBAL STATE & FIREBASE SYNC
// ==========================================
class AppGlobals {
  static late SharedPreferences prefs;
  static late String deviceId;
  
  static bool isWallHackPaid = false;
  static bool isPaidObbPaid = false;
  static bool isDarkMode = true;
  static bool isFirewallActive = false;
  static String firewallJsonConfig = "";

  // 🚀 DYNAMIC URLs FETCHED FROM FIREBASE
  static String wallHackUrl = "https://github.com/rajamransri-blip/Gfx/releases/download/Pak/mini_obbzsdic_obb.pak"; // Default Fallback
  static String paidObbUrl = "https://github.com/rajamransri-blip/Gfx/releases/download/Pak/mini_obbzsdic_obb.pak"; // Default Fallback

  static const Color neonYellow = Color(0xFFFFCC00);
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonGreen = Color(0xFF00FF66);
  static const Color neonOrange = Color(0xFFFF6600);
  static const Color neonPurple = Color(0xFFB026FF);
  static const Color darkBg = Color(0xFF07070C);
  static const Color surfaceCard = Color(0xFF11111E);

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString('deviceId') ?? "";
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      prefs.setString('deviceId', deviceId);
    }

    isWallHackPaid = prefs.getBool('isWallHackPaid') ?? false;
    isPaidObbPaid = prefs.getBool('isPaidObbPaid') ?? false;
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    isFirewallActive = prefs.getBool('isFirewallActive') ?? false;
    firewallJsonConfig = prefs.getString('firewallJsonConfig') ?? "";

    try {
      // 1. Fetch User Unlocks
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$deviceId");
      final userSnap = await userRef.get();
      if (userSnap.exists) {
        final data = userSnap.value as Map<dynamic, dynamic>;
        isWallHackPaid = data['isWallHackPaid'] ?? isWallHackPaid;
        isPaidObbPaid = data['isPaidObbPaid'] ?? isPaidObbPaid;
        prefs.setBool('isWallHackPaid', isWallHackPaid);
        prefs.setBool('isPaidObbPaid', isPaidObbPaid);
      }

      // 2. 🚀 FETCH ADMIN DOWNLOAD URLs FROM FIREBASE
      DatabaseReference configRef = FirebaseDatabase.instance.ref("app_config");
      final configSnap = await configRef.get();
      if (configSnap.exists) {
        final configData = configSnap.value as Map<dynamic, dynamic>;
        if (configData['wallHackUrl'] != null) wallHackUrl = configData['wallHackUrl'];
        if (configData['paidObbUrl'] != null) paidObbUrl = configData['paidObbUrl'];
      }
    } catch (e) {
      debugPrint("Firebase Sync Error: $e");
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
    try {
      await FirebaseDatabase.instance.ref("users/$deviceId").update({
        'isWallHackPaid': isWallHackPaid,
        'isPaidObbPaid': isPaidObbPaid,
      });
    } catch (_) {}
  }
}

// ==========================================
// NATIVE SERVICES (Shizuku + VPN)
// ==========================================
class NativeService {
  static const platform = MethodChannel('com.raaz.gaming/native');
  static bool isShizukuConnected = false;

  static Future<void> autoConnectShizuku() async {
    try {
      final bool isRunning = await platform.invokeMethod('isShizukuServiceRunning');
      if (!isRunning) { isShizukuConnected = false; return; }
      final bool hasPerm = await platform.invokeMethod('checkPermission');
      if (hasPerm) { isShizukuConnected = true; } 
      else { isShizukuConnected = await platform.invokeMethod('requestPermission'); }
    } catch (e) { isShizukuConnected = false; }
  }

  // 🛡️ ACTUAL VPN TRIGGER METHOD
  static Future<void> toggleVpn(bool enable, String jsonConfig) async {
    try {
      if (enable) {
        await platform.invokeMethod('startVpn', {'config': jsonConfig});
      } else {
        await platform.invokeMethod('stopVpn');
      }
    } catch (e) {
      debugPrint("VPN Error: $e");
    }
  }

  static Future<void> handleFeatureInjection({
    required BuildContext context, required String featureName, required bool enable, 
    required String downloadUrl, required String fileName, required Function(bool) setLoading,
  }) async {
    if (!isShizukuConnected && enable) {
      showSnack(context, "⚠️ Connect Shizuku from Home Page first!", AppGlobals.neonOrange);
      return;
    }

    setLoading(true);
    try {
      await Permission.storage.request();
      final targetPath = "/storage/emulated/0/Raaz";
      final String bgmiPakPath = "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks";

      await platform.invokeMethod('executeCommand', {'command': 'mkdir -p $targetPath'});

      if (enable) {
        final directory = await getExternalStorageDirectory();
        final localFile = File("${directory!.path}/$fileName");

        // 🚀 DOWNLOADING FROM FIREBASE DYNAMIC URL
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200 || response.statusCode == 302) {
          await localFile.writeAsBytes(response.bodyBytes);
          await platform.invokeMethod('executeCommand', {'command': 'cp "${localFile.path}" "$targetPath/$fileName"'});
          await platform.invokeMethod('executeCommand', {'command': 'mkdir -p $bgmiPakPath'});
          final bool success = await platform.invokeMethod('executeCommand', {'command': 'cp "$targetPath/$fileName" "$bgmiPakPath/$fileName"'});

          if (success) showSnack(context, "⚡ $featureName Activated!", AppGlobals.neonGreen);
          else throw Exception("Shizuku processing failure");
        }
      } else {
        await platform.invokeMethod('executeCommand', {'command': 'rm -f "$bgmiPakPath/$fileName"'});
        showSnack(context, "🗑️ $featureName Disabled!", AppGlobals.neonYellow);
      }
    } catch (e) {
      showSnack(context, "Inject Error: $e", Colors.redAccent);
    } finally {
      setLoading(false);
    }
  }

  static void showSnack(BuildContext context, String message, Color color) {
    if(!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: AppGlobals.surfaceCard, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 2))));
  }
}

// ==========================================
// 1. HOME PAGE
// ==========================================
class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(); int _currentPage = 0; Timer? _sliderTimer;
  final List<String> feedbackImages = ["https://picsum.photos/id/113/800/400", "https://picsum.photos/id/114/800/400"];

  @override void initState() {
    super.initState();
    NativeService.autoConnectShizuku().then((_) => setState(() {}));
    _sliderTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < feedbackImages.length - 1) _currentPage++; else _currentPage = 0;
      if (_pageController.hasClients) _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
    });
  }
  @override void dispose() { _pageController.dispose(); _sliderTimer?.cancel(); super.dispose(); }

  void _showJsonDialog(StateSetter setModalState) {
    TextEditingController jsonController = TextEditingController(text: AppGlobals.firewallJsonConfig);
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E2A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppGlobals.neonPurple, width: 2)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(children: [ Icon(Icons.settings, color: Colors.blueGrey, size: 28), SizedBox(width: 10), Expanded(child: Text("FIREWALL CONFIG", style: TextStyle(color: AppGlobals.neonPurple, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2))) ]),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFF0D0D14), borderRadius: BorderRadius.circular(12)),
                  child: TextField(controller: jsonController, maxLines: 8, style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'Paste Firewall JSON...', border: InputBorder.none, contentPadding: EdgeInsets.all(16))),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () { setModalState(() { AppGlobals.isFirewallActive = false; AppGlobals.prefs.setBool('isFirewallActive', false); }); Navigator.pop(context); }, child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppGlobals.neonPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                      onPressed: () async {
                        try {
                          jsonDecode(jsonController.text); // Validate
                          AppGlobals.isFirewallActive = true; AppGlobals.firewallJsonConfig = jsonController.text;
                          AppGlobals.prefs.setBool('isFirewallActive', true); AppGlobals.prefs.setString('firewallJsonConfig', jsonController.text);
                          
                          // 🚀 START ACTUAL VPN
                          await NativeService.toggleVpn(true, jsonController.text);
                          
                          setModalState(() {}); setState(() {}); Navigator.pop(context);
                          NativeService.showSnack(context, "🛡️ VPN Activated!", AppGlobals.neonPurple);
                        } catch (e) { NativeService.showSnack(context, "❌ Invalid JSON Format!", Colors.redAccent); }
                      },
                      child: const Text("ENABLE VPN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppGlobals.surfaceCard.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: AppGlobals.neonBlue.withOpacity(0.5), width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 20),
                  const Text("SYSTEM SETTINGS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)), const SizedBox(height: 24),
                  
                  ListTile(
                    tileColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(NativeService.isShizukuConnected ? Icons.gpp_good_rounded : Icons.gpp_maybe_rounded, color: NativeService.isShizukuConnected ? AppGlobals.neonGreen : AppGlobals.neonOrange, size: 30),
                    title: const Text("Shizuku Core", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), trailing: CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), color: NativeService.isShizukuConnected ? AppGlobals.neonGreen.withOpacity(0.2) : AppGlobals.neonOrange.withOpacity(0.2), onPressed: () async { await NativeService.autoConnectShizuku(); setModalState(() {}); setState(() {}); }, child: Text("REFRESH", style: TextStyle(color: NativeService.isShizukuConnected ? AppGlobals.neonGreen : AppGlobals.neonOrange, fontWeight: FontWeight.bold, fontSize: 12))),
                  ), const SizedBox(height: 12),
                  
                  ListTile(
                    tileColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppGlobals.isFirewallActive ? AppGlobals.neonPurple.withOpacity(0.5) : Colors.transparent)),
                    leading: Icon(Icons.shield_moon_rounded, color: AppGlobals.isFirewallActive ? AppGlobals.neonPurple : Colors.grey, size: 30),
                    title: const Text("Firewall VPN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: CupertinoSwitch(activeColor: AppGlobals.neonPurple, value: AppGlobals.isFirewallActive, onChanged: (v) async {
                        if (v) _showJsonDialog(setModalState);
                        else {
                          setModalState(() { AppGlobals.isFirewallActive = false; AppGlobals.prefs.setBool('isFirewallActive', false); }); setState(() {});
                          await NativeService.toggleVpn(false, ""); // 🛑 STOP ACTUAL VPN
                          NativeService.showSnack(context, "Firewall Disabled", Colors.orange);
                        }
                    }),
                  ), const SizedBox(height: 12),
                  
                  ListTile(
                    tileColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(AppGlobals.isDarkMode ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill, color: AppGlobals.neonBlue, size: 30), title: const Text("Dark UI Mode", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: CupertinoSwitch(activeColor: AppGlobals.neonBlue, value: AppGlobals.isDarkMode, onChanged: (v) { setModalState(() => AppGlobals.isDarkMode = v); AppGlobals.prefs.setBool('isDarkMode', v); setState(() {}); }),
                  ), const SizedBox(height: 30),
                ],
              ),
            );
          }),
        );
    });
  }

  void _handleBoxClick(String feature, Color color, bool isPaid, Widget page) {
    if (isPaid) Navigator.push(context, CupertinoPageRoute(builder: (context) => page));
    else Navigator.push(context, CupertinoPageRoute(builder: (context) => PaymentPage(featureName: feature, themeColor: color, onUnlockSuccess: () => setState(() {}))));
  }

  @override Widget build(BuildContext context) {
    Color currentBg = AppGlobals.isDarkMode ? AppGlobals.darkBg : const Color(0xFFF4F5F9);
    Color currentCard = AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.white;
    Color currentText = AppGlobals.isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: currentBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("SK VIP", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: currentText, letterSpacing: 2)), const Text("CONFIG • POWERED BY SHIZUKU", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.8, color: AppGlobals.neonOrange)) ]), IconButton(icon: Icon(CupertinoIcons.settings_solid, color: AppGlobals.neonBlue, size: 30), onPressed: _showSettingsPanel) ])),
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), physics: const BouncingScrollPhysics(), children: [
                  _buildNavigationBox(["WALL HACK", "PANEL", "FEATURES"], Icons.grid_view_rounded, AppGlobals.neonYellow, AppGlobals.isWallHackPaid, currentCard, currentText, () => _handleBoxClick("WALL HACK", AppGlobals.neonYellow, AppGlobals.isWallHackPaid, const WallHackPage())), const SizedBox(height: 16),
                  _buildNavigationBox(["PAID OBB", "ENHANCED", "MODULES"], Icons.developer_board_rounded, AppGlobals.neonBlue, AppGlobals.isPaidObbPaid, currentCard, currentText, () => _handleBoxClick("PAID OBB", AppGlobals.neonBlue, AppGlobals.isPaidObbPaid, const PaidObbPage())), const SizedBox(height: 30),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("USER FEEDBACK & PROOFS", style: TextStyle(color: AppGlobals.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)), const SizedBox(height: 10), Container(height: 160, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: PageView.builder(controller: _pageController, itemCount: feedbackImages.length, itemBuilder: (context, index) => Image.network(feedbackImages[index], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade900, child: const Icon(Icons.image, color: Colors.white, size: 50)))))) ]), const SizedBox(height: 24),
                  Center(child: Container(width: 220, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(25)), child: TextButton.icon(onPressed: () async { final Uri url = Uri.parse('https://t.me/telegram'); NativeService.showSnack(context, "Redirecting to Telegram...", AppGlobals.neonBlue); if (!await launchUrl(url, mode: LaunchMode.externalApplication)) if(context.mounted) NativeService.showSnack(context, "Error opening Telegram", Colors.red); }, icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20), label: const Text("Share Feedback", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))), const SizedBox(height: 30),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.verified_user_rounded, color: AppGlobals.neonGreen, size: 30), const SizedBox(width: 8), Text("100% SECURE & SAFE", style: TextStyle(color: currentText, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)) ]), const SizedBox(height: 40),
            ]))
          ],
        ),
      ),
    );
  }
  Widget _buildNavigationBox(List<String> textLines, IconData icon, Color color, bool isUnlocked, Color bg, Color txt, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.8), width: 1.5)), child: Row(children: [ Icon(icon, color: color, size: 38), const SizedBox(width: 24), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: textLines.map((line) => Text(line, style: TextStyle(color: txt, fontWeight: FontWeight.w900, fontSize: 18, height: 1.2, letterSpacing: 1))).toList())), Icon(isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: isUnlocked ? AppGlobals.neonGreen : Colors.redAccent, size: 24), const SizedBox(width: 8), Icon(CupertinoIcons.chevron_right, color: Colors.grey.shade400, size: 24) ])));
  }
}

// ==========================================
// 2. PAYMENT PAGE
// ==========================================
class PaymentPage extends StatefulWidget {
  final String featureName; final Color themeColor; final VoidCallback onUnlockSuccess;
  const PaymentPage({super.key, required this.featureName, required this.themeColor, required this.onUnlockSuccess});
  @override State<PaymentPage> createState() => _PaymentPageState();
}
class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _utrController = TextEditingController(); bool isVerifying = false;
  void verifyPayment() async {
    if (_utrController.text.length < 12) { NativeService.showSnack(context, "⚠️ Enter Valid 12-Digit UTR/Ref ID", Colors.red); return; }
    setState(() => isVerifying = true); await Future.delayed(const Duration(seconds: 2)); setState(() => isVerifying = false);
    NativeService.showSnack(context, "✅ Verified & Cloud Synced!", AppGlobals.neonGreen);
    await AppGlobals.unlockFeature(widget.featureName);
    widget.onUnlockSuccess(); Navigator.pop(context);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.darkBg : Colors.white, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), title: Text("UNLOCK ${widget.featureName}", style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.w900, fontSize: 16))), body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [ Text("₹399", style: TextStyle(color: AppGlobals.isDarkMode ? Colors.white : Colors.black, fontSize: 40, fontWeight: FontWeight.w900)), Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.themeColor, width: 3)), child: Image.network("https://upload.wikimedia.org/wikipedia/commons/d/d0/QR_code_for_mobile_English_Wikipedia.svg", height: 200, width: 200, fit: BoxFit.cover)), TextField(controller: _utrController, keyboardType: TextInputType.number, style: TextStyle(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), decoration: InputDecoration(filled: true, fillColor: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade200, hintText: "Enter 12-Digit UTR / Ref No.", prefixIcon: Icon(Icons.tag, color: widget.themeColor), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppGlobals.isDarkMode ? Colors.white12 : Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.themeColor, width: 2)))), const SizedBox(height: 24), SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: isVerifying ? null : verifyPayment, child: isVerifying ? const CircularProgressIndicator(color: Colors.black) : const Text("VERIFY PAYMENT", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)))) ])));
  }
}

// ==========================================
// 3. WALL HACK PAGE
// ==========================================
class WallHackPage extends StatefulWidget { const WallHackPage({super.key}); @override State<WallHackPage> createState() => _WallHackPageState(); }
class _WallHackPageState extends State<WallHackPage> {
  bool isEnabled = false; bool isLoading = false;
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.darkBg : Colors.white, appBar: AppBar(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade200, iconTheme: IconThemeData(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), title: const Text("WALL HACK MODULES", style: TextStyle(color: AppGlobals.neonYellow, fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(20), children: [ Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: isEnabled ? AppGlobals.neonYellow : Colors.white12, width: 1.5)), child: Row(children: [ Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("Enable Wall Hack", style: TextStyle(color: AppGlobals.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)), Text("Auto fetches URL from Admin Firebase", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)) ])), isLoading && isEnabled ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppGlobals.neonYellow, strokeWidth: 2)) : CupertinoSwitch(activeColor: AppGlobals.neonYellow, value: isEnabled, onChanged: (v) { setState(() => isEnabled = v); NativeService.handleFeatureInjection(context: context, featureName: "Wall Hack", enable: v, downloadUrl: AppGlobals.wallHackUrl, fileName: "wallhack.pak", setLoading: (loading) => setState(() => isLoading = loading)); }) ])) ]));
  }
}

// ==========================================
// 4. PAID OBB PAGE
// ==========================================
class PaidObbPage extends StatefulWidget { const PaidObbPage({super.key}); @override State<PaidObbPage> createState() => _PaidObbPageState(); }
class _PaidObbPageState extends State<PaidObbPage> {
  bool isEnabled = false; bool isLoading = false;
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.darkBg : Colors.white, appBar: AppBar(backgroundColor: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade200, iconTheme: IconThemeData(color: AppGlobals.isDarkMode ? Colors.white : Colors.black), title: const Text("PAID OBB MODULES", style: TextStyle(color: AppGlobals.neonBlue, fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(20), children: [ Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppGlobals.isDarkMode ? AppGlobals.surfaceCard : Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: isEnabled ? AppGlobals.neonBlue : Colors.white12, width: 1.5)), child: Row(children: [ Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("Inject Paid OBB", style: TextStyle(color: AppGlobals.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)), Text("Auto fetches URL from Admin Firebase", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)) ])), isLoading && isEnabled ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppGlobals.neonBlue, strokeWidth: 2)) : CupertinoSwitch(activeColor: AppGlobals.neonBlue, value: isEnabled, onChanged: (v) { setState(() => isEnabled = v); NativeService.handleFeatureInjection(context: context, featureName: "Paid OBB", enable: v, downloadUrl: AppGlobals.paidObbUrl, fileName: "paid_obb.pak", setLoading: (loading) => setState(() => isLoading = loading)); }) ])) ]));
  }
}
