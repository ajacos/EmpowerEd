import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Sidebar extends StatelessWidget {
  final User? user;
  
  const Sidebar({Key? key, this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Color(0xFF1A237E),
      child: Column(
        children: [
          SizedBox(height: 50),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          SizedBox(height: 10),
          Text(
            user?.email?.split('@')[0] ?? 'User',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 30),
          _buildMenuItem(context, 'Home', Icons.home, () => Navigator.pushReplacementNamed(context, '/home')),
          _buildMenuItem(context, 'Video Conference', Icons.video_call, () => Navigator.pushNamed(context, '/video')),
          _buildMenuItem(context, 'Educational Content', Icons.school, () => Navigator.pushReplacementNamed(context, '/education')),
          _buildMenuItem(context, 'Community Forum', Icons.forum, () {}),
          _buildMenuItem(context, 'Resources', Icons.library_books, () {}),
          Spacer(),
          _buildMenuItem(context, 'Logout', Icons.logout, () => _showLogoutConfirmation(context)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1A237E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: Colors.red[300])),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
              },
            ),
          ],
        );
      },
    );
  }
}

class VideoConferenceScreen extends StatefulWidget {
  const VideoConferenceScreen({Key? key}) : super(key: key);

  @override
  _VideoConferenceScreenState createState() => _VideoConferenceScreenState();
}

