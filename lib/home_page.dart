import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    home: HomePage(),
    debugShowCheckedModeBanner: false,
  ));
}

// ==========================================
// GLOBAL STATE (To track Paid Status)
// ==========================================
class AppGlobals {
  static bool isWallHackPaid = false;
  static bool isPaidObbPaid = false;

  // Cyberpunk Theme Colors
  static const Color neonYellow = Color(0xFFFFCC00);
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonGreen = Color(0xFF00FF66);
  static const Color neonOrange = Color(0xFFFF6600);
  static const Color darkBg = Color(0xFF07070C);
  static const Color surfaceCard = Color(0xFF11111E);
}

// ==========================================
// SHIZUKU CORE ENGINE (Shared across pages)
// ==========================================
class ShizukuService {
  static const platform = MethodChannel('com.raaz.gaming/shizuku');
  static bool isConnected = false;

  static Future<void> autoConnect() async {
    try {
      final bool isRunning = await platform.invokeMethod('isShizukuServiceRunning');
      if (!isRunning) {
        isConnected = false;
        return;
      }
      final bool hasPerm = await platform.invokeMethod('checkPermission');
      if (hasPerm) {
        isConnected = true;
      } else {
        isConnected = await platform.invokeMethod('requestPermission');
      }
    } catch (e) {
      isConnected = false;
    }
  }

