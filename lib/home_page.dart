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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('com.raaz.gaming/shizuku');

  // App Main State States
  bool isDarkMode = true;
  bool isShizukuConnected = false;
  bool isDownloading = false;

  // Feature Toggles State Maps
  bool ipadView = false;
  final Map<String, bool> wallHackFeatures = {
    "Wall Hack Plus Aimbot": false,
    "Wall Hack Plus No Recoil": false,
    "Only Wall Hack": false,
    "Wall Hack Plus Skins": false,
    "120 FPS Enable": false,
  };

  final Map<String, bool> obbFeatures = {
    "Antina Plus Aimbot": false,
    "Antina Plus Magic Bullet": false,
    "Only Aimbot": false,
    "Only Magic Bullet": false,
    "One Time Apply OBB": false,
    "Full Season Safe": false,
  };

  final Map<String, bool> espFeatures = {
    "ESP 400 Meter": false,
    "Aimbot 400 Meter": false,
    "Height Recorder": false,
    "Bullet Track 200 Meter": false,
    "Anti Ten Year": false,
    "No 1 Day": false,
    "No 7 Day": false,
  };

  final String fileUrl = "https://github.com/rajamransri-blip/Gfx/releases/download/Pak/mini_obbzsdic_obb.pak";
  final String fileName = "mini_obbzsdic_obb.pak";
  final String bgmiPakPath = "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks";

  // Pure Image Theme Colors (Cyberpunk Premium Palette)
  final Color neonYellow = const Color(0xFFFFCC00);
  final Color neonBlue = const Color(0xFF00D4FF);
  final Color neonPurple = const Color(0xFFB026FF);
  final Color neonGreen = const Color(0xFF00FF66);
  final Color neonOrange = const Color(0xFFFF6600);
  final Color neonCyan = const Color(0xFF00FFFF);
  final Color darkBg = const Color(0xFF07070C);
  final Color surfaceCard = const Color(0xFF11111E);

  @override
  void initState() {
    super.initState();
    _autoDetectAndConnectShizuku();
  }

  // Auto Binder & Shizuku Authorization Hook
  Future<void> _autoDetectAndConnectShizuku() async {
    try {
      final bool isServiceRunning = await platform.invokeMethod('isShizukuServiceRunning');
      if (!isServiceRunning) {
        setState(() => isShizukuConnected = false);
        return;
      }
      final bool hasPermission = await platform.invokeMethod('checkPermission');
      if (hasPermission) {
        setState(() => isShizukuConnected = true);
      } else {
        final bool granted = await platform.invokeMethod('requestPermission');
        setState(() => isShizukuConnected = granted);
      }
    } catch (e) {
      setState(() => isShizukuConnected = false);
    }
  }

  // Unified File Injector Engine
  Future<void> handleFeatureInjection(String featureName, bool enable) async {
    if (!isShizukuConnected && enable) {
      _showSnackBar("⚠️ Please start and authorize Shizuku first!", neonOrange);
      _autoDetectAndConnectShizuku();
      return;
    }

    setState(() => isDownloading = true);
    try {
      await Permission.storage.request();
      final targetPath = "/storage/emulated/0/Raaz";
      
      // Execute directory allocation commands via Shizuku shell
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
            _showSnackBar("⚡ $featureName Injected Successfully!", neonGreen);
          } else {
            throw Exception("Shizuku processing validation failure");
          }
        }
      } else {
        await platform.invokeMethod('executeCommand', {'command': 'rm -f "$bgmiPakPath/$fileName"'});
        _showSnackBar("🗑️ $featureName Disabled & Cleaned!", neonYellow);
      }
    } catch (e) {
      _showSnackBar("Inject Error: ${e.toString()}", Colors.redAccent);
    } finally {
      setState(() => isDownloading = false);
    }
  }

  void _showSnackBar(String message, Color borderGlowColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: surfaceCard.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderGlowColor, width: 2),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Modernized System Control & Configuration Hub Sheet
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceCard.withOpacity(0.98),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: neonBlue.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 50, height: 4, decoration: BoxDecoration(color: neonBlue, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 24),
                  const Text("GLOBAL RADAR CONTROL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 20),
                  ListTile(
                    tileColor: Colors.black26, // ✅ Fixed Error Here (Changed from black25 to black26)
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(Icons.cached_rounded, color: isShizukuConnected ? neonGreen : neonOrange),
                    title: const Text("Shizuku Status Core", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(isShizukuConnected ? "Authorized & Connected" : "Service Inactive", style: TextStyle(color: Colors.grey.shade400)),
                    trailing: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: isShizukuConnected ? neonGreen.withOpacity(0.2) : neonOrange.withOpacity(0.2),
                      onPressed: () async {
                        await _autoDetectAndConnectShizuku();
                        setModalState(() {});
                      },
                      child: Text(isShizukuConnected ? "REFRESH" : "CONNECT", style: TextStyle(color: isShizukuConnected ? neonGreen : neonOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    title: const Text("Dark Matrix Theme", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    value: isDarkMode,
                    activeColor: neonBlue,
                    onChanged: (v) {
                      setModalState(() => isDarkMode = v);
                      setState(() => isDarkMode = v);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? darkBg : const Color(0xFFF4F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header Bar Implementation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SK VIP",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: isDarkMode ? Colors.white : Colors.black,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        "CONFIG • POWERED BY SHIZUKU",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.8, color: neonOrange),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.settings_solid, color: neonBlue, size: 28),
                    onPressed: _showSettingsPanel,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Dynamic System Connection Status Banner Card
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isShizukuConnected ? neonGreen : neonOrange, width: 2),
                      boxShadow: [
                        BoxShadow(color: (isShizukuConnected ? neonGreen : neonOrange).withOpacity(0.15), blurRadius: 12, spreadRadius: 1)
                      ],
                    ),
                    child: InkWell(
                      onTap: _autoDetectAndConnectShizuku,
                      child: Row(
                        children: [
                          Icon(isShizukuConnected ? Icons.gpp_good_rounded : Icons.gpp_maybe_rounded, color: isShizukuConnected ? neonGreen : neonOrange, size: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isShizukuConnected ? "SHIZUKU CONNECTED" : "SHIZUKU DISCONNECTED",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isShizukuConnected ? "System bypass active. Ready for feature injection." : "Tap here to initialize backend system interface.",
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Plans horizontal matrix slider row
                  _buildSectionTitle("OUR SYSTEM BUNDLES"),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 125,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildPlanCard("WALL HACK", "₹399", "FULL SEASON", neonYellow),
                        _buildPlanCard("PAID OBB", "₹399", "FULL SEASON", neonBlue),
                        _buildPlanCard("ESP", "₹100", "1 DAY ACCESS", neonPurple),
                        _buildPlanCard("ESP PRO", "₹399", "7 DAYS TRIAL", neonGreen),
                        _buildPlanCard("ESP ULTRA", "₹799", "30 DAYS CORE", neonCyan),
                        _buildPlanCard("ESP VIP", "₹1200", "FULL SEASON", neonOrange),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle("CORE INJECTOR SWITCHES"),
                  const SizedBox(height: 12),

                  // Standalone Core Feature Toggle
                  _buildCoreToggleCard("IPAD VIEW SYSTEM", "Wide-angle peripheral FOV calibration (.pak)", ipadView, (v) {
                    setState(() => ipadView = v);
                    handleFeatureInjection("iPad View", v);
                  }, neonCyan, Icons.tablet_mac_rounded),

                  const SizedBox(height: 20),

                  // Category feature grids matching image parameters
                  _buildFeatureCategoryBlock("WALL HACK PANEL FEATURES", wallHackFeatures, neonYellow, Icons.grid_view_rounded),
                  const SizedBox(height: 16),
                  _buildFeatureCategoryBlock("PAID OBB ENHANCED MODULES", obbFeatures, neonBlue, Icons.developer_board_rounded),
                  const SizedBox(height: 16),
                  _buildFeatureCategoryBlock("ESP AIMBOT SECURITY PACKS", espFeatures, neonGreen, Icons.remove_red_eye_rounded),

                  const SizedBox(height: 28),
                  _buildSectionTitle("SYSTEM SECURITY COMPLIANCE"),
                  const SizedBox(height: 12),

                  // Matrix parameters indicators grid row
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.95,
                    children: [
                      _buildSecurityMetricCard("ANTI 10 YEAR", "PROTECTION", Icons.shield_outlined, neonBlue),
                      _buildSecurityMetricCard("NO FLAG ALERT", "SECURE SAFE", Icons.outlined_flag_rounded, neonGreen),
                      _buildSecurityMetricCard("PREMIUM", "LOADER PACK", Icons.diamond_outlined, neonYellow),
                      _buildSecurityMetricCard("100% SECURE", "ENCRYPTED", Icons.lock_outline_rounded, neonPurple),
                      _buildSecurityMetricCard("SMOOTH AIM", "CALIBRATED", Icons.track_changes_rounded, neonOrange),
                      _buildSecurityMetricCard("WALL HACK", "SUPPORT DESK", Icons.headset_mic_outlined, neonCyan),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: neonBlue, fontWeight: FontWeight.w900, letterSpacing: 2.5, fontSize: 13),
      ),
    );
  }

  // Component Builder for the Horizontal Matrix Purchase Cards
  Widget _buildPlanCard(String title, String price, String duration, Color accentColor) {
    return Container(
      width: 115,
      margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 6, spreadRadius: 1)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
          const Spacer(),
          Text(price, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 19)),
          const Spacer(),
          Text(duration, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text("FREE UNLOCK", style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Component Builder for Individual Main Option Toggle Switches
  Widget _buildCoreToggleCard(String title, String subtitle, bool currentVal, Function(bool) stateSetter, Color neonColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentVal ? neonColor : Colors.white12, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: neonColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
          isDownloading && currentVal 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : CupertinoSwitch(
                  activeColor: neonColor,
                  value: currentVal,
                  onChanged: stateSetter,
                ),
        ],
      ),
    );
  }

  // Component Builder for Interactive Group Feature Expansion Boxes
  Widget _buildFeatureCategoryBlock(String categoryTitle, Map<String, bool> featureMap, Color themeNeon, IconData categoryIcon) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeNeon.withOpacity(0.3), width: 1.5),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(categoryIcon, color: themeNeon),
          title: Text(categoryTitle, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          children: featureMap.keys.map((String key) {
            return CheckboxListTile(
              activeColor: themeNeon,
              checkColor: Colors.black,
              title: Text(key, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              value: featureMap[key],
              onChanged: (bool? value) {
                setState(() {
                  featureMap[key] = value ?? false;
                });
                handleFeatureInjection(key, value ?? false);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // Component Builder for Bottom Guard/Security Matrix Parameter Tiles
  Widget _buildSecurityMetricCard(String row1, String row2, IconData iconData, Color componentNeon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, color: componentNeon, size: 26),
          const SizedBox(height: 8),
          Text(row1, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(row2, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 8, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
