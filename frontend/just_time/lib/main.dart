// ignore_for_file: unrelated_type_equality_checks, invalid_return_type_for_catch_error, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen + Landscape
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ClockApp());
}

class ClockApp extends StatelessWidget {
  const ClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const ClockScreen(),
    );
  }
}

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  late String _timeString;
  WebSocketChannel? channel;
  bool isConnected = false;
  Color _selectedColor = const Color.fromARGB(255, 0, 255, 255); // Default neon blue
  String? savedServerIP;
  final TextEditingController _ipController = TextEditingController();
  
  // Font selection
  String _selectedFontFamily = 'Agdasima';
  final List<String> _availableFonts = [
    'Agdasima',
    'Orbitron',
    'Play',
    'Audiowide',
    'Wallpoet',
    'Teko',
    'VT323',
    'Press Start 2P',
    'Rajdhani',
    'Oxanium',
  ];
  
  // Status message to display connection state
  String statusMessage = "Not connected";

  @override
  void initState() {
    super.initState();
    _updateTime();
    Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    WakelockPlus.enable();
    
    // Try to auto-connect if we have a saved IP
    _loadSavedIP();
  }

  // Load the saved IP from persistent storage
  void _loadSavedIP() async {
    // In a real app, you would use SharedPreferences here
    // For simplicity, we'll just try a default IP
    savedServerIP = "172.20.180.144"; // Default IP to try
    _ipController.text = savedServerIP ?? "";
    
    // Try to connect with the saved IP if available
    if (savedServerIP != null && savedServerIP!.isNotEmpty) {
      _connectWebSocket(savedServerIP!);
    } else {
      _showConnectionDialog();
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${_pad(now.hour)}:${_pad(now.minute)}";
    });
  }

  String _pad(int num) => num.toString().padLeft(2, '0');

  void sendVolumeCommand(String command) {
    if (isConnected && channel != null) {
      channel!.sink.add(command);
      // No notification as requested
    } else {
      // Show reconnect option
      setState(() {
        statusMessage = "Not connected";
      });
      _showSettingsMenu(); // Open settings with connection tab active
    }
  }

  Future<bool> _isIPReachable(String ip) async {
    try {
      // Simple connectivity check
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // A more direct test: try to connect to the websocket server
      final socket = await Socket.connect(ip, 8765, 
          timeout: const Duration(seconds: 2))
        .catchError((_) {
          return null;
        });
      
      if (socket != null) {
        socket.destroy();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _connectWebSocket(String serverIp) async {
    setState(() {
      statusMessage = "Connecting...";
    });
    
    // Check if the IP is reachable first
    bool isReachable = await _isIPReachable(serverIp);
    
    if (!isReachable) {
      setState(() {
        statusMessage = "Cannot reach $serverIp";
        isConnected = false;
      });
      return;
    }
    
    try {
      final wsUrl = "ws://$serverIp:8765";
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      channel!.stream.listen(
        (message) {
          print("Received: $message");
        },
        onDone: () {
          print("WebSocket connection closed");
          setState(() {
            isConnected = false;
            statusMessage = "Disconnected";
          });
        },
        onError: (error) {
          print("WebSocket error: $error");
          setState(() {
            isConnected = false;
            statusMessage = "Connection error";
          });
        },
      );
      
      // Save the successful IP address
      savedServerIP = serverIp;
      
      setState(() {
        isConnected = true;
        statusMessage = "Connected to $serverIp";
      });
      
    } catch (e) {
      print("Failed to connect: $e");
      setState(() {
        isConnected = false;
        statusMessage = "Failed to connect";
      });
    }
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Connect to PC',
          style: GoogleFonts.getFont(
            _selectedFontFamily,
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
        ),
        content: SizedBox(
          width: 250,
          child: Wrap(
            children: [
              const Text(
                'Enter the IP address of your PC',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16, width: double.infinity),
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '192.168.1.x',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _selectedColor),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8, width: double.infinity),
              Text(
                'Make sure your Python server is running on the PC',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              String ip = _ipController.text.trim();
              if (ip.isNotEmpty) {
                _connectWebSocket(ip);
              }
            },
            child: Text(
              'Connect',
              style: TextStyle(color: _selectedColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Handle indicator at top
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Settings title
              Text(
                'Settings',
                style: GoogleFonts.getFont(
                  _selectedFontFamily,
                  textStyle: TextStyle(
                    color: _selectedColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Connection option
              ListTile(
                leading: Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                title: const Text('Connection', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  statusMessage,
                  style: TextStyle(
                    color: isConnected ? Colors.green[300] : Colors.red[300],
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showConnectionScreen();
                },
              ),
              
              // Font option
              ListTile(
                leading: Icon(Icons.font_download, color: _selectedColor),
                title: const Text('Font', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _selectedFontFamily,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showFontScreen();
                },
              ),
              
              // Color option
              ListTile(
                leading: Icon(Icons.palette, color: _selectedColor),
                title: const Text('Color', style: TextStyle(color: Colors.white)),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showColorScreen();
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Create separate screen for connection settings
  void _showConnectionScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              'Connection',
              style: GoogleFonts.getFont(
                _selectedFontFamily,
                textStyle: TextStyle(
                  color: _selectedColor,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: _selectedColor,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Connect to your PC",
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '192.168.1.x',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _selectedColor),
                      ),
                      prefixIcon: Icon(
                        isConnected ? Icons.wifi : Icons.wifi_off,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: _selectedColor,
                        minimumSize: const Size(200, 48),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Connect'),
                      onPressed: () {
                        String ip = _ipController.text.trim();
                        if (ip.isNotEmpty) {
                          _connectWebSocket(ip);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    "Make sure your Python server is running on the PC at the specified IP address. The server should be listening on port 8765 for WebSocket connections.",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Create separate screen for font settings
  void _showFontScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              'Font Selection',
              style: GoogleFonts.getFont(
                _selectedFontFamily,
                textStyle: TextStyle(
                  color: _selectedColor,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: _selectedColor,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: Text(
                      "Choose a font for your clock",
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableFonts.length,
                      itemBuilder: (context, index) {
                        final font = _availableFonts[index];
                        final isSelected = font == _selectedFontFamily;
                        
                        return Card(
                          color: isSelected ? Colors.grey[900] : Colors.black,
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              "12:34",
                              style: GoogleFonts.getFont(
                                font,
                                textStyle: TextStyle(
                                  color: isSelected ? _selectedColor : Colors.white,
                                  fontSize: 40,
                                ),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                font,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            selected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedFontFamily = font;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Create separate screen for color settings
  void _showColorScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setColorState) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                title: Text(
                  'Color Selection',
                  style: GoogleFonts.getFont(
                    _selectedFontFamily,
                    textStyle: TextStyle(
                      color: _selectedColor,
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: _selectedColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Preview box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                              color: Colors.grey[800]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              "12:34",
                              style: GoogleFonts.getFont(
                                _selectedFontFamily,
                                textStyle: TextStyle(
                                  color: _selectedColor,
                                  fontSize: 60,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Select a color for your clock",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ColorPicker(
                          pickerColor: _selectedColor,
                          onColorChanged: (color) {
                            setColorState(() {
                              _selectedColor = color;
                            });
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          enableAlpha: false,
                          labelTypes: const [ColorLabelType.rgb, ColorLabelType.hex],
                          pickerAreaHeightPercent: 0.8,
                          displayThumbColor: true,
                        ),
                        const SizedBox(height: 16),
                        // Color presets - popular neon colors
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildColorPreset(Colors.cyan, setColorState),
                              _buildColorPreset(Colors.pink, setColorState),
                              _buildColorPreset(Colors.green.shade500, setColorState),
                              _buildColorPreset(Colors.purple.shade300, setColorState),
                              _buildColorPreset(Colors.orange.shade300, setColorState),
                              _buildColorPreset(Colors.blue.shade300, setColorState),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

Widget _buildColorPreset(Color color, Function setColorState) {
  return GestureDetector(
    onTap: () {
      setColorState(() {
        _selectedColor = color;
      });
      setState(() {
        _selectedColor = color;
      });
    },
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: _selectedColor == color ? Colors.white : Colors.grey[800]!,
          width: _selectedColor == color ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    ),
  );
}
  TextStyle _buildTextStyle() {
    return GoogleFonts.getFont(
      _selectedFontFamily,
      textStyle: TextStyle(
        fontSize: 125,
        color: _selectedColor,
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Clock Text
          Center(
            child: Text(_timeString, style: _buildTextStyle()),
          ),

          // Status indicator
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: isConnected ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Left Controls
          Positioned(
            left: 20,
            top: 100,
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => sendVolumeCommand("play_pause"),
                  iconSize: 28,
                  color: _selectedColor,
                  splashRadius: 20,
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => sendVolumeCommand("previous_track"),
                  iconSize: 28,
                  color: _selectedColor,
                  splashRadius: 20,
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => sendVolumeCommand("next_track"),
                  iconSize: 28,
                  color: _selectedColor,
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // Right Controls
          Positioned(
            right: 20,
            top: 100,
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => sendVolumeCommand("volume_up"),
                  iconSize: 28,
                  color: _selectedColor,
                  splashRadius: 20,
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.volume_off),
                  onPressed: () => sendVolumeCommand("mute"),
                  iconSize: 28,
                  color: _selectedColor,
                  splashRadius: 20,
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.volume_down),
                  onPressed: () => sendVolumeCommand("volume_down"),
                  iconSize: 28,
                  color: _selectedColor,
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // Settings button - Single button now
          // Replace the settings button in the build method with this
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: "settings",
              backgroundColor: Colors.black,
              onPressed: () => _showSettingsMenu(),
              child: Icon(
                Icons.settings,
                color: _selectedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}