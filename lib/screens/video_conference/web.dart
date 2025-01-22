import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

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
  html.MediaStream? _localStream;
  Map<String, html.MediaStream> _remoteStreams = {};
  Map<String, js.JsObject> _peerConnections = {};
  
  html.VideoElement? _localVideo;
  Map<String, html.VideoElement> _remoteVideos = {};

  bool _isCreatingRoom = true;

  @override
  void initState() {
    super.initState();
    _userId = DateTime.now().millisecondsSinceEpoch.toString();
    _initializeVideoElements();
    _connectToSignalingServer();
  }

  void _initializeVideoElements() {
    _localVideo = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..id = 'localVideo';
    _registerVideoElement(_localVideo!);
  }

  void _registerVideoElement(html.VideoElement videoElement) {
    final viewType = 'videoElement_${videoElement.id}';
    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) => videoElement);
  }

  void _connectToSignalingServer() {
    _socket = WebSocketChannel.connect(Uri.parse('ws://localhost:8080'));
    _socket!.stream.listen((message) {
      final data = jsonDecode(message);
      _handleSignalingMessage(data);
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
        _startConnectionCheck();
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
      case 'room-full':
        _showError('Room is full');
        break;
      case 'invalid-password':
        _showError('Invalid password');
        break;
      case 'room-not-found':
        _showError('Room not found');
        break;
    }
  }

  String _generateRoomId() {
    const chars = '0123456789';
    return List.generate(8, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<void> _createRoom() async {
    final roomId = _generateRoomId();
    final password = _passwordController.text;

    if (password.isEmpty) {
      _showError('Please enter a password');
      return;
    }

    try {
      _localStream = await _getUserMedia();

      if (_localStream != null) {
        _localVideo?.srcObject = _localStream;
        print('Local stream created with ${_localStream!.getVideoTracks().length} video tracks');
        
        _socket?.sink.add(jsonEncode({
          'type': 'create-room',
          'roomId': roomId,
          'password': password,
          'userId': _userId,
        }));

        setState(() {
          _inCall = true;
        });
        _startConnectionCheck();
      } else {
        throw Exception('Failed to create local stream');
      }
    } catch (e) {
      print('Error accessing media devices: $e');
      _showError('Failed to access camera/microphone. Please check your settings and try again.');
      _showTroubleshootingDialog();
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
      _localStream = await _getUserMedia();

      if (_localStream != null) {
        _localVideo?.srcObject = _localStream;
        print('Local stream created with ${_localStream!.getVideoTracks().length} video tracks');
        
        _socket?.sink.add(jsonEncode({
          'type': 'join-room',
          'roomId': roomId,
          'password': password,
          'userId': _userId,
        }));

        setState(() {
          _inCall = true;
        });
        _startConnectionCheck();
      } else {
        throw Exception('Failed to create local stream');
      }
    } catch (e) {
      print('Error accessing media devices: $e');
      _showError('Failed to access camera/microphone. Please check your settings and try again.');
      _showTroubleshootingDialog();
    }
  }

  Future<html.MediaStream?> _getUserMedia() async {
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {'width': 640, 'height': 480},
        'audio': true
      });
      print('getUserMedia successful. Video tracks: ${stream!.getVideoTracks().length}, Audio tracks: ${stream.getAudioTracks().length}');
      return stream;
    } catch (e) {
      print('Error in getUserMedia: $e');
      if (e.toString().contains('NotReadableError')) {
        throw Exception('NotReadableError: Could not start video source');
      } else {
        throw e;
      }
    }
  }

  void _showTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Troubleshooting Steps'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('1. Ensure no other applications are using your camera.'),
                Text('2. Try closing and reopening your browser.'),
                Text('3. Check if your camera is properly connected and enabled.'),
                Text('4. Ensure you\'ve granted camera permissions to this website.'),
                Text('5. Restart your computer if the issue persists.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleUserJoined(String remoteUserId) {
    print('Handling user joined: $remoteUserId');
    _createPeerConnection(remoteUserId).then((pc) {
      _peerConnections[remoteUserId] = pc;
      _createAndSendOffer(remoteUserId, pc);
    });
    _checkVideoTracks();
  }

  Future<js.JsObject> _createPeerConnection(String remoteUserId) async {
    print('Creating peer connection for $remoteUserId');
    final rtcPeerConnection = js.context['RTCPeerConnection'];
    if (rtcPeerConnection == null) {
      throw Exception('RTCPeerConnection is not available');
    }

    final pc = js.JsObject(rtcPeerConnection, [
      js.JsObject.jsify({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ]
      })
    ]);

    pc['onicecandidate'] = js.allowInterop((event) {
      if (event['candidate'] != null) {
        print('Sending ICE candidate to $remoteUserId');
        _socket?.sink.add(jsonEncode({
          'type': 'ice-candidate',
          'userId': _userId,
          'targetUserId': remoteUserId,
          'candidate': event['candidate'],
        }));
      }
    });

    pc['ontrack'] = js.allowInterop((event) {
      print('Received track from $remoteUserId');
      if (event['streams'].length > 0) {
        _remoteStreams[remoteUserId] = event['streams'][0];
        _displayRemoteStream(remoteUserId);
      }
    });

    pc['oniceconnectionstatechange'] = js.allowInterop(() {
      print('ICE connection state for $remoteUserId: ${pc['iceConnectionState']}');
    });

    if (_localStream != null) {
      print('Adding local tracks to peer connection for $remoteUserId');
      _localStream!.getTracks().forEach((track) {
        try {
          print('Adding track: ${track.kind}');
          final jsTrack = js.JsObject.fromBrowserObject(track);
          final jsStream = js.JsObject.fromBrowserObject(_localStream!);
          pc.callMethod('addTrack', [jsTrack, jsStream]);
        } catch (e) {
          print('Error adding track: $e');
        }
      });
    } else {
      print('Local stream is null, cannot add tracks to peer connection for $remoteUserId');
    }

    print('Peer connection created successfully for $remoteUserId');
    print('Local stream tracks: ${_localStream?.getTracks().length}');
    print('Peer connection state: ${pc['connectionState']}');
    _logPeerConnectionState(remoteUserId, pc);
    return pc;
  }

  void _handleOffer(String remoteUserId, String sdp) {
    print('Handling offer from: $remoteUserId');
    _createPeerConnection(remoteUserId).then((pc) {
      _peerConnections[remoteUserId] = pc;
      print('Setting remote description for offer');
      pc.callMethod('setRemoteDescription', [
        js.JsObject.jsify({'type': 'offer', 'sdp': sdp})
      ]).then((_) {
        print('Remote description set for offer');
        print('Creating answer');
        return pc.callMethod('createAnswer', []);
      }).then((answer) {
        print('Created answer for $remoteUserId');
        print('Setting local description for answer');
        return pc.callMethod('setLocalDescription', [answer]);
      }).then((_) {
        print('Local description set for answer');
        _socket?.sink.add(jsonEncode({
          'type': 'answer',
          'userId': _userId,
          'targetUserId': remoteUserId,
          'sdp': pc.callMethod('localDescription')['sdp'],
        }));
        print('Answer sent to $remoteUserId');
      });
    });
  }

  void _handleAnswer(String remoteUserId, String sdp) {
    print('Handling answer from: $remoteUserId');
    final pc = _peerConnections[remoteUserId];
    if (pc != null) {
      print('Setting remote description for answer');
      pc.callMethod('setRemoteDescription', [
        js.JsObject.jsify({'type': 'answer', 'sdp': sdp})
      ]).then((_) {
        print('Remote description set for answer from $remoteUserId');
      });
    } else {
      print('No peer connection found for $remoteUserId');
    }
  }

  void _handleIceCandidate(String remoteUserId, Map<String, dynamic> candidate) {
    print('Handling ICE candidate from: $remoteUserId');
    final pc = _peerConnections[remoteUserId];
    if (pc != null) {
      print('Adding ICE candidate');
      pc.callMethod('addIceCandidate', [
        js.JsObject.jsify(candidate)
      ]).then((_) {
        print('ICE candidate added successfully for $remoteUserId');
      }).catchError((error) {
        print('Error adding ICE candidate: $error');
      });
    } else {
      print('No peer connection found for $remoteUserId');
    }
  }

  void _handleUserLeft(String remoteUserId) {
    final pc = _peerConnections[remoteUserId];
    if (pc != null) {
      pc.callMethod('close');
      _peerConnections.remove(remoteUserId);
    }
    _remoteStreams.remove(remoteUserId);
    _remoteVideos[remoteUserId]?.remove();
    _remoteVideos.remove(remoteUserId);
    setState(() {});
  }

  void _displayRemoteStream(String remoteUserId) {
    print('Displaying remote stream for user: $remoteUserId');
    if (!_remoteVideos.containsKey(remoteUserId)) {
      final videoElement = html.VideoElement()
        ..autoplay = true
        ..id = 'remote_$remoteUserId';
      
      videoElement.srcObject = _remoteStreams[remoteUserId];
      _remoteVideos[remoteUserId] = videoElement;
      _registerVideoElement(videoElement);
      print('Remote video element created for user: $remoteUserId');
      setState(() {});
    }
    _checkVideoTracks();
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
    _peerConnections.forEach((_, pc) => pc.callMethod('close'));
    _peerConnections.clear();
    _remoteStreams.clear();
    _remoteVideos.forEach((_, video) => video.remove());
    _remoteVideos.clear();
    _localVideo?.remove();

    setState(() {
      _inCall = false;
    });
  }

  void _createAndSendOffer(String remoteUserId, js.JsObject pc) {
    print('Creating offer for $remoteUserId');
    final createOfferPromise = pc.callMethod('createOffer');
    if (createOfferPromise == null) {
      print('Error: createOffer returned null');
      return;
    }
    
    js.JsObject.fromBrowserObject(createOfferPromise).callMethod('then', [
      js.allowInterop((offer) {
        print('Offer created successfully for $remoteUserId');
        print('Offer SDP: ${offer['sdp']}');
        pc.callMethod('setLocalDescription', [offer]);
        _socket?.sink.add(jsonEncode({
          'type': 'offer',
          'userId': _userId,
          'targetUserId': remoteUserId,
          'sdp': offer['sdp'],
        }));
        _logPeerConnectionState(remoteUserId, pc);
      })
    ]);
  }

  void _checkVideoTracks() {
    print('Checking video tracks:');
    print('Local stream tracks: ${_localStream?.getVideoTracks().length}');
    _remoteStreams.forEach((userId, stream) {
      print('Remote stream tracks for user $userId: ${stream.getVideoTracks().length}');
    });
  }

  void _startConnectionCheck() {
    Future.doWhile(() async {
      if (!_inCall) return false;
      
      print('Connection check:');
      _peerConnections.forEach((userId, pc) {
        print('Connection to $userId - ICE State: ${pc['iceConnectionState']}, Connection State: ${pc['connectionState']}');
      });
      
      await Future.delayed(Duration(seconds: 5));
      return _inCall;
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
      if (_localVideo != null) _buildVideoWidget(_localVideo!, isLocal: true),
      ..._remoteVideos.entries.map((entry) => _buildVideoWidget(entry.value, remoteUserId: entry.key)),
    ];

    print('Building video grid with ${videoWidgets.length} videos');

    return GridView.count(
      crossAxisCount: videoWidgets.length <= 1 ? 1 : 2,
      children: videoWidgets,
    );
  }

  Widget _buildVideoWidget(html.VideoElement video, {bool isLocal = false, String? remoteUserId}) {
    final viewType = 'videoElement_${video.id}';
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
            HtmlElementView(
              viewType: viewType,
              key: ValueKey(video.id),
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
    _peerConnections.forEach((_, pc) => pc.callMethod('close'));
    _socket?.sink.close();
    _roomIdController.dispose();
    _passwordController.dispose();
    _localVideo?.remove();
    _remoteVideos.forEach((_, video) => video.remove());
    super.dispose();
  }

  void _logPeerConnectionState(String remoteUserId, js.JsObject pc) {
    print('Peer Connection State for $remoteUserId:');
    print('- Connection State: ${pc['connectionState']}');
    print('- ICE Connection State: ${pc['iceConnectionState']}');
    print('- Signaling State: ${pc['signalingState']}');
    
    final senders = pc.callMethod('getSenders');
    print('- Number of senders: ${senders.length}');
    for (var i = 0; i < senders.length; i++) {
      final sender = senders[i];
      final track = sender['track'];
      if (track != null) {
        print('  - Sender $i: ${track['kind']} track (${track['readyState']})');
      } else {
        print('  - Sender $i: No track');
      }
    }
  }
}

