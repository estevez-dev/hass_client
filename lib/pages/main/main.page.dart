part of '../../main.dart';

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => new _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver, TickerProviderStateMixin {

  StreamSubscription _stateSubscription;
  StreamSubscription _lovelaceSubscription;
  StreamSubscription _settingsSubscription;
  StreamSubscription _serviceCallSubscription;
  StreamSubscription _showEntityPageSubscription;
  StreamSubscription _showErrorSubscription;
  StreamSubscription _startAuthSubscription;
  StreamSubscription _showPopupDialogSubscription;
  StreamSubscription _showPopupMessageSubscription;
  StreamSubscription _reloadUISubscription;
  StreamSubscription _showPageSubscription;
  int _previousViewCount;
  bool _showLoginButton = false;
  bool _preventAppRefresh = false;
  Entity _entityToShow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _firebaseMessaging.configure(
        onLaunch: (data) {
          Logger.d("Notification [onLaunch]: $data");
          return Future.value();
        },
        onMessage: (data) {
          Logger.d("Notification [onMessage]: $data");
          return _showNotification(title: data["notification"]["title"], text: data["notification"]["body"]);
        },
        onResume: (data) {
          Logger.d("Notification [onResume]: $data");
          return Future.value();
        }
    );

    _firebaseMessaging.requestNotificationPermissions(const IosNotificationSettings(sound: true, badge: true, alert: true));

    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid =
    new AndroidInitializationSettings('mini_icon');
    var initializationSettingsIOS = new IOSInitializationSettings(
        onDidReceiveLocalNotification: null);
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    _settingsSubscription = eventBus.on<SettingsChangedEvent>().listen((event) {
      Logger.d("Settings change event: reconnect=${event.reconnect}");
      if (event.reconnect) {
        _preventAppRefresh = false;
        _fullLoad();
      }
    });

    _fullLoad();
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      Logger.d('Notification clicked: ' + payload);
    }
  }

  Future _showNotification({String title, String text}) async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'ha_notify', 'Home Assistant notifications', 'Notifications from Home Assistant notify service',
        importance: Importance.Max, priority: Priority.High);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0,
        title ?? appName,
        text,
        platformChannelSpecifics
    );
  }

  void _fullLoad() {
    _showInfoBottomBar(progress: true,);
    _subscribe().then((_) {
      ConnectionManager().init(loadSettings: true, forceReconnect: true).then((__){
        SharedPreferences.getInstance().then((prefs) {
          HomeAssistant().lovelaceDashboardUrl = prefs.getString('lovelace_dashboard_url') ?? HomeAssistant.DEFAULT_DASHBOARD;
          _fetchData(useCache: true);
          LocationManager();
          StartupUserMessagesManager().checkMessagesToShow();
        });
      }, onError: (e) {
        _setErrorState(e);
      });
    });
  }

  void _quickLoad({bool uiOnly: false}) {
    _hideBottomBar();
    _showInfoBottomBar(progress: true,);
    ConnectionManager().init(loadSettings: false, forceReconnect: false).then((_){
      _fetchData(useCache: false, uiOnly: uiOnly);
    }, onError: (e) {
      _setErrorState(e);
    });
  }

  _fetchData({useCache: false, uiOnly: false}) async {
    if (useCache && !uiOnly) {
      HomeAssistant().fetchDataFromCache().then((_) {
        setState((){});  
      });
    }
    await HomeAssistant().fetchData(uiOnly).then((_) {
      _hideBottomBar();
      if (_entityToShow != null) {
        _entityToShow = HomeAssistant().entities.get(_entityToShow.entityId);
      }
    }).catchError((e) {
      if (e is HAError) {
        _setErrorState(e);
      } else {
        _setErrorState(HAError(e.toString()));
      }
    });
    eventBus.fire(RefreshDataFinishedEvent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logger.d("$state");
    if (state == AppLifecycleState.resumed && ConnectionManager().settingsLoaded && !_preventAppRefresh) {
      _quickLoad();
    } else if (state == AppLifecycleState.paused && ConnectionManager().settingsLoaded && !_preventAppRefresh) {
      HomeAssistant().saveCache();
    }
  }

  Future _subscribe() {
    Completer completer = Completer();

    if (_stateSubscription == null) {
      _stateSubscription = eventBus.on<StateChangedEvent>().listen((event) {
        if (event.needToRebuildUI) {
          Logger.d("Need to rebuild UI");
          _quickLoad();
        } else {
          setState(() {});
        }
      });
    }
    if (_lovelaceSubscription == null) {
      _lovelaceSubscription = eventBus.on<LovelaceChangedEvent>().listen((event) {
        _quickLoad();
      });
    }
    if (_reloadUISubscription == null) {
      _reloadUISubscription = eventBus.on<ReloadUIEvent>().listen((event){
        _quickLoad(uiOnly: true);
      });
    }
    if (_showPopupDialogSubscription == null) {
      _showPopupDialogSubscription = eventBus.on<ShowPopupDialogEvent>().listen((event){
        _showPopupDialog(
            title: event.title,
            body: event.body,
            onPositive: event.onPositive,
            onNegative: event.onNegative,
            positiveText: event.positiveText,
            negativeText: event.negativeText
        );
      });
    }
    if (_showPopupMessageSubscription == null) {
      _showPopupMessageSubscription = eventBus.on<ShowPopupMessageEvent>().listen((event){
        _showPopupDialog(
            title: event.title,
            body: event.body,
            onPositive: event.onButtonClick,
            positiveText: event.buttonText,
            negativeText: null
        );
      });
    }
    if (_serviceCallSubscription == null) {
      _serviceCallSubscription =
          eventBus.on<NotifyServiceCallEvent>().listen((event) {
            _notifyServiceCalled(event.domain, event.service, event.entityId);
          });
    }

    if (_showEntityPageSubscription == null) {
      _showEntityPageSubscription =
          eventBus.on<ShowEntityPageEvent>().listen((event) {
            _showEntityPage(event.entity?.entityId);
          });
    }

    if (_showPageSubscription == null) {
      _showPageSubscription =
          eventBus.on<ShowPageEvent>().listen((event) {
            _showPage(event.path, event.goBackFirst);
          });
    }

    if (_showErrorSubscription == null) {
      _showErrorSubscription = eventBus.on<ShowErrorEvent>().listen((event){
        _showErrorBottomBar(event.error);
      });
    }

    if (_startAuthSubscription == null) {
      _startAuthSubscription = eventBus.on<StartAuthEvent>().listen((event){
        setState(() {
          _showLoginButton = event.showButton;
        });
        if (event.showButton) {
          _showOAuth();
        } else {
          _preventAppRefresh = false;
          Navigator.of(context).pop();
        }
      });
    }

    _firebaseMessaging.getToken().then((String token) {
      HomeAssistant().fcmToken = token;
      completer.complete();
    });
    return completer.future;
  }

  void _showOAuth() {
    _preventAppRefresh = true;
    Navigator.of(context).pushNamed("/auth", arguments: {"url": ConnectionManager().oauthUrl});
  }

  _setErrorState(HAError e) {
    if (e == null) {
      _showErrorBottomBar(
          HAError("Unknown error")
      );
    } else {
      _showErrorBottomBar(e);
    }
  }

  void _showPopupDialog({String title, String body, var onPositive, var onNegative, String positiveText, String negativeText}) {
    List<Widget> buttons = [];
    buttons.add(FlatButton(
      child: new Text("$positiveText"),
      onPressed: () {
        Navigator.of(context).pop();
        if (onPositive != null) {
          onPositive();
        }
      },
    ));
    if (negativeText != null) {
      buttons.add(FlatButton(
        child: new Text("$negativeText"),
        onPressed: () {
          Navigator.of(context).pop();
          if (onNegative != null) {
            onNegative();
          }
        },
      ));
    }
    // flutter defined function
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("$title"),
          content: new Text("$body"),
          actions: buttons,
        );
      },
    );
  }

  void _notifyServiceCalled(String domain, String service, entityId) {
    _showInfoBottomBar(
        message: "Calling $domain.$service",
        duration: Duration(seconds: 4)
    );
  }

  void _showEntityPage(String entityId) {
    setState(() {
      _entityToShow = HomeAssistant().entities?.get(entityId);
      if (_entityToShow != null) {
        _mainScrollController?.jumpTo(0);
      }
    });
    /*if (_entityToShow!= null && MediaQuery.of(context).size.width < Sizes.tabletMinWidth) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EntityViewPage(entityId: entityId),
          )
      );
    }*/
  }

  void _showPage(String path, bool goBackFirst) {
    if (goBackFirst) {
      Navigator.pop(context);
    }
    Navigator.pushNamed(
        context,
        path
    );
  }

  List<Tab> buildUIViewTabs() {
    List<Tab> result = [];

    if (HomeAssistant().ui.views.isNotEmpty) {
      HomeAssistant().ui.views.forEach((HAView view) {
        result.add(view.buildTab());
      });
    }

    return result;
  }

  Drawer _buildAppDrawer() {
    List<Widget> menuItems = [];
    menuItems.add(
        UserAccountsDrawerHeader(
          accountName: Text(HomeAssistant().userName),
          accountEmail: Text(HomeAssistant().locationName ?? ""),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Theme.of(context).backgroundColor,
            child: Text(
              HomeAssistant().userAvatarText,
              style: Theme.of(context).textTheme.display1
            ),
          ),
        )
    );
    if (HomeAssistant().panels.isNotEmpty) {
      HomeAssistant().panels.forEach((Panel panel) {
        if (!panel.isHidden) {
          menuItems.add(
              panel.getMenuItemWidget(context)
          );
        }
      });
    }
    menuItems.addAll([
      Divider(),
      ListTile(
        leading: Icon(MaterialDesignIcons.getIconDataFromIconName("mdi:server-network")),
        title: Text("Connection settings"),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/connection-settings');
        },
      ),
      ListTile(
        leading: Icon(MaterialDesignIcons.getIconDataFromIconName("mdi:cellphone-settings-variant")),
        title: Text("Integration settings"),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/integration-settings');
        },
      )
    ]);
    menuItems.addAll([
      Divider(),
      new ListTile(
        leading: Icon(Icons.insert_drive_file),
        title: Text("Log"),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/log-view');
        },
      ),
      new ListTile(
        leading: Icon(MaterialDesignIcons.getIconDataFromIconName("mdi:github-circle")),
        title: Text("Report an issue"),
        onTap: () {
          Navigator.of(context).pop();
          Launcher.launchURL("https://github.com/estevez-dev/ha_client/issues/new");
        },
      ),
      Divider(),
      new ListTile(
        leading: Icon(MaterialDesignIcons.getIconDataFromIconName("mdi:food")),
        title: Text("Support app development"),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/putchase');
        },
      ),
      Divider(),
      new ListTile(
        leading: Icon(Icons.help),
        title: Text("Help"),
        onTap: () {
          Navigator.of(context).pop();
          Launcher.launchURL("http://ha-client.app/docs");
        },
      ),
      new ListTile(
        leading: Icon(MaterialDesignIcons.getIconDataFromIconName("mdi:discord")),
        title: Text("Contacts/Discussion"),
        onTap: () {
          Navigator.of(context).pop();
          Launcher.launchURL("https://discord.gg/nd6FZQ");
        },
      ),
      new ListTile(
        title: Text("What's new?"),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/whats-new');
        }
      ),
      new AboutListTile(
          aboutBoxChildren: <Widget>[
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Launcher.launchURL("http://ha-client.app/");
              },
              child: Text(
                "ha-client.app",
                style: Theme.of(context).textTheme.body1.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Container(
              height: 10.0,
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Launcher.launchURLInCustomTab(context: context, url: "http://ha-client.app/terms_and_conditions");
              },
              child: Text(
                "Terms and Conditions",
                style: Theme.of(context).textTheme.body1.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Container(
              height: 10.0,
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Launcher.launchURLInCustomTab(context: context, url: "http://ha-client.app/privacy_policy");
              },
              child: Text(
                "Privacy Policy",
                style: Theme.of(context).textTheme.body1.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            )
          ],
          applicationName: appName,
          applicationVersion: appVersion
      )
    ]);
    return new Drawer(
      child: ListView(
        children: menuItems,
      ),
    );
  }

  void _hideBottomBar() {
    //_scaffoldKey?.currentState?.hideCurrentSnackBar();
    setState(() {
      _showBottomBar = false;
    });
  }

  Widget _bottomBarAction;
  bool _showBottomBar = false;
  String _bottomBarText;
  bool _bottomBarProgress;
  bool _bottomBarErrorColor;
  Timer _bottomBarTimer;

  void _showInfoBottomBar({String message, bool progress: false, Duration duration}) {
    _bottomBarTimer?.cancel();
    _bottomBarAction = Container(height: 0.0, width: 0.0,);
    _bottomBarErrorColor = false;
    setState(() {
      _bottomBarText = message;
      _bottomBarProgress = progress;
      _showBottomBar = true;
    });
    if (duration != null) {
      _bottomBarTimer = Timer(duration, () {
        _hideBottomBar();
      });
    }
  }

  void _showErrorBottomBar(HAError error) {
    TextStyle textStyle = Theme.of(context).textTheme.button.copyWith(
      decoration: TextDecoration.underline
    );
    _bottomBarErrorColor = true;
    List<Widget> actions = [];
    error.actions.forEach((HAErrorAction action) {
      switch (action.type) {
        case HAErrorActionType.FULL_RELOAD: {
          actions.add(FlatButton(
            child: Text("${action.title}", style: textStyle),
            onPressed: () {
              _fullLoad();
            },
          ));
          break;
        }

        case HAErrorActionType.QUICK_RELOAD: {
          actions.add(FlatButton(
            child: Text("${action.title}", style: textStyle),
            onPressed: () {
              _quickLoad();
            },
          ));
          break;
        }

        case HAErrorActionType.RELOGIN: {
          actions.add(FlatButton(
            child: Text("${action.title}", style: textStyle),
            onPressed: () {
              ConnectionManager().logout().then((_) => _fullLoad());
            },
          ));
          break;
        }

        case HAErrorActionType.URL: {
          actions.add(FlatButton(
            child: Text("${action.title}", style: textStyle),
            onPressed: () {
              Launcher.launchURLInCustomTab(context: context, url: "${action.url}");
            },
          ));
          break;
        }

        case HAErrorActionType.OPEN_CONNECTION_SETTINGS: {
          actions.add(FlatButton(
            child: Text("${action.title}", style: textStyle),
            onPressed: () {
              Navigator.pushNamed(context, '/connection-settings');
            },
          ));
          break;
        }
      }
    });
    if (actions.isNotEmpty) {
      _bottomBarAction = Row(
        mainAxisSize: MainAxisSize.min,
        children: actions,
        mainAxisAlignment: MainAxisAlignment.end,
      );
    } else {
      _bottomBarAction = Container(height: 0.0, width: 0.0,);
    }
    setState(() {
      _bottomBarProgress = false;
      _bottomBarText = "${error.message}";
      _showBottomBar = true;
    });
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final ScrollController _mainScrollController = ScrollController();

  Widget _buildScaffoldBody(bool empty) {
    List<PopupMenuItem<String>> serviceMenuItems = [];
    List<PopupMenuItem<String>> mediaMenuItems = [];

    int currentViewCount = HomeAssistant().ui?.views?.length ?? 0;
    if (_previousViewCount != currentViewCount) {
      Logger.d("Views count changed ($_previousViewCount->$currentViewCount). Creating new tabs controller.");
      _viewsTabController = TabController(vsync: this, length: currentViewCount);
      _previousViewCount = currentViewCount;
    }

    serviceMenuItems.add(PopupMenuItem<String>(
      child: new Text("Reload"),
      value: "reload",
    ));
    if (ConnectionManager().isAuthenticated) {
      _showLoginButton = false;
      serviceMenuItems.add(
          PopupMenuItem<String>(
            child: new Text("Logout"),
            value: "logout",
          ));
    }
    Widget mediaMenuIcon;
    int playersCount = 0;
    if (!empty && !HomeAssistant().entities.isEmpty) {
      List<Entity> activePlayers = HomeAssistant().entities.getByDomains(includeDomains: ["media_player"], stateFiler: [EntityState.paused, EntityState.playing, EntityState.idle]);
      playersCount = activePlayers.length;
      mediaMenuItems.addAll(
          activePlayers.map((entity) => PopupMenuItem<String>(
            child: Text(
                "${entity.displayName}",
              style: Theme.of(context).textTheme.body1.copyWith(
                color: HAClientTheme().getColorByEntityState(entity.state, context)
              )
            ),
            value: "${entity.entityId}",
          )).toList()
      );
    }
    mediaMenuItems.addAll([
      PopupMenuItem<String>(
        child: new Text("Play media..."),
        value: "play_media",
      )
    ]);
    if (playersCount > 0) {
      mediaMenuIcon = Stack(
        overflow: Overflow.visible,
        children: <Widget>[
          Icon(MaterialDesignIcons.getIconDataFromIconName(
              "mdi:television"), color: Colors.white,),
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              height: 16,
              width: 16,
              decoration: new BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "$playersCount",
                  style: Theme.of(context).textTheme.caption.copyWith(
                    color: Colors.white
                  )
                ),
              ),
            ),
          )
        ],
      );
    } else {
      mediaMenuIcon = Icon(MaterialDesignIcons.getIconDataFromIconName(
          "mdi:television"), color: Colors.white,);
    }
    Widget mainScrollBody;
    if (empty) {
      if (_showLoginButton) {
        mainScrollBody = Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FlatButton(
                    child: Text("Login with Home Assistant", style: Theme.of(context).textTheme.button),
                    color: Colors.blue,
                    onPressed: () => _fullLoad(),
                  )
                ]
            )
        );
      } else {
        mainScrollBody = Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text("...")
              ]
          ),
        );
      }
    } else {
      if (_entityToShow != null && MediaQuery.of(context).size.width >= Sizes.tabletMinWidth) {
        mainScrollBody = Flex(
          direction: Axis.horizontal,
          children: <Widget>[
            Expanded(
              child: HomeAssistant().ui.build(context, _viewsTabController),
            ),
            Container(
              width: Sizes.mainPageScreenSeparatorWidth,
              color: Colors.blue,
            ),
            ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: Sizes.entityPageMaxWidth),
              child: EntityPageLayout(entity: _entityToShow, showClose: true,),
            )
          ],
        );
      } else if (_entityToShow != null) {
        mainScrollBody = EntityPageLayout(entity: _entityToShow, showClose: true,);
      } else {
        mainScrollBody = HomeAssistant().ui.build(context, _viewsTabController);
      }
    }

    return NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              floating: true,
              pinned: true,
              primary: true,
              title: Text(HomeAssistant().locationName ?? ""),
              actions: <Widget>[
                IconButton(
                    icon: mediaMenuIcon,
                    onPressed: () {
                      showMenu(
                          position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width, 100.0, 50, 0.0),
                          context: context,
                          items: mediaMenuItems
                      ).then((String val) {
                        if (val == "play_media") {
                          Navigator.pushNamed(context, "/play-media", arguments: {"url": ""});
                        } else  {
                          _showEntityPage(val);
                        }
                      });
                    }
                ),
                IconButton(
                    icon: Icon(MaterialDesignIcons.getIconDataFromIconName(
                        "mdi:dots-vertical"), color: Colors.white,),
                    onPressed: () {
                      showMenu(
                          position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width, 100, 0.0, 0.0),
                          context: context,
                          items: serviceMenuItems
                      ).then((String val) {
                        HomeAssistant().lovelaceDashboardUrl = HomeAssistant.DEFAULT_DASHBOARD;
                        if (val == "reload") {
                          
                          _quickLoad();
                        } else if (val == "logout") {
                          HomeAssistant().logout().then((_) {
                            _quickLoad();
                          });
                        }
                      });
                    }
                )
              ],
              leading: IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState.openDrawer();
                },
              ),
              bottom: (empty || _entityToShow != null) ? null : TabBar(
                controller: _viewsTabController,
                tabs: buildUIViewTabs(),
                isScrollable: true,
              ),
            ),

          ];
        },
        body: mainScrollBody,
        controller: _mainScrollController,
    );
  }

  TabController _viewsTabController;

  @override
  Widget build(BuildContext context) {
    Widget bottomBar;
    if (_showBottomBar) {
      List<Widget> bottomBarChildren = [];
      if (_bottomBarText != null) {
        bottomBarChildren.add(
            Padding(
              padding: EdgeInsets.fromLTRB(
                  Sizes.leftWidgetPadding, Sizes.rowPadding, 0.0,
                  Sizes.rowPadding),
              child: Text(
                "$_bottomBarText",
                textAlign: TextAlign.left,
                softWrap: true,
              ),
            )

        );
      }
      if (_bottomBarProgress) {
        bottomBarChildren.add(
          CollectionScaleTransition(
            children: <Widget>[
              Icon(Icons.stop, size: 10.0, color: HAClientTheme().getOnStateColor(context),),
              Icon(Icons.stop, size: 10.0, color: HAClientTheme().getDisabledStateColor(context),),
              Icon(Icons.stop, size: 10.0, color: HAClientTheme().getOffStateColor(context),),
            ],
          ),
        );
      }
      if (bottomBarChildren.isNotEmpty) {
        bottomBar = Container(
          color: _bottomBarErrorColor ? Theme.of(context).errorColor : Theme.of(context).primaryColorLight,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: _bottomBarProgress ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: bottomBarChildren,
                ),
              ),
              _bottomBarAction
            ],
          ),
        );
      }
    }
    if (HomeAssistant().isNoViews) {
        return Scaffold(
            key: _scaffoldKey,
            primary: false,
            drawer: _buildAppDrawer(),
            bottomNavigationBar: bottomBar,
            body: _buildScaffoldBody(true)
        );
      } else {
        return WillPopScope(
          child: Scaffold(
            key: _scaffoldKey,
            drawer: _buildAppDrawer(),
            primary: false,
            bottomNavigationBar: bottomBar,
            body: _buildScaffoldBody(false)
          ),
          onWillPop: () {
            if (_entityToShow != null) {
              eventBus.fire(ShowEntityPageEvent());
              return Future.value(false);
            } else {
              return Future.value(true);
            }
          },
        );
      }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    //final flutterWebviewPlugin = new FlutterWebviewPlugin();
    //flutterWebviewPlugin.dispose();
    _viewsTabController?.dispose();
    _stateSubscription?.cancel();
    _lovelaceSubscription?.cancel();
    _settingsSubscription?.cancel();
    _serviceCallSubscription?.cancel();
    _showPopupDialogSubscription?.cancel();
    _showPopupMessageSubscription?.cancel();
    _showEntityPageSubscription?.cancel();
    _showErrorSubscription?.cancel();
    _startAuthSubscription?.cancel();
    _showPageSubscription?.cancel();
    _reloadUISubscription?.cancel();
    //TODO disconnect
    //widget.homeAssistant?.disconnect();
    super.dispose();
  }
}
