part of 'main.dart';

class EntityState {
  static const on = 'on';
  static const off = 'off';
  static const home = 'home';
  static const not_home = 'not_home';
  static const unknown = 'unknown';
  static const open = 'open';
  static const opening = 'opening';
  static const closed = 'closed';
  static const closing = 'closing';
  static const playing = 'playing';
  static const paused = 'paused';
  static const idle = 'idle';
  static const standby = 'standby';
  static const alarm_disarmed = 'disarmed';
  static const alarm_armed_home = 'armed_home';
  static const alarm_armed_away = 'armed_away';
  static const alarm_armed_night = 'armed_night';
  static const alarm_armed_custom_bypass = 'armed_custom_bypass';
  static const alarm_pending = 'pending';
  static const alarm_arming = 'arming';
  static const alarm_disarming = 'disarming';
  static const alarm_triggered = 'triggered';
  static const locked = 'locked';
  static const unlocked = 'unlocked';
  static const unavailable = 'unavailable';
  static const ok = 'ok';
  static const problem = 'problem';
  static const active = 'active';
  static const cleaning = 'cleaning';
  static const docked = 'docked';
  static const returning = 'returning';
  static const error = 'error';

}

class EntityUIAction {
  static const moreInfo = 'more-info';
  static const toggle = 'toggle';
  static const callService = 'call-service';
  static const navigate = 'navigate';
  static const none = 'none';

  String tapAction = EntityUIAction.moreInfo;
  String tapNavigationPath;
  String tapService;
  Map<String, dynamic> tapServiceData;
  String holdAction = EntityUIAction.none;
  String holdNavigationPath;
  String holdService;
  Map<String, dynamic> holdServiceData;
  String doubleTapAction = EntityUIAction.none;
  String doubleTapNavigationPath;
  String doubleTapService;
  Map<String, dynamic> doubleTapServiceData;

  EntityUIAction({rawEntityData}) {
    if (rawEntityData != null) {
      if (rawEntityData["tap_action"] != null) {
        if (rawEntityData["tap_action"] is String) {
          tapAction = rawEntityData["tap_action"];
        } else {
          tapAction =
              rawEntityData["tap_action"]["action"] ?? EntityUIAction.moreInfo;
          tapNavigationPath = rawEntityData["tap_action"]["navigation_path"];
          tapService = rawEntityData["tap_action"]["service"];
          tapServiceData = rawEntityData["tap_action"]["service_data"];
        }
      }
      if (rawEntityData["hold_action"] != null) {
        if (rawEntityData["hold_action"] is String) {
          holdAction = rawEntityData["hold_action"];
        } else {
          holdAction =
              rawEntityData["hold_action"]["action"] ?? EntityUIAction.none;
          holdNavigationPath = rawEntityData["hold_action"]["navigation_path"];
          holdService = rawEntityData["hold_action"]["service"];
          holdServiceData = rawEntityData["hold_action"]["service_data"];
        }
      }
      if (rawEntityData["double_tap_action"] != null) {
        if (rawEntityData["double_tap_action"] is String) {
          doubleTapAction = rawEntityData["double_tap_action"];
        } else {
          doubleTapAction =
              rawEntityData["double_tap_action"]["action"] ?? EntityUIAction.none;
          doubleTapNavigationPath = rawEntityData["double_tap_action"]["navigation_path"];
          doubleTapService = rawEntityData["double_tap_action"]["service"];
          doubleTapServiceData = rawEntityData["double_tap_action"]["service_data"];
        }
      }
    }
  }

}

class CardType {
  static const HORIZONTAL_STACK = "horizontal-stack";
  static const VERTICAL_STACK = "vertical-stack";
  static const ENTITIES = "entities";
  static const GLANCE = "glance";
  static const MEDIA_CONTROL = "media-control";
  static const WEATHER_FORECAST = "weather-forecast";
  static const THERMOSTAT = "thermostat";
  static const SENSOR = "sensor";
  static const PLANT_STATUS = "plant-status";
  static const PICTURE_ENTITY = "picture-entity";
  static const PICTURE_ELEMENTS = "picture-elements";
  static const PICTURE = "picture";
  static const MAP = "map";
  static const IFRAME = "iframe";
  static const GAUGE = "gauge";
  static const ENTITY_BUTTON = "entity-button";
  static const ENTITY = "entity";
  static const BUTTON = "button";
  static const CONDITIONAL = "conditional";
  static const ALARM_PANEL = "alarm-panel";
  static const MARKDOWN = "markdown";
  static const LIGHT = "light";
  static const ENTITY_FILTER = "entity-filter";
  static const UNKNOWN = "unknown";
  static const HISTORY_GRAPH = "history-graph";
  static const PICTURE_GLANCE = "picture-glance";
}

class Sizes {
  static const rightWidgetPadding = 10.0;
  static const leftWidgetPadding = 10.0;
  static const buttonPadding = 4.0;
  static const extendedWidgetHeight = 50.0;
  static const iconSize = 28.0;
  static const largeIconSize = 46.0;
  //static const stateFontSize = 15.0;
  //static const nameFontSize = 15.0;
  //static const smallFontSize = 14.0;
  //static const largeFontSize = 24.0;
  static const inputWidth = 160.0;
  static const rowPadding = 10.0;
  static const doubleRowPadding = rowPadding*2;
  static const minViewColumnWidth = 350;
  static const entityPageMaxWidth = 400.0;
  static const mainPageScreenSeparatorWidth = 5.0;
  static const tabletMinWidth = minViewColumnWidth + entityPageMaxWidth + 5;
}