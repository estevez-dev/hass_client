part of '../main.dart';

enum StatelessEntityType {none, missed, ghost, divider, section, callService, webLink}

class Entity {

  static List badgeDomains = [
    "alarm_control_panel",
    "binary_sensor",
    "device_tracker",
    "updater",
    "sun",
    "timer",
    "sensor"
  ];

  static Map StateByDeviceClass = {
    "battery.on": "Low",
    "battery.off": "Normal",
    "cold.on": "Cold",
    "cold.off": "Normal",
    "connectivity.on": "Connected",
    "connectivity.off": "Disconnected",
    "door.on": "Open",
    "door.off": "Closed",
    "garage_door.on": "Open",
    "garage_door.off": "Closed",
    "gas.on": "Detected",
    "gas.off": "Clear",
    "heat.on": "Hot",
    "heat.off": "Normal",
    "light.on": "Detected",
    "lignt.off": "No light",
    "lock.on": "Unlocked",
    "lock.off": "Locked",
    "moisture.on": "Wet",
    "moisture.off": "Dry",
    "motion.on": "Detected",
    "motion.off": "Clear",
    "moving.on": "Moving",
    "moving.off": "Stopped",
    "occupancy.on": "Occupied",
    "occupancy.off": "Clear",
    "opening.on": "Open",
    "opening.off": "Closed",
    "plug.on": "Plugged in",
    "plug.off": "Unplugged",
    "power.on": "Powered",
    "power.off": "No power",
    "presence.on": "Home",
    "presence.off": "Away",
    "problem.on": "Problem",
    "problem.off": "OK",
    "safety.on": "Unsafe",
    "safety.off": "Safe",
    "smoke.on": "Detected",
    "smoke.off": "Clear",
    "sound.on": "Detected",
    "sound.off": "Clear",
    "vibration.on": "Detected",
    "vibration.off": "Clear",
    "window.on": "Open",
    "window.off": "Closed"
  };

  Map attributes;
  String domain;
  String entityId;
  String entityPicture;
  String state;
  String displayState;
  DateTime lastUpdatedTimestamp;
  StatelessEntityType statelessType = StatelessEntityType.none;

  List<Entity> childEntities = [];
  String deviceClass;
  EntityHistoryConfig historyConfig = EntityHistoryConfig(
    chartType: EntityHistoryWidgetType.simple
  );

  String get displayName {
    if (attributes.containsKey('friendly_name')) {
      return attributes['friendly_name'];
    }
    if (attributes.containsKey('name')) { 
      return attributes['name'];
    }
    if (entityId == null) {
      return "";
    }
    if (entityId.contains(".")) {
      return entityId.split(".")[1].replaceAll("_", " ");
    }
    return entityId;
  }

  bool get isView =>
      (domain == "group") &&
      (attributes != null ? attributes["view"] ?? false : false);
  bool get isGroup => domain == "group";
  bool get isBadge => Entity.badgeDomains.contains(domain);
  String get icon => attributes["icon"] ?? "";
  bool get isOn => state == EntityState.on;
  String get unitOfMeasurement => attributes["unit_of_measurement"] ?? "";
  List get childEntityIds => attributes["entity_id"] ?? [];
  String get lastUpdated => _getLastUpdatedFormatted();
  bool get isHidden => attributes["hidden"] ?? false;
  double get doubleState => double.tryParse(state) ?? 0.0;
  int get supportedFeatures => attributes["supported_features"] ?? 0;

  String _getEntityPictureUrl(String webHost) {
    String result = attributes["entity_picture"];
    if (result == null) return result;
    if (!result.startsWith("http")) {
      if (result.startsWith("/")) {
        result = "$webHost$result";
      } else {
        result = "$webHost/$result";
      }
    }
    return result;
  }

  Entity(Map rawData, String webHost) {
    update(rawData, webHost);
  }

