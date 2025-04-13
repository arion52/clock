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
      _showConnectionDialog();
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
          style: GoogleFonts.agdasima(
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

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          "Pick a Text Color",
          style: GoogleFonts.agdasima(
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
        ),
        content: SizedBox(
          height: 240,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              enableAlpha: false,
              labelTypes: const [ColorLabelType.rgb],
              pickerAreaHeightPercent: 0.8,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Done",
              style: GoogleFonts.agdasima(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _buildTextStyle() {
    return GoogleFonts.agdasimaTextTheme().displayLarge!.copyWith(
          fontSize: 125,
          color: _selectedColor,
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

          // Connect button - now with black background
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              heroTag: "connect",
              backgroundColor: Colors.black,
              onPressed: _showConnectionDialog,
              child: Icon(
                isConnected ? Icons.wifi : Icons.wifi_off,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
          ),

          // 🎨 Color Picker FAB
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: "color",
              backgroundColor: _selectedColor,
              onPressed: _openColorPicker,
              child: const Icon(Icons.palette, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