class _VideoConferenceScreenState extends State<VideoConferenceScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _inCall = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  WebSocketChannel? _socket;
  String _userId = '';
  MediaStream? _localStream;
  Map<String, MediaStream> _remoteStreams = {};
  Map<String, RTCPeerConnection> _peerConnections = {};
  
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  bool _isCreatingRoom = true;

  @override
  void initState() {
    super.initState();
    _userId = DateTime.now().millisecondsSinceEpoch.toString();
    _initRenderers();
    _connectToSignalingServer();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  void _connectToSignalingServer() {
    _socket = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8080?userId=$_userId'),
    );
    _socket!.stream.listen((message) {
      final data = jsonDecode(message);
      _handleSignalingMessage(data);
    }, onError: (error) {
      print('WebSocket error: $error');
    }, onDone: () {
      print('WebSocket connection closed');
    });
  }

  void _handleSignalingMessage(Map<String, dynamic> data) {
    print('Received signaling message: $data');
    switch (data['type']) {
      case 'room-created':
        _showSnackBar('Room created successfully. Room ID: ${data['roomId']}');
        setState(() {
          _inCall = true;
        });
        break;
      case 'user-joined':
        print('User joined: ${data['userId']}');
        _handleUserJoined(data['userId']);
        break;
      case 'user-left':
        print('User left: ${data['userId']}');
        _handleUserLeft(data['userId']);
        break;
      case 'offer':
        print('Received offer from: ${data['userId']}');
        _handleOffer(data['userId'], data['sdp']);
        break;
      case 'answer':
        print('Received answer from: ${data['userId']}');
        _handleAnswer(data['userId'], data['sdp']);
        break;
      case 'ice-candidate':
        print('Received ICE candidate from: ${data['userId']}');
        _handleIceCandidate(data['userId'], data['candidate']);
        break;
      case 'error':
        _showError(data['message']);
        break;
      case 'room-joined':
        _showSnackBar('Joined room successfully');
        setState(() {
          _inCall = true;
        });
        break;
    }
  }

  Future<void> _createRoom() async {
    final roomId = _generateRoomId();
    final password = _passwordController.text;

    if (password.isEmpty) {
      _showError('Please enter a password');
      return;
    }

    try {
      await _initializeLocalStream();
      _socket?.sink.add(jsonEncode({
        'type': 'create-room',
        'roomId': roomId,
        'password': password,
        'userId': _userId,
      }));
      _roomIdController.text = roomId; // Added line to update roomIdController
    } catch (e) {
      print('Error creating room: $e');
      _showError('Failed to create room. Please try again.');
    }
  }

  Future<void> _joinRoom(String roomId) async {
    _roomIdController.text = roomId; // Added line to update roomIdController
    if (roomId.length != 8) {
      _showError('Room ID must be 8 digits');
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      _showError('Please enter a password');
      return;
    }

    try {
      await _initializeLocalStream();
      _socket?.sink.add(jsonEncode({
        'type': 'join-room',
        'roomId': roomId,
        'password': password,
        'userId': _userId,
      }));
    } catch (e) {
      print('Error joining room: $e');
      _showError('Failed to join room. Please try again.');
    }
  }

  Future<void> _initializeLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
      setState(() {});
    } catch (e) {
      print('Error getting user media: $e');
      _showError('Failed to access camera/microphone. Please check your settings and try again.');
    }
  }

  String _generateRoomId() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return random.substring(random.length - 8);
  }

  Future<void> _handleUserJoined(String remoteUserId) async {
    try {
      final pc = await _createPeerConnection(remoteUserId);
      _peerConnections[remoteUserId] = pc;
      await _addLocalStream(pc);
      await _createAndSendOffer(remoteUserId, pc);
    } catch (e) {
      print('Error handling user joined: $e');
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUserId) async {
    print('Creating peer connection for $remoteUserId');
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    });

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        _socket?.sink.add(jsonEncode({
          'type': 'ice-candidate',
          'userId': _userId,
          'targetUserId': remoteUserId,
          'candidate': candidate.toMap(),
        }));
      }
    };

    pc.onTrack = (event) {
      print('Remote track received');
      if (event.streams.isNotEmpty) {
        _remoteStreams[remoteUserId] = event.streams[0];
        _displayRemoteStream(remoteUserId);
      }
    };

    pc.onIceConnectionState = (state) {
      print('ICE connection state for $remoteUserId: ${state.toString()}');
    };

    return pc;
  }

  Future<void> _addLocalStream(RTCPeerConnection pc) async {
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });
  }

  Future<void> _createAndSendOffer(String remoteUserId, RTCPeerConnection pc) async {
    try {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      _socket?.sink.add(jsonEncode({
        'type': 'offer',
        'userId': _userId,
        'targetUserId': remoteUserId,
        'sdp': offer.sdp,
      }));
    } catch (e) {
      print('Error creating and sending offer: $e');
    }
  }

  Future<void> _handleOffer(String remoteUserId, String sdp) async {
    try {
      final pc = await _createPeerConnection(remoteUserId);
      _peerConnections[remoteUserId] = pc;

      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      await _addLocalStream(pc);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socket?.sink.add(jsonEncode({
        'type': 'answer',
        'userId': _userId,
        'targetUserId': remoteUserId,
        'sdp': answer.sdp,
      }));
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  Future<void> _handleAnswer(String remoteUserId, String sdp) async {
    final pc = _peerConnections[remoteUserId];
    if (pc != null) {
      try {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      } catch (e) {
        print('Error setting remote description for answer: $e');
      }
    } else {
      print('No peer connection found for $remoteUserId');
    }
  }

  Future<void> _handleIceCandidate(String remoteUserId, Map<String, dynamic> candidateMap) async {
    final pc = _peerConnections[remoteUserId];
    if (pc != null) {
      try {
        final candidate = RTCIceCandidate(
          candidateMap['candidate'],
          candidateMap['sdpMid'],
          candidateMap['sdpMLineIndex'],
        );
        await pc.addCandidate(candidate);
      } catch (e) {
        print('Error adding ICE candidate: $e');
      }
    } else {
      print('No peer connection found for $remoteUserId');
    }
  }

  void _handleUserLeft(String remoteUserId) {
    final pc = _peerConnections[remoteUserId];
    if (pc != null) {
      pc.close();
      _peerConnections.remove(remoteUserId);
    }
    _remoteStreams.remove(remoteUserId);
    final renderer = _remoteRenderers[remoteUserId];
    if (renderer != null) {
      renderer.dispose();
      _remoteRenderers.remove(remoteUserId);
    }
    setState(() {});
  }

  void _displayRemoteStream(String remoteUserId) async {
    if (!_remoteRenderers.containsKey(remoteUserId)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = _remoteStreams[remoteUserId];
      _remoteRenderers[remoteUserId] = renderer;
      setState(() {});
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = !_isVideoOff;
      });
    });
  }

  void _leaveRoom() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Leave Call', style: GoogleFonts.poppins(color: Colors.white)),
          content: Text('Are you sure you want to leave the call?', style: GoogleFonts.poppins(color: Colors.white70)),
          backgroundColor: Color(0xFF1A237E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Leave', style: GoogleFonts.poppins(color: Colors.red[300])),
              onPressed: () {
                Navigator.of(context).pop();
                _performLeaveRoom();
              },
            ),
          ],
        );
      },
    );
  }

  void _performLeaveRoom() {
    _socket?.sink.add(jsonEncode({
      'type': 'leave-room',
      'userId': _userId,
    }));

    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnections.forEach((_, pc) => pc.close());
    _peerConnections.clear();
    _remoteStreams.clear();
    _remoteRenderers.forEach((_, renderer) => renderer.dispose());
    _remoteRenderers.clear();
    _localRenderer.srcObject = null;

    setState(() {
      _inCall = false;
    });
  }

  Widget _buildRoomInfo() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.video_call, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text(
          'Room ID: ',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SelectableText(
          _roomIdController.text,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.copy, color: Colors.white, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _roomIdController.text)).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Room ID copied to clipboard', style: GoogleFonts.poppins()),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: EdgeInsets.all(16),
                ),
              );
            });
          },
          tooltip: 'Copy Room ID',
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (!_inCall && isDesktop) Sidebar(user: user),
              Expanded(
                child: _inCall ? _buildCallScreen(isDesktop) : _buildJoinScreen(isDesktop),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinScreen(bool isDesktop) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isCreatingRoom ? 'Create a Room' : 'Join a Room',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              if (!_isCreatingRoom)
                _buildTextField(
                  controller: _roomIdController,
                  label: 'Room ID (8 digits)',
                  maxLength: 8,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: true,
              ),
              SizedBox(height: 40),
              _buildGradientButton(
                onPressed: _isCreatingRoom ? _createRoom : () => _joinRoom(_roomIdController.text),
                icon: Icons.video_call,
                label: _isCreatingRoom ? 'Create Room' : 'Join Room',
              ),
              SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isCreatingRoom = !_isCreatingRoom;
                  });
                },
                child: Text(
                  _isCreatingRoom ? 'Join an existing room' : 'Create a new room',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: GoogleFonts.poppins(color: Colors.white),
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildCallScreen(bool isDesktop) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: _buildRoomInfo(),
              ),
              Expanded(
                child: _buildVideoGrid(isDesktop),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildControlBar(),
        ),
      ],
    );
  }


  Widget _buildVideoGrid(bool isDesktop) {
    List<Widget> videoWidgets = [
      _buildVideoWidget(_localRenderer, isLocal: true),
      ..._remoteRenderers.entries.map((entry) => _buildVideoWidget(entry.value, remoteUserId: entry.key)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;

        if (isDesktop) {
          crossAxisCount = videoWidgets.length <= 1 ? 1 : (videoWidgets.length <= 4 ? 2 : 3);
          childAspectRatio = 16 / 9;
        } else {
          crossAxisCount = videoWidgets.length <= 1 ? 1 : 2;
          childAspectRatio = 3 / 4;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          padding: EdgeInsets.all(8),
          children: videoWidgets,
        );
      },
    );
  }

  Widget _buildVideoWidget(RTCVideoRenderer renderer, {bool isLocal = false, String? remoteUserId}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                RTCVideoView(
                  renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLocal ? 'You' : 'User ${remoteUserId?.substring(0, 4) ?? ""}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (isLocal)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Row(
                      children: [
                        _buildIndicator(_isMuted, Icons.mic_off),
                        SizedBox(width: 8),
                        _buildIndicator(_isVideoOff, Icons.videocam_off),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicator(bool isActive, IconData icon) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isActive ? Colors.red : Colors.green,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            color: _isMuted ? Colors.red : Colors.white,
            onPressed: _toggleMute,
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),
          SizedBox(width: 24),
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: _leaveRoom,
            isEndCall: true,
            tooltip: 'Leave Call',
          ),
          SizedBox(width: 24),
          _buildControlButton(
            icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
            color: _isVideoOff ? Colors.red : Colors.white,
            onPressed: _toggleVideo,
            tooltip: _isVideoOff ? 'Turn Video On' : 'Turn Video Off',
          ),
          SizedBox(width: 24),
          _buildControlButton(
            icon: Icons.screen_share,
            color: Colors.white,
            onPressed: () {
              // TODO: Implement screen sharing
            },
            tooltip: 'Share Screen',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isEndCall = false,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEndCall ? Colors.red : Colors.white24,
        ),
        child: IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          color: isEndCall ? Colors.white : color,
          iconSize: 28,
          padding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnections.forEach((_, pc) => pc.close());
    _socket?.sink.close();
    _roomIdController.dispose();
    _passwordController.dispose();
    _localRenderer.dispose();
    _remoteRenderers.forEach((_, renderer) => renderer.dispose());
    super.dispose();
  }
}