  Entity.missed(String entityId) {
    statelessType = StatelessEntityType.missed;
    attributes = {"hidden": false};
    this.entityId = entityId;
  }

  Entity.divider() {
    statelessType = StatelessEntityType.divider;
    attributes = {"hidden": false};
  }

  Entity.section(String label) {
    statelessType = StatelessEntityType.section;
    attributes = {"hidden": false, "friendly_name": "$label"};
  }

  Entity.ghost(String name, String icon) {
    statelessType = StatelessEntityType.ghost;
    attributes = {"icon": icon, "hidden": false, "friendly_name": name};
  }

  Entity.callService({String icon, String name, String service, String actionName}) {
    statelessType = StatelessEntityType.callService;
    entityId = service;
    displayState = actionName?.toUpperCase() ?? "RUN";
    attributes = {"hidden": false, "friendly_name": "$name", "icon": "$icon"};
  }

  Entity.weblink({String url, String name, String icon}) {
    statelessType = StatelessEntityType.webLink;
    entityId = "custom.custom";
    attributes = {"hidden": false, "friendly_name": "${name ?? url}", "icon": "${icon ?? 'mdi:link'}"};
  }

  void update(Map rawData, String webHost) {
    attributes = rawData["attributes"] ?? {};
    domain = rawData["entity_id"] != null ? rawData["entity_id"].split(".")[0] : null;
    entityId = rawData["entity_id"];
    deviceClass = attributes["device_class"];
    state = rawData["state"] is bool ? (rawData["state"] ? EntityState.on : EntityState.off) : rawData["state"];
    displayState = Entity.StateByDeviceClass["$deviceClass.$state"] ?? (state.toLowerCase() == 'unknown' ? '-' : state);
    lastUpdatedTimestamp = DateTime.tryParse(rawData["last_updated"]);
    entityPicture = _getEntityPictureUrl(webHost);
  }

  double _getDoubleAttributeValue(String attributeName) {
    var temp1 = attributes["$attributeName"];
    if (temp1 is int) {
      return temp1.toDouble();
    } else if (temp1 is double) {
      return temp1;
    } else {
      return double.tryParse("$temp1");
    }
  }

  int _getIntAttributeValue(String attributeName) {
    var temp1 = attributes["$attributeName"];
    if (temp1 is int) {
      return temp1;
    } else if (temp1 is double) {
      return temp1.round();
    } else {
      return int.tryParse("$temp1");
    }
  }

  List<String> getStringListAttributeValue(String attribute) {
    if (attributes["$attribute"] != null) {
      List<String> result = (attributes["$attribute"] as List).cast<String>();
      return result;
    } else {
      return null;
    }
  }

  Widget buildDefaultWidget(BuildContext context) {
    return DefaultEntityContainer(
        state: _buildStatePart(context)
    );
  }

  Widget _buildStatePart(BuildContext context) {
    return SimpleEntityState();
  }

  Widget _buildStatePartForPage(BuildContext context) {
    return _buildStatePart(context);
  }

  Widget _buildAdditionalControlsForPage(BuildContext context) {
    return Container(
      width: 0.0,
      height: 0.0,
    );
  }

  String getAttribute(String attributeName) {
    if (attributes != null) {
      return attributes["$attributeName"].toString();
    }
    return null;
  }

  String _getLastUpdatedFormatted() {
    if (lastUpdatedTimestamp == null) {
      return "-";
    } else {
      DateTime now = DateTime.now();
      Duration d = now.difference(lastUpdatedTimestamp);
      String text;
      int v;
      if (d.inDays == 0) {
        if (d.inHours == 0) {
          if (d.inMinutes == 0) {
            text = "seconds ago";
            v = d.inSeconds;
          } else {
            text = "minutes ago";
            v = d.inMinutes;
          }
        } else {
          text = "hours ago";
          v = d.inHours;
        }
      } else {
        text = "days ago";
        v = d.inDays;
      }
      return "$v $text";
    }
  }
}
