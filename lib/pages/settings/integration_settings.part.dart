part of '../../main.dart';

class IntegrationSettingsPage extends StatefulWidget {
  IntegrationSettingsPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _IntegrationSettingsPageState createState() => new _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends State<IntegrationSettingsPage> {

  static const platform = const MethodChannel('com.keyboardcrumbs.hassclient/native');
  static final locationAccuracy = {
    100: "Highest",
    102: "Balanced (about 100 meters)",
    104: "Low (up to 10 kilometers)",
    105: "Passive (last known location)",
  };

  Duration _locationInterval;
  bool _locationTrackingEnabled = false;
  bool _wait = false;
  bool _showNotification = true;
  int _accuracy = 102;

  @override
  void initState() {
    super.initState();
    _loadSettings();

  }

  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _accuracy = prefs.getInt("location-updates-priority") ?? 102;
        _locationTrackingEnabled = (prefs.getInt("location-updates-state") ?? 0) > 0;
        _showNotification = prefs.getBool("location-updates-show-notification") ?? true;
        _locationInterval = Duration(seconds: prefs.getInt("location-updates-interval") ??
            AppSettings().defaultLocationUpdateIntervalSeconds);
      });
    });
  }

  void _incLocationInterval() {
    if (_locationInterval.inSeconds < 60) {
      setState(() {
        _locationInterval = _locationInterval + Duration(seconds: 5);
      });
    } else if (_locationInterval.inMinutes < 15) {
      setState(() {
        _locationInterval = _locationInterval + Duration(minutes: 1);
      });
    } else if (_locationInterval.inMinutes < 60) {
      setState(() {
        _locationInterval = _locationInterval + Duration(minutes: 5);
      });
    } else if (_locationInterval.inHours < 4) {
      setState(() {
        _locationInterval = _locationInterval + Duration(minutes: 10);
      });
    } else if (_locationInterval.inHours < 48) {
      setState(() {
        _locationInterval = _locationInterval + Duration(hours: 1);
      });
    }
  }

  void _decLocationInterval() {
    if (_locationInterval.inSeconds > 5) {
      if (_locationInterval.inSeconds <= 60) {
        setState(() {
          _locationInterval = _locationInterval - Duration(seconds: 5);
        });
      } else if (_locationInterval.inMinutes <= 15) {
        setState(() {
          _locationInterval = _locationInterval - Duration(minutes: 1);
        });
      } else if (_locationInterval.inMinutes <= 60) {
        setState(() {
          _locationInterval = _locationInterval - Duration(minutes: 5);
        });
      } else if (_locationInterval.inHours <= 4) {
        setState(() {
          _locationInterval = _locationInterval - Duration(minutes: 10);
        });
      } else if (_locationInterval.inHours > 4) {
        setState(() {
          _locationInterval = _locationInterval - Duration(hours: 1);
        });
      }
    }
  }

  _switchLocationTrackingState(bool state) async {
    await AppSettings().save({'location-updates-interval': _locationInterval.inSeconds, 'location-updates-priority': _accuracy, 'location-updates-show-notification': _showNotification});
    if (state) {
      try {
        await platform.invokeMethod('startLocationService');
      } catch (e) {
        _locationTrackingEnabled = false;
      }
    } else {
      await platform.invokeMethod('stopLocationService');
    }
    setState(() {
      _wait = false;
    });
  }

  String _formatInterval() {
    String result = "";
    Duration leftToShow = Duration(seconds: _locationInterval?.inSeconds ?? 0);
    if (leftToShow.inHours > 0) {
      result += "${leftToShow.inHours} h ";
      leftToShow -= Duration(hours: leftToShow.inHours);
    }
    if (leftToShow.inMinutes > 0) {
      result += "${leftToShow.inMinutes} m";
      leftToShow -= Duration(hours: leftToShow.inMinutes);
    }
    if (leftToShow.inSeconds > 0) {
      result += "${leftToShow.inSeconds} s";
      leftToShow -= Duration(hours: leftToShow.inSeconds);
    }
    return result;
  }

  Widget _getNoteWidget(String text, bool important) {
    return Text(
      text,
      style: important ? Theme.of(context).textTheme.caption.copyWith(color: Theme.of(context).errorColor) : Theme.of(context).textTheme.caption,
      softWrap: true,
    );
  }

  Widget _getNotes() {
    List<Widget> notes = [];
    if (_locationTrackingEnabled) {
      notes.add(_getNoteWidget('* Stop location tracking to change settings', false));
    }
    if ((_locationInterval?.inMinutes ?? 15) < 15) {
      notes.add(_getNoteWidget('* Notification is mandatory for location updates with interval less than every 15 minutes', false));
      if (_accuracy < 102) {
        notes.add(_getNoteWidget('* Battery consumption will be noticeable', true));
      }
    }
    if (notes.isEmpty) {
      return Container(width: 0, height: 0);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: notes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(20.0),
      children: <Widget>[
        Text("Location tracking", style: Theme.of(context).textTheme.title),
        Container(height: Sizes.rowPadding),
        Row(
          children: <Widget>[
            Text("Enable"),
            Switch(
              value: _locationTrackingEnabled,
              onChanged: _wait ? null : (value) {
                setState(() {
                  _locationTrackingEnabled = value;
                  _wait = true;
                });
                _switchLocationTrackingState(value);
              },
            ),
          ],
        ),
        Container(height: Sizes.rowPadding),
        Text("Accuracy:", style: Theme.of(context).textTheme.body2),
        Container(height: Sizes.rowPadding),
        DropdownButton<int>(
          value: _accuracy,
          iconSize: 30.0,
          isExpanded: true,
          disabledHint: Text(locationAccuracy[_accuracy]),
          items: locationAccuracy.keys.map((value) {
            return new DropdownMenuItem<int>(
              value: value,
              child: Text('${locationAccuracy[value]}'),
            );
          }).toList(),
          onChanged: _locationTrackingEnabled ? null : (val) {
            setState(() {
              _accuracy = val;
            });
          },
        ),
        Container(height: Sizes.rowPadding),
        Text("Update interval"),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            //Expanded(child: Container(),),
            FlatButton(
              padding: EdgeInsets.all(0.0),
              child: Text("-", style: Theme.of(context).textTheme.headline4),
              onPressed: _locationTrackingEnabled ? null : () => _decLocationInterval(),
            ),
            Expanded(
              child: Text(_formatInterval(),
                  textAlign: TextAlign.center,
                  style: _locationTrackingEnabled ? Theme.of(context).textTheme.title.copyWith(color: HAClientTheme().getDisabledStateColor(context)) : Theme.of(context).textTheme.title),
            ),
            FlatButton(
              padding: EdgeInsets.all(0.0),
              child: Text("+", style: Theme.of(context).textTheme.headline4),
              onPressed: _locationTrackingEnabled ? null : () => _incLocationInterval(),
            ),
          ],
        ),
        Container(height: Sizes.rowPadding),
        Row(
          children: <Widget>[
            Text("Show notification"),
            Switch(
              value: _showNotification,
              onChanged: (_locationTrackingEnabled || (_locationInterval?.inMinutes ?? 0) < 15) ? null : (value) {
                setState(() {
                  _showNotification = value;
                });
              },
            ),
          ],
        ),
        Container(height: Sizes.rowPadding),
        _getNotes()
      ]
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
