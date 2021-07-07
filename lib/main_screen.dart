import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_recorder_player/local_app_directory.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  String _tempDirectory = "";
  String _audioFileName = "";
  String _audioFilePath = "";

  bool _isRecorded = false;

  double _currentVolume = 0.0;
  double _currentPercent = 0.0;
  Duration _currentDuration = new Duration();

  final Duration _recordMaxTime = const Duration(minutes: 5);

  Duration _recordedDuration = new Duration();

  IconData _recorderIconData() {
    if (_recorder.isStopped) {
      return Icons.fiber_manual_record;
    } else {
      //This case is _recorder.isRecording
      return Icons.stop;
    }
  }

  IconData _playerIconData() {
    if (_player.isPlaying) {
      return Icons.pause;
    } else {
      return Icons.play_arrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _openTheRecorder();
    _openThePlayer();
  }

  Future<void> _openTheRecorder() async {
    _checkMicroPhonePermissionAndRequest();

    await getTemporaryDirectory()
        .then((temDir) => _tempDirectory = temDir.path);

    _audioFileName = Uuid().v1().toString() + ".mp4";
    _audioFilePath = _tempDirectory + '/' + _audioFileName;

    print("_openTheRecorder $_audioFilePath");

    await _recorder.openAudioSession();
    await _recorder.setSubscriptionDuration(const Duration(seconds: 1));
  }

  Future<void> _checkMicroPhonePermissionAndRequest() async {
    var microPhonePermission = await Permission.microphone.status;
    if (microPhonePermission != PermissionStatus.granted) {
      await Permission.microphone.request();
    }
  }

  Future<void> _openThePlayer() async {
    await _player.openAudioSession();
    await _player.setSubscriptionDuration(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter sound"),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _recoderWidget(context)),
            // Expanded(
            //     child: Container(
            //   child: _playerWidget(),
            //   color: Colors.red,
            // )),
          ],
        ),
      ),
    );
  }

  Widget _recoderWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //volum bar
            Container(
              width: 10,
              height: 30,
              child: RotatedBox(
                quarterTurns: -1,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey,
                  value: _currentVolume,
                  // value: _convertAvgPowerToVolumeValue(_current.metering.averagePower),
                ),
              ),
            ),
            Stack(
              children: <Widget>[
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(
                      backgroundColor: Colors.grey,
                      value: _currentPercent,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: InkWell(
                      child: Icon(
                        !_isRecorded ? _recorderIconData() : _playerIconData(),
                        size: 60,
                        color: Colors.red,
                      ),
                      onTap: () async {
                        if (!_isRecorded) {
                          recordAction();
                        } else {
                          playAction();
                        }
                      },
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
        Text(
          _printDuration(_currentDuration),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: Colors.black,
          ),
        ),
        TextButton(
          child: const Text("Reset"),
          onPressed: () async {
            await _resetRecorder();
          },
        )
      ],
    );
  }

  void recordAction() {
    if (_recorder.isStopped) {
      _startRecord();
    } else {
      _stopRecord();
    }
  }

  Future<void> _startRecord() async {
    await _recorder.startRecorder(
      toFile: _audioFilePath,
      codec: Codec.defaultCodec,
    );

    _recorder.onProgress!.listen((event) {
      setState(() {
        print(
            "recorder onProgress duration: ${event.duration} and ${event.decibels}");
        _currentDuration = event.duration;
        _currentVolume = event.decibels! / 120;
      });
    });

    _tikTokForRecoder(_recordMaxTime);

    setState(() {});
  }

  Future<void> _stopRecord() async {
    await _recorder.stopRecorder();
    print("_stopRecord $_audioFilePath");
    setState(() {
      _isRecorded = true;
      _recordedDuration = _currentDuration;
      _currentDuration = new Duration();
      _currentVolume = 0.0;
      _currentPercent = 0.0;
    });
  }

  void playAction() {
    switch (_player.playerState) {
      case PlayerState.isStopped:
        _startPlayer();
        break;
      case PlayerState.isPlaying:
        _pausePlayer();
        break;
      case PlayerState.isPaused:
        _resumePlayer();
        break;
      default:
    }
  }

  Future<void> _startPlayer() async {
    await _player.startPlayer(
      fromURI: _audioFilePath,
      codec: Codec.defaultCodec,
      whenFinished: () async {
        await _stopPlayer();
      },
    );

    if (_player.onProgress != null) {
      _player.onProgress!.listen((event) {
        setState(() {
          _currentDuration = event.position;
        });
      });
    }

    // await _tikTokForPlayer(_recordedDuration);

    setState(() {});
  }

  Future<void> _pausePlayer() async {
    await _player.pausePlayer();

    setState(() {});
  }

  Future<void> _resumePlayer() async {
    await _player.resumePlayer();
  }

  Future<void> _stopPlayer() async {
    await _player.stopPlayer();

    setState(() {
      _currentDuration = new Duration();
      _currentPercent = 0;
      _currentVolume = 0;
    });
  }

  Future<void> _resetRecorder() async {
    await _recorder.closeAudioSession();
    await _player.closeAudioSession();

    File recordFile = File(_audioFilePath);
    await recordFile.delete();

    await _openTheRecorder();
    await _openThePlayer();

    setState(() {
      _isRecorded = false;
    });
  }

  Future<void> _tikTokForRecoder(Duration recordDuration) async {
    const tick = Duration(seconds: 1);
    Timer.periodic(
      tick,
      (Timer t) async {
        const double max = 1.0;
        double count = 1 / recordDuration.inSeconds;
        bool timeToStop = false;

        (_currentPercent == max ||
                _recorder.isStopped ||
                _currentDuration.inMinutes >= 5)
            ? timeToStop = true
            : timeToStop = false;

        //flutterRecorder.isStopped 이면 progress bar 를 멈춘다.
        if (timeToStop) {
          t.cancel();
          _stopRecord();
        }

        if (_currentPercent < max && _recorder.isRecording) {
          setState(() {
            _currentPercent += count;
          });
        } else if (_currentPercent > max) {
          setState(() {
            _currentPercent = 1.0;
          });
        }
      },
    );
  }

  Future<void> _tikTokForPlayer(Duration recordedDuration) async {
    const tick = Duration(seconds: 1);
    Timer.periodic(
      tick,
      (Timer t) async {
        double max = 1.0;
        double count = 1 / recordedDuration.inSeconds;

        //flutterRecorder.isStopped 이면 progress bar 를 멈춘다.
        if (_currentPercent == max || _player.isStopped) {
          t.cancel();
        }

        if (_currentPercent < max && _player.isPlaying) {
          setState(() {
            _currentPercent += count;
          });
        } else if (_currentPercent > max) {
          setState(() {
            _currentPercent = 1.0;
          });
        }
      },
    );
  }

  Widget _playerWidget() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13.0),
        color: Colors.white,
        boxShadow: [
          BoxShadow(blurRadius: 6, color: Color.fromRGBO(0, 0, 0, 0.16))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            InkWell(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 6,
                      offset: Offset(0, 3),
                      color: Color.fromRGBO(0, 0, 0, 0.16),
                    )
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Color.fromRGBO(165, 222, 97, 1),
                  size: 50,
                ),
              ),
              onTap: () async {
                print("play button tapped");
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text(
                "00:00",
                style: TextStyle(fontSize: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
