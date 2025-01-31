import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';

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
    } catch (e) {
      print('Error creating room: $e');
      _showError('Failed to create room. Please try again.');
    }
  }

  Future<void> _joinRoom(String roomId) async {
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Conference'),
        backgroundColor: Color(0xFF1A237E),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: SafeArea(
          child: _inCall ? _buildCallScreen() : _buildJoinScreen(),
        ),
      ),
    );
  }

  Widget _buildJoinScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isCreatingRoom ? 'Create a Room' : 'Join a Room',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 24),
          if (!_isCreatingRoom)
            TextField(
              controller: _roomIdController,
              decoration: InputDecoration(
                labelText: 'Room ID (8 digits)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLength: 8,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            obscureText: true,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isCreatingRoom ? _createRoom : () => _joinRoom(_roomIdController.text),
            icon: Icon(Icons.video_call),
            label: Text(_isCreatingRoom ? 'Create Room' : 'Join Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _isCreatingRoom = !_isCreatingRoom;
              });
            },
            child: Text(
              _isCreatingRoom ? 'Join an existing room' : 'Create a new room',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallScreen() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildVideoGrid(),
          ),
        ),
        _buildControlBar(),
      ],
    );
  }

  Widget _buildVideoGrid() {
    List<Widget> videoWidgets = [
      _buildVideoWidget(_localRenderer, isLocal: true),
      ..._remoteRenderers.entries.map((entry) => _buildVideoWidget(entry.value, remoteUserId: entry.key)),
    ];

    return GridView.count(
      crossAxisCount: videoWidgets.length <= 1 ? 1 : 2,
      children: videoWidgets,
    );
  }

  Widget _buildVideoWidget(RTCVideoRenderer renderer, {bool isLocal = false, String? remoteUserId}) {
    return Container(
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLocal ? 'You' : 'User ${remoteUserId?.substring(0, 4) ?? ""}',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      color: Colors.black.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            onPressed: _toggleMute,
            color: _isMuted ? Colors.red : Colors.white,
          ),
          IconButton(
            icon: Icon(Icons.call_end),
            onPressed: _leaveRoom,
            color: Colors.red,
          ),
          IconButton(
            icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam),
            onPressed: _toggleVideo,
            color: _isVideoOff ? Colors.red : Colors.white,
          ),
        ],
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

