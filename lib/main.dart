import 'dart:async';
import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp()); // Fixed: Added const

// Fill in the app ID of your project, generated from Agora Console
const appId = "1c4ac0a3f8d94e619e664c5c7d9510dd";
// Fill in the temporary token generated from Agora Console
const token =
    "007eJxTYDDcfjFt+T0eIR5edqMtISdLJn5/t2Puar+0W5dm5HGsObhFgcEw2SQx2SDROM0ixdIk1czQMtXMzCTZNNk8xdLU0CAlZZ51a1pDICNDnocRKyMDBIL4LAwpqbn5DAwAbQkflw==";
// Fill in the channel name you used to generate the token
const channel = "demo";

// Application class
class MyApp extends StatefulWidget {
  const MyApp({super.key}); // Fixed: Converted 'key' to a super parameter

  @override
  State<MyApp> createState() => MyAppState(); // Fixed: Made _MyAppState public
}

class MyAppState extends State<MyApp> {
  // Fixed: Made _MyAppState public
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  ClientRoleType _userRole =
      ClientRoleType.clientRoleBroadcaster; // Default role
  int _connectedUsers = 0; // Variable to track the number of connected users

  @override
  void initState() {
    super.initState();
    // initAgora(); // Moved initialization to after role selection
  }

  Future<void> initAgora(ClientRoleType role) async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType
            .channelProfileCommunication)); // Fixed: Removed const

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        log('local user ${connection.localUid} joined');
        setState(() => _localUserJoined = true);
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        log("remote user $remoteUid joined");
        setState(() {
          _remoteUid = remoteUid;
          _connectedUsers++; // Increment the count of connected users
        });
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        log("remote user $remoteUid left channel");
        setState(() {
          _remoteUid = null;
          _connectedUsers--; // Decrement the count of connected users
        });
      },
    ));

    await _engine.enableVideo();
    if (role == ClientRoleType.clientRoleBroadcaster) {
      await _engine.startPreview();
    }

    await _engine.joinChannel(
        token: token,
        channelId: channel,
        options: ChannelMediaOptions(
            clientRoleType: role,
            audienceLatencyLevel:
                AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency),
        uid: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Connectify Video Call')),
        body: _localUserJoined ? _callInterface() : _roleSelectionInterface(),
      ),
    );
  }

  Widget _roleSelectionInterface() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => setState(() {
              _userRole = ClientRoleType.clientRoleBroadcaster;
              initAgora(_userRole);
            }),
            child: const Text('Join as Host'),
          ),
          ElevatedButton(
            onPressed: () => setState(() {
              _userRole = ClientRoleType.clientRoleAudience;
              initAgora(_userRole);
            }),
            child: const Text('Join as Audience'),
          ),
        ],
      ),
    );
  }

  Widget _callInterface() {
    return Stack(
      children: [
        Center(child: _remoteVideo()),
        if (_userRole == ClientRoleType.clientRoleBroadcaster) ...[
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: 150,
                height: 200,
                child: Center(
                  child: _localUserJoined
                      ? AgoraVideoView(
                          controller: VideoViewController(
                              rtcEngine: _engine,
                              canvas: const VideoCanvas(
                                  uid: 0))) // Fixed: Added const
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Connected Users: $_connectedUsers'),
            ),
          ),
        ]
      ],
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
          controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: const RtcConnection(
                  channelId: channel))); // Fixed: Added const
    } else {
      return const Text('Please wait for the host to join the call',
          textAlign: TextAlign.center);
    }
  }
}
