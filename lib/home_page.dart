import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('com.raaz.gaming/shizuku');

  bool ipad = false;
  bool isDarkMode = true;
  bool isShizukuConnected = false;
  bool isDownloading = false;

  final String fileUrl =
      "https://github.com/rajamransri-blip/Gfx/releases/download/Pak/mini_obbzsdic_obb.pak";
  final String fileName = "mini_obbzsdic_obb.pak";

  final List<String> sliderImages = [
    "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=800&q=80"
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _sliderTimer;

  final String bgmiPakPath =
      "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks";

  // Gaming UI Colors inspired by the uploaded image
  final Color neonBlue = const Color(0xFF00D4FF);
  final Color neonOrange = const Color(0xFFFF9900);
  final Color neonGreen = const Color(0xFF00FF00);
  final Color neonRed = const Color(0xFFFF003C);
  final Color neonPurple = const Color(0xFFB026FF);
  final Color darkSurface = const Color(0xFF0A0A12);
  final Color panelBackground = const Color(0xFF151522);

  @override
  void initState() {
    super.initState();
    _startAutoSlider();
    _autoDetectAndConnectShizuku();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sliderTimer?.cancel();
    super.dispose();
  }

  void _startAutoSlider() {
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < sliderImages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  Future<void> _autoDetectAndConnectShizuku() async {
    try {
      final bool isServiceRunning =
          await platform.invokeMethod('isShizukuServiceRunning');

      if (!isServiceRunning) {
        setState(() => isShizukuConnected = false);
        _showSnackBar("❌ Shizuku Service is stopped. Please start it.", neonRed);
        return;
      }

      final bool hasPermission =
          await platform.invokeMethod('checkPermission');
      if (hasPermission) {
        setState(() => isShizukuConnected = true);
      } else {
        final bool granted =
            await platform.invokeMethod('requestPermission');
        if (granted) {
          setState(() => isShizukuConnected = true);
          _showSnackBar("⚡ Shizuku Connected Successfully!", neonGreen);
        } else {
          _showSnackBar("⚠️ Permission Denied by User!", neonOrange);
        }
      }
    } catch (e) {
      setState(() => isShizukuConnected = false);
      _showSnackBar("❌ Failed to communicate with Shizuku", neonRed);
    }
  }

  Future<void> handleIpadView(bool enable) async {
    if (!isShizukuConnected && enable) {
      setState(() => ipad = false);
      _autoDetectAndConnectShizuku();
      return;
    }

    setState(() => isDownloading = true);
    try {
      await Permission.storage.request();
      final raazPath = "/storage/emulated/0/Raaz";
      final sourceFile = "$raazPath/$fileName";

      await platform.invokeMethod(
          'executeCommand', {'command': 'mkdir -p $raazPath'});

      if (enable) {
        final directory = await getExternalStorageDirectory();
        final localRaazFolder = Directory("${directory!.path}/Raaz");
        if (!localRaazFolder.existsSync()) {
          localRaazFolder.createSync(recursive: true);
        }
        final file = File("${localRaazFolder.path}/$fileName");

        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode == 200 || response.statusCode == 302) {
          await file.writeAsBytes(response.bodyBytes);
          await platform.invokeMethod('executeCommand',
              {'command': 'cp "${file.path}" "$sourceFile"'});
          await platform.invokeMethod(
              'executeCommand', {'command': 'mkdir -p $bgmiPakPath'});
          final bool success = await platform.invokeMethod('executeCommand',
              {'command': 'cp "$sourceFile" "$bgmiPakPath/$fileName"'});

          if (success) {
            _showSnackBar("✅ Applied to BGMI Android/data!", neonGreen);
            setState(() => ipad = true);
          } else {
            throw Exception("Shizuku failed to paste");
          }
        }
      } else {
        await platform.invokeMethod('executeCommand',
            {'command': 'rm -f "$bgmiPakPath/$fileName"'});
        await platform.invokeMethod(
            'executeCommand', {'command': 'rm -f "$sourceFile"'});
        _showSnackBar("❌ Removed from BGMI!", neonOrange);
        setState(() => ipad = false);
      }
    } catch (e) {
      _showSnackBar("Error: $e", neonRed);
      setState(() => ipad = !enable);
    } finally {
      setState(() => isDownloading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          backgroundColor: color.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: color, width: 1.5)),
          elevation: 10,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? panelBackground.withOpacity(0.95)
                    : Colors.white.withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(
                    color: isDarkMode
                        ? neonBlue.withOpacity(0.5)
                        : Colors.grey.shade300,
                    width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                          color: isDarkMode ? neonBlue : Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isDarkMode
                              ? [BoxShadow(color: neonBlue, blurRadius: 5)]
                              : [])),
                  const SizedBox(height: 24),
                  Text("CONFIG SETTINGS",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: isDarkMode ? Colors.white : Colors.black)),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black45
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: isDarkMode
                              ? Colors.white12
                              : Colors.grey.shade300),
                    ),
                    child: ListTile(
                      leading: Icon(
                          isDarkMode
                              ? CupertinoIcons.moon_stars_fill
                              : CupertinoIcons.sun_max_fill,
                          color: isDarkMode ? neonOrange : Colors.orange),
                      title: Text("Dark Gaming Mode",
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold)),
                      trailing: CupertinoSwitch(
                          activeColor: neonOrange,
                          value: isDarkMode,
                          onChanged: (v) {
                            setModalState(() => isDarkMode = v);
                            setState(() => isDarkMode = v);
                          }),
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? darkSurface : const Color(0xFFF0F0F5),
      body: Container(
        decoration: isDarkMode
            ? BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.2,
                  colors: [
                    const Color(0xFF1A1A2E), // Subtle dark blue glow top
                    darkSurface,
                    Colors.black,
                  ],
                ),
              )
            : null,
        child: SafeArea(
          child: Column(
            children: [
              // Custom Gaming App Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SK VIP",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: isDarkMode ? Colors.white : Colors.black,
                            letterSpacing: 2,
                            shadows: isDarkMode
                                ? [
                                    BoxShadow(
                                        color: Colors.white.withOpacity(0.5),
                                        blurRadius: 10)
                                  ]
                                : [],
                          ),
                        ),
                        Text(
                          "CONFIG • POWERED BY SHIZUKU",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: isDarkMode ? neonOrange : Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: isDarkMode
                            ? [
                                BoxShadow(
                                    color: neonBlue.withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2)
                              ]
                            : [],
                      ),
                      child: IconButton(
                        icon: Icon(CupertinoIcons.settings_solid,
                            color: isDarkMode ? neonBlue : Colors.black87),
                        onPressed: _showSettingsPanel,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Shizuku Connection Status Card
                    GestureDetector(
                      onTap: _autoDetectAndConnectShizuku,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? panelBackground : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isShizukuConnected
                                ? neonGreen
                                : (isDarkMode ? neonRed : Colors.red),
                            width: 2,
                          ),
                          boxShadow: isDarkMode
                              ? [
                                  BoxShadow(
                                    color: (isShizukuConnected
                                            ? neonGreen
                                            : neonRed)
                                        .withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10)
                                ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isShizukuConnected && isDarkMode)
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: neonGreen, blurRadius: 10)
                                      ],
                                    ),
                                  ),
                                Icon(
                                  isShizukuConnected
                                      ? Icons.offline_bolt_rounded
                                      : Icons.warning_rounded,
                                  color: isShizukuConnected
                                      ? neonGreen
                                      : neonRed,
                                  size: 32,
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isShizukuConnected
                                        ? "SHIZUKU ACTIVE"
                                        : "SHIZUKU DISCONNECTED",
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isShizukuConnected
                                        ? "System ready to inject configurations."
                                        : "Tap here to initialize service.",
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Section Title
                    Center(
                      child: Text(
                        "PREMIUM FEATURES",
                        style: TextStyle(
                          color: isDarkMode ? neonBlue : Colors.blueAccent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Feature Card (iPad View)
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? panelBackground : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ipad
                              ? (isDarkMode ? neonOrange : Colors.orange)
                              : (isDarkMode
                                  ? neonBlue.withOpacity(0.3)
                                  : Colors.grey.shade300),
                          width: ipad ? 2 : 1.5,
                        ),
                        boxShadow: (ipad && isDarkMode)
                            ? [
                                BoxShadow(
                                  color: neonOrange.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ]
                            : [
                                if (!isDarkMode)
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10)
                              ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.black45
                                        : Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white12
                                            : Colors.transparent),
                                  ),
                                  child: Icon(Icons.tablet_mac_rounded,
                                      color: isDarkMode
                                          ? neonPurple
                                          : Colors.purple,
                                      size: 32),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "IPAD VIEW",
                                        style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            letterSpacing: 1),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Wide-angle FOV support (PAK)",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600),
                                      )
                                    ],
                                  ),
                                ),
                                isDownloading
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                            right: 8.0),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              color: neonOrange,
                                              strokeWidth: 3),
                                        ),
                                      )
                                    : Transform.scale(
                                        scale: 0.9,
                                        child: CupertinoSwitch(
                                          activeColor: neonOrange,
                                          trackColor: isDarkMode
                                              ? Colors.white12
                                              : Colors.grey.shade300,
                                          value: ipad,
                                          onChanged: (v) async {
                                            setState(() => ipad = v);
                                            await handleIpadView(v);
                                          },
                                        ),
                                      ),
                              ],
                            ),
                            if (ipad) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                decoration: BoxDecoration(
                                  color: (isDarkMode
                                          ? neonOrange
                                          : Colors.orange)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    "STATUS: INJECTED & ACTIVE",
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? neonOrange
                                          : Colors.orange.shade800,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Showcase / Auto Slider
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isDarkMode
                            ? [
                                BoxShadow(
                                    color: neonBlue.withOpacity(0.15),
                                    blurRadius: 20,
                                    spreadRadius: 5)
                              ]
                            : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: sliderImages.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(sliderImages[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.8),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Slider Indicator Dots
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  sliderImages.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    height: 6,
                                    width: _currentPage == index ? 24 : 8,
                                    decoration: BoxDecoration(
                                      color: _currentPage == index
                                          ? neonBlue
                                          : Colors.white54,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Trust Badge
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: neonOrange, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.shield_rounded,
                                        color: neonOrange, size: 14),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "100% SAFE",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