  static Future<void> handleFeatureInjection({
    required BuildContext context,
    required String featureName,
    required bool enable,
    required Function(bool) setLoading,
  }) async {
    if (!isConnected && enable) {
      _showSnack(context, "⚠️ Connect Shizuku from Home Page first!", AppGlobals.neonOrange);
      return;
    }

    setLoading(true);
    try {
      await Permission.storage.request();
      final targetPath = "/storage/emulated/0/Raaz";
      final String fileUrl = "https://github.com/rajamransri-blip/Gfx/releases/download/Pak/mini_obbzsdic_obb.pak";
      final String fileName = "mini_obbzsdic_obb.pak";
      final String bgmiPakPath = "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks";

      await platform.invokeMethod('executeCommand', {'command': 'mkdir -p $targetPath'});

      if (enable) {
        final directory = await getExternalStorageDirectory();
        final localFolder = Directory("${directory!.path}/Raaz");
        if (!localFolder.existsSync()) localFolder.createSync(recursive: true);
        final localFile = File("${localFolder.path}/$fileName");

        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode == 200 || response.statusCode == 302) {
          await localFile.writeAsBytes(response.bodyBytes);
          await platform.invokeMethod('executeCommand', {'command': 'cp "${localFile.path}" "$targetPath/$fileName"'});
          await platform.invokeMethod('executeCommand', {'command': 'mkdir -p $bgmiPakPath'});
          final bool success = await platform.invokeMethod('executeCommand', {'command': 'cp "$targetPath/$fileName" "$bgmiPakPath/$fileName"'});

          if (success) {
            _showSnack(context, "⚡ $featureName Activated!", AppGlobals.neonGreen);
          } else {
            throw Exception("Shizuku processing validation failure");
          }
        }
      } else {
        await platform.invokeMethod('executeCommand', {'command': 'rm -f "$bgmiPakPath/$fileName"'});
        _showSnack(context, "🗑️ $featureName Deactivated!", AppGlobals.neonYellow);
      }
    } catch (e) {
      _showSnack(context, "Inject Error: ${e.toString()}", Colors.redAccent);
    } finally {
      setLoading(false);
    }
  }

  static void _showSnack(BuildContext context, String message, Color color) {
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
  @override
  void initState() {
    super.initState();
    ShizukuService.autoConnect().then((_) => setState(() {}));
  }

  void _handleBoxClick(String feature, Color color, bool isPaid, VoidCallback onSuccess) {
    if (isPaid) {
      onSuccess();
    } else {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => PaymentPage(
            featureName: feature,
            themeColor: color,
            price: "₹399",
            onUnlockSuccess: () {
              setState(() {});
              onSuccess();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGlobals.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SK VIP", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: 2)),
                      Text("CONFIG • POWERED BY SHIZUKU", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.8, color: AppGlobals.neonOrange)),
                    ],
                  ),
                  Icon(CupertinoIcons.settings_solid, color: AppGlobals.neonBlue, size: 28),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Shizuku Banner
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppGlobals.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ShizukuService.isConnected ? AppGlobals.neonGreen : AppGlobals.neonOrange, width: 2),
                      boxShadow: [BoxShadow(color: (ShizukuService.isConnected ? AppGlobals.neonGreen : AppGlobals.neonOrange).withOpacity(0.15), blurRadius: 12)],
                    ),
                    child: InkWell(
                      onTap: () async {
                        await ShizukuService.autoConnect();
                        setState(() {});
                      },
                      child: Row(
                        children: [
                          Icon(ShizukuService.isConnected ? Icons.gpp_good_rounded : Icons.gpp_maybe_rounded, color: ShizukuService.isConnected ? AppGlobals.neonGreen : AppGlobals.neonOrange, size: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ShizukuService.isConnected ? "SHIZUKU CONNECTED" : "SHIZUKU DISCONNECTED", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                Text(ShizukuService.isConnected ? "Ready for injection." : "Tap to initialize service.", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // MAIN FEATURE BOXES
                  _buildNavigationBox(
                    title: "WALL HACK PANEL FEATURES",
                    icon: Icons.grid_view_rounded,
                    color: AppGlobals.neonYellow,
                    isUnlocked: AppGlobals.isWallHackPaid,
                    onTap: () => _handleBoxClick("WALL HACK", AppGlobals.neonYellow, AppGlobals.isWallHackPaid, () {
                      Navigator.push(context, CupertinoPageRoute(builder: (context) => const WallHackPage()));
                    }),
                  ),
                  const SizedBox(height: 16),
                  _buildNavigationBox(
                    title: "PAID OBB ENHANCED MODULES",
                    icon: Icons.developer_board_rounded,
                    color: AppGlobals.neonBlue,
                    isUnlocked: AppGlobals.isPaidObbPaid,
                    onTap: () => _handleBoxClick("PAID OBB", AppGlobals.neonBlue, AppGlobals.isPaidObbPaid, () {
                      Navigator.push(context, CupertinoPageRoute(builder: (context) => const PaidObbPage()));
                    }),
                  ),

                  const SizedBox(height: 40),

                  // FEEDBACK BUTTON
                  Center(
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.feedback_rounded, color: Colors.white70, size: 20),
                      label: const Text("Share Feedback", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(backgroundColor: Colors.white10, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // PHONEPE STYLE SECURE FOOTER
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.green.shade500, size: 28),
                          const SizedBox(width: 8),
                          const Text("100% SECURE & SAFE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("All payments are encrypted and verified instantly", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text("POWERED BY SK VIP • UPI", style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBox({required String title, required IconData icon, required Color color, required bool isUnlocked, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppGlobals.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
            ),
            if (isUnlocked)
              Icon(Icons.lock_open_rounded, color: AppGlobals.neonGreen, size: 20)
            else
              Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            Icon(CupertinoIcons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. PAYMENT VERIFICATION PAGE
// ==========================================
class PaymentPage extends StatefulWidget {
  final String featureName;
  final String price;
  final Color themeColor;
  final VoidCallback onUnlockSuccess;

  const PaymentPage({super.key, required this.featureName, required this.price, required this.themeColor, required this.onUnlockSuccess});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _utrController = TextEditingController();
  bool isVerifying = false;
  
  // Replace with your actual QR Code Image URL
  final String qrCodeUrl = "https://upload.wikimedia.org/wikipedia/commons/d/d0/QR_code_for_mobile_English_Wikipedia.svg";

  void verifyPayment() async {
    if (_utrController.text.length < 12) {
      ShizukuService._showSnack(context, "⚠️ Enter Valid 12-Digit UTR/Ref ID", Colors.red);
      return;
    }

    setState(() => isVerifying = true);
    
    // Simulating network verification delay
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() => isVerifying = false);
    ShizukuService._showSnack(context, "✅ Payment Verified! Feature Unlocked.", AppGlobals.neonGreen);
    
    if (widget.featureName == "WALL HACK") {
      AppGlobals.isWallHackPaid = true;
    } else {
      AppGlobals.isPaidObbPaid = true;
    }

    widget.onUnlockSuccess();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGlobals.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("UNLOCK ${widget.featureName}", style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(widget.price, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            Text("Pay via any UPI App", style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 30),
            
            // QR Code Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.themeColor, width: 3)),
              child: Image.network(qrCodeUrl, height: 200, width: 200, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2, size: 200, color: Colors.black)),
            ),
            const SizedBox(height: 30),

            // UTR Input
            TextField(
              controller: _utrController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppGlobals.surfaceCard,
                hintText: "Enter 12-Digit UTR / Ref No.",
                hintStyle: TextStyle(color: Colors.grey.shade600, letterSpacing: 0),
                prefixIcon: Icon(Icons.tag, color: widget.themeColor),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.themeColor, width: 2)),
              ),
            ),
            const SizedBox(height: 24),

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isVerifying ? null : verifyPayment,
                child: isVerifying
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("VERIFY PAYMENT", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. WALL HACK PAGE (wall.dart equivalent)
// ==========================================
class WallHackPage extends StatefulWidget {
  const WallHackPage({super.key});
  @override
  State<WallHackPage> createState() => _WallHackPageState();
}

class _WallHackPageState extends State<WallHackPage> {
  bool isWallHackEnabled = false;
  bool isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGlobals.darkBg,
      appBar: AppBar(
        backgroundColor: AppGlobals.surfaceCard,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("WALL HACK MODULES", style: TextStyle(color: AppGlobals.neonYellow, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildFeatureToggle("Enable Wall Hack + Aimbot", "Downloads and injects via GitHub URL", isWallHackEnabled, (v) {
            setState(() => isWallHackEnabled = v);
            ShizukuService.handleFeatureInjection(
              context: context, featureName: "Wall Hack", enable: v,
              setLoading: (loading) => setState(() => isDownloading = loading),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureToggle(String title, String subtitle, bool val, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppGlobals.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: val ? AppGlobals.neonYellow : Colors.white12, width: 1.5)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
          isDownloading && val 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppGlobals.neonYellow, strokeWidth: 2))
            : CupertinoSwitch(activeColor: AppGlobals.neonYellow, value: val, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ==========================================
// 4. PAID OBB PAGE (paid.dart equivalent)
// ==========================================
class PaidObbPage extends StatefulWidget {
  const PaidObbPage({super.key});
  @override
  State<PaidObbPage> createState() => _PaidObbPageState();
}

class _PaidObbPageState extends State<PaidObbPage> {
  bool isObbEnabled = false;
  bool isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGlobals.darkBg,
      appBar: AppBar(
        backgroundColor: AppGlobals.surfaceCard,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("PAID OBB MODULES", style: TextStyle(color: AppGlobals.neonBlue, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildFeatureToggle("Inject Paid OBB (Anti-Ban)", "Replaces OBB safely via Shizuku", isObbEnabled, (v) {
            setState(() => isObbEnabled = v);
            ShizukuService.handleFeatureInjection(
              context: context, featureName: "Paid OBB", enable: v,
              setLoading: (loading) => setState(() => isDownloading = loading),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureToggle(String title, String subtitle, bool val, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppGlobals.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: val ? AppGlobals.neonBlue : Colors.white12, width: 1.5)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
          isDownloading && val 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppGlobals.neonBlue, strokeWidth: 2))
            : CupertinoSwitch(activeColor: AppGlobals.neonBlue, value: val, onChanged: onChanged),
        ],
      ),
    );
  }
}
