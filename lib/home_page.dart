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

  final String fileUrl = "https://github.com/rajamransri-blip/Gfx/releases/download/Pak/mini_obbzsdic_obb.pak";
  final String fileName = "mini_obbzsdic_obb.pak";

  final List<String> sliderImages = [
    "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=800&q=80"
  ];
  final String feedbackImageUrl = "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=800&q=80";
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _sliderTimer;

  final String bgmiPakPath = "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks";

  @override
  void initState() {
    super.initState();
    _startAutoSlider();
    _checkShizukuStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sliderTimer?.cancel();
    super.dispose();
  }

  void _startAutoSlider() {
    _sliderTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < 2) _currentPage++; else _currentPage = 0;
      if (_pageController.hasClients) _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  Future<void> _checkShizukuStatus() async {
    try {
      final bool hasPermission = await platform.invokeMethod('checkPermission');
      setState(() => isShizukuConnected = hasPermission);
    } catch (e) {
      setState(() => isShizukuConnected = false);
    }
  }

  Future<void> _connectShizuku() async {
    try {
      await platform.invokeMethod('requestPermission');
      await Future.delayed(const Duration(seconds: 2));
      await _checkShizukuStatus();
      if (isShizukuConnected) _showSnackBar("⚡ Shizuku Connected!", Colors.green);
    } catch (e) {
      _showSnackBar("❌ Shizuku not running in background!", Colors.red);
    }
  }

  Future<void> handleIpadView(bool enable) async {
    if (!isShizukuConnected && enable) {
      setState(() => ipad = false);
      _showSnackBar("❌ Connect Shizuku First!", Colors.red);
      return;
    }
    setState(() => isDownloading = true);
    try {
      await Permission.storage.request();
      final raazPath = "/storage/emulated/0/Raaz";
      final sourceFile = "$raazPath/$fileName";

      await platform.invokeMethod('executeCommand', {'command': 'mkdir -p $raazPath'});

      if (enable) {
        final directory = await getExternalStorageDirectory();
        final localRaazFolder = Directory("${directory!.path}/Raaz");
        if (!localRaazFolder.existsSync()) localRaazFolder.createSync(recursive: true);
        final file = File("${localRaazFolder.path}/$fileName");

        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode == 200 || response.statusCode == 302) {
          await file.writeAsBytes(response.bodyBytes);
          await platform.invokeMethod('executeCommand', {'command': 'cp "${file.path}" "$sourceFile"'});
          await platform.invokeMethod('executeCommand', {'command': 'mkdir -p $bgmiPakPath'});
          final bool success = await platform.invokeMethod('executeCommand', {'command': 'cp "$sourceFile" "$bgmiPakPath/$fileName"'});
          
          if (success) {
            _showSnackBar("✅ Applied to BGMI Android/data!", Colors.green);
            setState(() => ipad = true);
          } else { throw Exception("Shizuku failed to paste"); }
        }
      } else {
        await platform.invokeMethod('executeCommand', {'command': 'rm -f "$bgmiPakPath/$fileName"'});
        await platform.invokeMethod('executeCommand', {'command': 'rm -f "$sourceFile"'});
        _showSnackBar("❌ Removed from BGMI!", Colors.orange);
        setState(() => ipad = false);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
      setState(() => ipad = !enable);
    } finally {
      setState(() => isDownloading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: color));
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text("Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                  ListTile(
                    leading: const Icon(CupertinoIcons.moon_stars_fill), title: Text("Dark Mode", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                    trailing: CupertinoSwitch(value: isDarkMode, onChanged: (v) { setModalState(() => isDarkMode = v); setState(() => isDarkMode = v); }),
                  ),
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
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.transparent,
        title: Text("Gamer Pro Tool", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: Icon(CupertinoIcons.settings, color: isDarkMode ? Colors.white : Colors.black), onPressed: _showSettingsPanel)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GestureDetector(
            onTap: _connectShizuku,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isShizukuConnected ? Colors.green.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: isShizukuConnected ? Colors.green : Colors.redAccent)),
              child: Row(children: [
                Icon(isShizukuConnected ? Icons.check_circle : Icons.warning_rounded, color: isShizukuConnected ? Colors.green : Colors.redAccent, size: 30),
                const SizedBox(width: 12),
                Expanded(child: Text(isShizukuConnected ? "Shizuku Connected! Ready to apply." : "Tap here to connect Shizuku", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold))),
              ]),
            ),
          ),
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _pageController, itemCount: sliderImages.length,
              itemBuilder: (context, index) => Container(margin: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(sliderImages[index]), fit: BoxFit.cover))),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF232323) : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.tablet_mac, color: Colors.purpleAccent, size: 30), const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("iPad View (.pak)", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)), const Text("Apply directly via Shizuku", style: TextStyle(fontSize: 12, color: Colors.grey))])),
              isDownloading ? const CircularProgressIndicator() : CupertinoSwitch(value: ipad, onChanged: (v) async { setState(() => ipad = v); await handleIpadView(v); })
            ]),
          )
        ],
      ),
    );
  }
}
