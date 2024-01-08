using Toybox.Activity as Activity;
using Toybox.Application as App;
using Toybox.Application.Storage as Storage;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.Time as Time;
using Toybox.Timer as Timer;
using Toybox.FitContributor as FitContributor;
using Toybox.UserProfile as UserProfile;

enum {
  TYPE_NONE = 0,
  TYPE_DURATION = 1,
  TYPE_DISTANCE = 2,
  TYPE_DISTANCE_TO_NEXT_POINT =3,
  TYPE_DISTANCE_FROM_START = 4,
  TYPE_CADENCE = 5,
  TYPE_SPEED = 6,
  TYPE_PACE = 7,
  TYPE_AVG_SPEED = 8,
  TYPE_AVG_PACE = 9,
  TYPE_HR = 10,
  TYPE_HR_ZONE = 11,
  TYPE_STEPS = 12,
  TYPE_ELEVATION = 13,
  TYPE_MAX_ELEVATION = 14,
  TYPE_ASCENT = 15,
  TYPE_DESCENT = 16,
  TYPE_GRADE = 17,
  TYPE_DAYLIGHT_REMAINING = 18,
  TYPE_CLOCK = 19,
  TYPE_DATA_MAX = 20,
}

enum {
  INFO_CELL_TOP_LEFT = 0,
  INFO_CELL_TOP_RIGHT = 1,
  INFO_CELL_MIDDLE_LEFT = 2,
  INFO_CELL_MIDDLE_RIGHT = 3,
  INFO_CELL_CENTER = 4,
  INFO_CELL_BOTTOM_LEFT = 5,
  INFO_CELL_BOTTOM_RIGHT = 6,
  INFO_CELL_RING_ARC = 7,
  INFO_CELL_TOP_BAR = 8,
  INFO_CELL_MAX = 9,
}

enum {
  STEPS_FIELD_ID = 0,
  STEPS_LAP_FIELD_ID = 1,
}

class HikeFieldv2 extends App.AppBase {

  function initialize() { AppBase.initialize(); }

  function getInitialView() {
    var view = new HikeView();
    return [view];
  }
}

class InfoField {
  const FONT_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

  // Coordinates of top-left of grid entry
  var x = 0;
  var y = 0;

  var headerStr = "";

  function initialize(dcHeight, x_pos, y_pos) {
    x = x_pos;
    y = y_pos;
  }
}

class HikeView extends Ui.DataField {
  hidden var ready = false;

  const FONT_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
  const FONT_HEADER_STR = Graphics.FONT_XTINY;
  const FONT_HEADER_VAL = Graphics.FONT_XTINY;
  var fontValue = Graphics.FONT_NUMBER_MILD;
  const FONT_NOTIFICATIONS = Graphics.FONT_SMALL;
  const FONT_TIME = Graphics.FONT_SMALL;
  const NUM_INFO_FIELDS = 7;  // Number of primary configurable cells (each cell has a header and data)
  const NUM_DATA_FIELDS = INFO_CELL_MAX;  // Total number of configurable data items. The first group correspond to the info cells
  const arcThickness = [1, 3, 5, 7, 10];
  const sunsetTypes = [SUNSET, DUSK, NAUTIC_DUSK, ASTRO_DUSK];
  const valueFontTypes = [Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE, Graphics.FONT_NUMBER_MILD,
                          Graphics.FONT_SYSTEM_SMALL, Graphics.FONT_SYSTEM_MEDIUM, Graphics.FONT_SYSTEM_LARGE];

  var totalStepsField;
  var lapStepsField;

  hidden var kmOrMileInMeters = 1000;
  hidden var mOrFeetsInMeter = 1;
  hidden var is24Hour = true;

  //colors
  const batteryBackground = Graphics.COLOR_WHITE;
  const inverseTextColor = Graphics.COLOR_WHITE;
  const inverseBackgroundColor = Graphics.COLOR_BLACK;
  hidden var textColor = Graphics.COLOR_BLACK;
  hidden var backgroundColor = Graphics.COLOR_WHITE;
  hidden var inactiveGpsBackground = Graphics.COLOR_LT_GRAY;
  hidden var batteryColor1 = Graphics.COLOR_GREEN;
  hidden var hrColor = Graphics.COLOR_RED;
  hidden var headerColor = Graphics.COLOR_DK_GRAY;
  hidden var gridColor = Graphics.COLOR_LT_GRAY;

  hidden var sunriseMoment = null;
  hidden var sunsetMoment = null;

  const fieldTitles = [
    null,                            //  TYPE_NONE = 0,
    Rez.Strings.duration,            //  TYPE_DURATION = 1,
    Rez.Strings.distance,            //  TYPE_DISTANCE = 2,
    Rez.Strings.distanceNextPoint,   //  TYPE_DISTANCE_TO_NEXT_POINT =3,
    Rez.Strings.distanceFromStart,   //  TYPE_DISTANCE_FROM_START = 4,
    Rez.Strings.cadence,             //  TYPE_CADENCE = 5,
    Rez.Strings.speed,               //  TYPE_SPEED = 6,
    Rez.Strings.pace,                //  TYPE_PACE = 7,
    Rez.Strings.avgSpeed,            //  TYPE_AVG_SPEED = 8,
    Rez.Strings.avgPace,             //  TYPE_AVG_PACE = 9,
    Rez.Strings.hr,                  //  TYPE_HR = 10,
    Rez.Strings.hrz,                 //  TYPE_HR_ZONE = 11,
    Rez.Strings.steps,               //  TYPE_STEPS = 12,
    Rez.Strings.elevation,           //  TYPE_ELEVATION = 13,
    Rez.Strings.maxElevation,        //  TYPE_MAX_ELEVATION = 14,
    Rez.Strings.ascent,              //  TYPE_ASCENT = 15,
    Rez.Strings.descent,             //  TYPE_DESCENT = 16,
    Rez.Strings.grade,               //  TYPE_GRADE = 17,
    Rez.Strings.daylight,            //  TYPE_DAYLIGHT_REMAINING = 18,
    Rez.Strings.clock,               //  TYPE_CLOCK = 19,
  ];

  var InfoHeaderMapping = new[NUM_INFO_FIELDS]; // Only info fields have headers
  var InfoValueMapping = new[NUM_DATA_FIELDS];  // There are other data fields (top bar, central ring)
  var InfoValues = new[TYPE_DATA_MAX];

  //data
  hidden var maxelevation = -65536;
  hidden var grade = 0;
  hidden var pressure = 0;
  hidden var gpsSignal = 0;
  hidden var stepPrev = 0;
  hidden var stepCount = 0;
  hidden var stepPrevLap = 0;
  hidden var stepsPerLap = [];
  hidden var startTime = [];
  hidden var stepsAddedToField = 0;

  hidden var sunCalc = new SunCalc();

  hidden var daylightAtStart = 0;
  hidden var daylightRemaining = 0;

  hidden var hasAmbientPressure = false;

  hidden var checkStorage = false;

  hidden var phoneConnected = false;
  hidden var notificationCount = 0;

  hidden var hasBackgroundColorOption = false;

  hidden var doUpdates = 0;
  hidden var activityRunning = false;

  hidden var dcWidth = 0;
  hidden var dcHeight = 0;
  hidden var centerAreaHeight = 0;
  hidden var centerX = 0;

  hidden var infoFields = new[NUM_INFO_FIELDS];
  hidden var timeOffsetY;
  hidden var topBarHeight;
  hidden var bottomBarHeight;
  hidden var bottomOffset;
  hidden var centerRingRadius;

  hidden var settingsNotification = Application.getApp().getProperty("SN");    // showNotifications
  hidden var settingsGradePressure = Application.getApp().getProperty("SGP");  // showGridPressure
  hidden var firstLocation = null;

  hidden var hrZoneInfo;

  hidden var gradeBuffer = new[10];
  hidden var gradeBufferPos = 0;
  hidden var gradeBufferSkip = 0;
  hidden var gradePrevData = 0.0;
  hidden var gradePrevDistance = 0.0;
  hidden var gradeFirst = true;
  hidden var alwaysDrawCentralRing = false;
  hidden var centralRingThickness = 2;
  hidden var sunsetType = 0;

  function initialize() {
    DataField.initialize();

    // clang-format off
    totalStepsField = createField(Ui.loadResource(Rez.Strings.steps_label), STEPS_FIELD_ID, FitContributor.DATA_TYPE_UINT32,
                                  {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => Ui.loadResource(Rez.Strings.steps_unit)});

    lapStepsField = createField(Ui.loadResource(Rez.Strings.steps_label), STEPS_LAP_FIELD_ID, FitContributor.DATA_TYPE_UINT32,
                                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => Ui.loadResource(Rez.Strings.steps_unit)});

    hrZoneInfo = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);

    for (var i = 0; i < 10; i++) {
      gradeBuffer[i] = null;
    }

    if (Activity.Info has :ambientPressure) {
      hasAmbientPressure = true;
    }
    // clang-format on
  }

  function loadSettings() {
    var app = Application.getApp();

    /* Load data cell mapping from user settings */
    for (var i = 0; i < NUM_DATA_FIELDS; i++) {
      // Load the data mapping for each info cell body, and for the items beyond the info cell range
      // Data mappings are for the big text in each cell.
      var valueMapping = app.getProperty("D" + i);
      InfoValueMapping[i] = valueMapping;

      // Load the header mapping for each info cell.
      // The headers are the small text at the top of each cell.
      // If a header doesn't have anything assigned to it, use the title of the data item from that cell.
      if (i < NUM_INFO_FIELDS) {
        var headerMapping = app.getProperty("H" + i);
        InfoHeaderMapping[i] = headerMapping;

        // Set up headers for fields that don't show data in the header
        var res = fieldTitles[valueMapping];
        if (headerMapping == TYPE_NONE && res != null) {
          infoFields[i].headerStr = Ui.loadResource(res);
        }
      }
    }

    alwaysDrawCentralRing = app.getProperty("ADCR");  // alwaysDrawCentralRing
    centralRingThickness = app.getProperty("CRT");  // centralRingThickness
    sunsetType = app.getProperty("SST");  // sunsetType
    fontValue = valueFontTypes[app.getProperty("FT")];  // valueFontType

    // Don't draw central ring if there's nothing in it and if the arc indicator is disabled
    if (InfoHeaderMapping[INFO_CELL_CENTER] == TYPE_NONE && InfoValueMapping[INFO_CELL_CENTER] == TYPE_NONE &&
        InfoValueMapping[INFO_CELL_RING_ARC] == TYPE_NONE) {
      centerRingRadius = 0;
    }
  }

  function computeDistance(pos1, pos2) {
    var lat1 = pos1.toDegrees()[0].toFloat();
    var lon1 = pos1.toDegrees()[1].toFloat();
    var lat2 = pos2.toDegrees()[0].toFloat();
    var lon2 = pos2.toDegrees()[1].toFloat();

    var lat = (lat1 + lat2) / 2 * 0.01745;
    var dx = 111.3 * Math.cos(lat) * (lon1 - lon2);
    var dy = 111.3 * (lat1 - lat2);
    return 1000 * Math.sqrt(dx * dx + dy * dy);
  }

  function formatTime(elapsedTime) {
    var hours = null;
    var minutes = elapsedTime / 60;
    var seconds = elapsedTime % 60;

    if (minutes >= 60) {
      hours = minutes / 60;
      minutes = minutes % 60;
    }

    if (hours == null) {
      return minutes.format("%d") + ":" + seconds.format("%02d");
    } else {
      return hours.format("%d") + ":" + minutes.format("%02d");
    }
  }

  function formatDistance(fieldType, distance) {
    var distanceKmOrMiles = distance / kmOrMileInMeters;
    if (distanceKmOrMiles < 100) {
      InfoValues[fieldType] = distanceKmOrMiles.format("%.2f");
    } else {
      InfoValues[fieldType] = distanceKmOrMiles.format("%.1f");
    }
  }

  function formatSpeed(speedFieldType, paceFieldType, speed) {
    if (speed == null) {
      speed = 0;
    }

    speed = speed * 3600 / kmOrMileInMeters;
    InfoValues[speedFieldType] = speed.format("%.1f");

    if (speed >= 1) {
      var pace = (3600 / speed).toLong();
      InfoValues[paceFieldType] = (pace / 60).format("%d") + ":" + (pace % 60).format("%02d");
    } else {
      InfoValues[paceFieldType] = "--:--";
    }
  }

  function compute(info) {
    InfoValues[TYPE_DURATION] = formatTime((info.timerTime != null ? info.timerTime : 0) / 1000);

    daylightAtStart = secondsToSunset(info.currentLocation, info.startTime);
    daylightRemaining = secondsToSunset(info.currentLocation, Time.now());

    var hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
    InfoValues[TYPE_HR] = hr;

    var distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
    var distanceToNextPoint = null;
    if (info has :distanceToNextPoint) {
      distanceToNextPoint = info.distanceToNextPoint;
    }

    formatDistance(TYPE_DISTANCE, distance);


    if (distanceToNextPoint != null) {
      formatDistance(TYPE_DISTANCE_TO_NEXT_POINT, distanceToNextPoint);
    }

    var startLocation = info.startLocation;
    var currentLocation = info.currentLocation;

    if (startLocation == null) {
      if (firstLocation == null) {
        firstLocation = currentLocation;
      }

      startLocation = firstLocation;
    }

    if (startLocation != null && currentLocation != null) {
      formatDistance(TYPE_DISTANCE_FROM_START, computeDistance(startLocation, currentLocation));
    } else {
      InfoValues[TYPE_DISTANCE_FROM_START] = "---";
    }

    gpsSignal = info.currentLocationAccuracy != null ? info.currentLocationAccuracy : 0;
    InfoValues[TYPE_CADENCE] = info.currentCadence != null ? info.currentCadence : 0;

    formatSpeed(TYPE_SPEED, TYPE_PACE, info.currentSpeed);
    formatSpeed(TYPE_AVG_SPEED, TYPE_AVG_PACE, info.averageSpeed);

    InfoValues[TYPE_ASCENT] = info.totalAscent != null ? (info.totalAscent * mOrFeetsInMeter).format("%.0f") : 0;
    InfoValues[TYPE_DESCENT] = info.totalDescent != null ? (info.totalDescent * mOrFeetsInMeter).format("%.0f") : 0;
    var elevation = info.altitude != null ? info.altitude : 0;
    InfoValues[TYPE_ELEVATION] = elevation.format("%.0f");

    if (hasAmbientPressure) {
      pressure = info.ambientPressure != null ? info.ambientPressure : 0;
    }

    var hrZone = 0;

    for (var i = hrZoneInfo.size(); i > 0; i--) {
      if (hr > hrZoneInfo[i - 1]) {
        hrZone = i;
        break;
      }
    }

    if (hr == 0) {
      hrZone = 0;
    } else if (hrZone == 6) {
      hrZone = 5;
    } else {
      var diff;
      if (hrZone == 0) {
        diff = hrZoneInfo[hrZone] / 2;
        diff = (hr.toFloat() - hrZoneInfo[hrZone] / 2) / diff;
      } else {
        diff = hrZoneInfo[hrZone] - hrZoneInfo[hrZone - 1];
        diff = (hr.toFloat() - hrZoneInfo[hrZone - 1]) / diff;
      }
      hrZone = hrZone + diff;
    }

    InfoValues[TYPE_HR_ZONE] = hrZone.format("%.1f");

    if (stepsAddedToField < stepsPerLap.size() * 2) {
      if (stepsAddedToField & 0x1) {
        lapStepsField.setData(stepsPerLap[stepsAddedToField / 2]);
      }
      stepsAddedToField++;
    }

    if (activityRunning) {
      if (checkStorage && Activity.getActivityInfo().startTime != null) {
        checkStorage = false;
        var savedStartTime = null;
        startTime = Activity.getActivityInfo().startTime;
        savedStartTime = Storage.getValue("startTime");
        if (savedStartTime != null && startTime != null && startTime.value() == savedStartTime) {
          stepCount = Storage.getValue("totalSteps");
          stepsPerLap = Storage.getValue("stepsPerLap");
          if (stepsPerLap.size() > 0) {
            stepPrevLap = stepsPerLap[stepsPerLap.size() - 1];
          }
        }
      }
      var stepCur = ActivityMonitor.getInfo().steps;
      if (stepCur < stepPrev) {
        stepCount = stepCount + stepCur;
        stepPrev = stepCur;
      } else {
        stepCount = stepCount + stepCur - stepPrev;
        stepPrev = stepCur;
      }
    }

    InfoValues[TYPE_STEPS] = stepCount;

    var mySettings = System.getDeviceSettings();
    phoneConnected = mySettings.phoneConnected;
    if (phoneConnected) {
      notificationCount = mySettings.notificationCount;
    }

    if (distance > 0) {
      if (gradeFirst) {
        if (!settingsGradePressure) {
          gradePrevData = elevation;
        } else {
          gradePrevData = pressure;
        }
        gradePrevDistance = distance;
        gradeFirst = false;
      }

      var change = false;
      gradeBufferSkip++;
      if (gradeBufferSkip == 5) {
        gradeBufferSkip = 0;
        change = true;
      }

      if (change) {
        if (distance != gradePrevDistance) {
          if (!settingsGradePressure || !hasAmbientPressure) {
            gradeBuffer[gradeBufferPos] = (elevation - gradePrevData) / (distance - gradePrevDistance);
            gradePrevData = elevation;
          } else {
            gradeBuffer[gradeBufferPos] = (8434.15 * (gradePrevData - pressure) / pressure) / (distance - gradePrevDistance);
            gradePrevData = pressure;
          }
          gradePrevDistance = distance;
          gradeBufferPos++;

          if (gradeBufferPos == 10) {
            gradeBufferPos = 0;
          }

          var gradeSum = 0.0;
          var gradeNum = 0;

          for (var i = 0; i < 10; i++) {
            if (gradeBuffer[i] != null) {
              gradeNum++;
              gradeSum += gradeBuffer[i];
            }
          }
          grade = 100 * gradeSum / gradeNum;
        }
      }
    }
    InfoValues[TYPE_GRADE] = grade.format("%.1f");

    elevation *= mOrFeetsInMeter;
    if (elevation > maxelevation) {
      maxelevation = elevation;
    }
    InfoValues[TYPE_MAX_ELEVATION] = maxelevation.format("%.0f");
    InfoValues[TYPE_DAYLIGHT_REMAINING] = formatTime(daylightRemaining);

    var clockTime = System.getClockTime();
    var time = "";
    var hour = clockTime.hour;

    if (!is24Hour) {
      if (hour < 1) {
        hour += 12;
      }
      if (hour > 12) {
        hour -= 12;
      }
      time = (clockTime.hour < 12) ? " am" : " pm";
    }

    InfoValues[TYPE_CLOCK] = hour + ":" + clockTime.min.format("%.2d") + time;

    ready = true;
  }

  function onLayout(dc) {
    if (System.getDeviceSettings().distanceUnits != System.UNIT_METRIC) {
      kmOrMileInMeters = 1609.344;
    }

    if (System.getDeviceSettings().elevationUnits != System.UNIT_METRIC) {
      mOrFeetsInMeter = 3.2808399;
    }
    is24Hour = System.getDeviceSettings().is24Hour;

    // clang-format off
    hasBackgroundColorOption = (self has :getBackgroundColor);
    // clang-format on

    dcHeight = dc.getHeight();
    dcWidth = dc.getWidth();
    centerX = dcWidth / 2;
    topBarHeight = dcHeight / 7;
    timeOffsetY = topBarHeight - Graphics.getFontHeight(FONT_TIME) / 2;
    bottomBarHeight = dcHeight / 8;
    bottomOffset = dcHeight / 8 - 21;
    centerRingRadius = dcHeight / 8;  // Default radius, if arc indicator is OFF. May become wider if on.
    centerAreaHeight = dcHeight - topBarHeight - bottomBarHeight;

    // Layout positions for the seven grid items we'll be displaying
    // Each grid item has a header (small font) and a value (large font)
    // In some situations, the header may contain a title; in others, this
    // may be an auxiliary value
    infoFields[INFO_CELL_TOP_LEFT] = new InfoField(dcHeight, dcWidth * 2 / 7, topBarHeight);
    infoFields[INFO_CELL_TOP_RIGHT] = new InfoField(dcHeight, dcWidth - dcWidth * 2 / 7, topBarHeight);
    infoFields[INFO_CELL_MIDDLE_LEFT] = new InfoField(dcHeight, dcWidth * 2 / 11, topBarHeight + centerAreaHeight / 3);
    infoFields[INFO_CELL_MIDDLE_RIGHT] = new InfoField(dcHeight, dcWidth - dcWidth * 2 / 11, topBarHeight + centerAreaHeight / 3);
    infoFields[INFO_CELL_CENTER] = new InfoField(dcHeight, dcWidth / 2, topBarHeight + centerAreaHeight / 3);
    infoFields[INFO_CELL_BOTTOM_LEFT] = new InfoField(dcHeight, dcWidth / 3.5, topBarHeight + centerAreaHeight / 3 * 2);
    infoFields[INFO_CELL_BOTTOM_RIGHT] = new InfoField(dcHeight, dcWidth - dcWidth / 3.5, topBarHeight + centerAreaHeight / 3 * 2);

    loadSettings();

    // Don't draw central ring if the ring indicator doesn't call for it
    if (!alwaysDrawCentralRing) {
      centerRingRadius = 0;
    }

    // If arc indicator is enabled, use a wider radius for the central ring
    if (InfoValueMapping[INFO_CELL_RING_ARC] != TYPE_NONE) {
      centerRingRadius = dcHeight / 7.3;
    }
  }

  function onShow() { doUpdates = true; }

  function onHide() { doUpdates = false; }

  function secondsToSunset(position, to_moment) {
    if (position == null) {
      return 0;
    }

    if (to_moment == null) {
      return 0;
    }

    var location = position.toRadians();

    if (location == null) {
      return 0;
    }

    var now = Time.now();

    if (sunriseMoment == null) {
      sunriseMoment = sunCalc.calculate(now, location, SUNRISE);
    }

    if (sunsetMoment == null) {
      sunsetMoment = sunCalc.calculate(now, location, sunsetTypes[sunsetType]);
    }

    if (sunriseMoment == null || sunsetMoment == null) {
      return 0;
    }

    var sec_until_sunrise = sunriseMoment.compare(to_moment);
    var sec_until_sunset = sunsetMoment.compare(to_moment);

    /*
    System.println("Sunrise = " + sunCalc.printMoment(sunrise) + "   to = " + sunCalc.printMoment(to_moment) + "   delta = " + sec_until_sunrise);
    System.println("Sunset  = " + sunCalc.printMoment(sunset) +  "   to = " + sunCalc.printMoment(to_moment) + "   delta = " + sec_until_sunset);
    System.println("\n");

        Both positive; sunrise is smaller --> still dark
            Sunrise = 16.12.2023 03:58:56   to = 16.12.2023 03:01:09   delta = 3467
            Sunset  = 16.12.2023 16:00:00   to = 16.12.2023 03:01:09   delta = 46731

        Sunrise negative, sunset positive  --> sun is up
            Sunrise = 16.12.2023 03:58:56   to = 16.12.2023 03:59:30   delta = -34
            Sunset  = 16.12.2023 16:00:00   to = 16.12.2023 03:59:30   delta = 43230

        Both negative, sunrise is more negative -> sun has set
            Sunrise = 16.12.2023 03:58:56   to = 16.12.2023 16:00:05   delta = -43269
            Sunset  = 16.12.2023 16:00:00   to = 16.12.2023 16:00:05   delta = -5

        Early hours of the next day -> both positibe, sunrise is smaller --> still dark
            Sunrise = 17.12.2023 04:01:04   to = 17.12.2023 01:00:18   delta = 10846
            Sunset  = 17.12.2023 16:00:00   to = 17.12.2023 01:00:18   delta = 53982

    */

    if (sec_until_sunrise < 0 && sec_until_sunset > 0) {
      return sec_until_sunset;
    }

    return 0;
  }

  function onUpdate(dc) {
    if (doUpdates == false) {
      return;
    }

    dc.clear();

    if (!ready) {
      return;
    }

    if (hasBackgroundColorOption) {
      if (backgroundColor != getBackgroundColor()) {
        backgroundColor = getBackgroundColor();
        if (backgroundColor == Graphics.COLOR_BLACK) {
          textColor = Graphics.COLOR_WHITE;
          batteryColor1 = Graphics.COLOR_BLUE;
          hrColor = Graphics.COLOR_BLUE;
          headerColor = Graphics.COLOR_LT_GRAY;
          gridColor = Graphics.COLOR_DK_GRAY;
          inactiveGpsBackground = Graphics.COLOR_DK_GRAY;
        } else {
          textColor = Graphics.COLOR_BLACK;
          batteryColor1 = Graphics.COLOR_GREEN;
          hrColor = Graphics.COLOR_RED;
          headerColor = Graphics.COLOR_DK_GRAY;
          gridColor = Graphics.COLOR_LT_GRAY;
        }
      }
    }

    dc.setColor(backgroundColor, backgroundColor);
    dc.fillRectangle(0, 0, dcWidth, dcHeight);

    // Draw text in the top bar (usually the clock)
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.fillRectangle(0, 0, dcWidth, topBarHeight);
    dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
    dc.drawText(centerX, timeOffsetY, FONT_TIME, InfoValues[InfoValueMapping[INFO_CELL_TOP_BAR]], FONT_JUSTIFY);

    drawBottomBar(dc);

    //grid start
    dc.setPenWidth(2);
    dc.setColor(gridColor, Graphics.COLOR_TRANSPARENT);
    dc.drawLine(0, topBarHeight, dcWidth, topBarHeight);
    dc.drawLine(0, dcHeight - bottomBarHeight, dcWidth, dcHeight - bottomBarHeight);

    // Vertical line that runs down the center of the screen
    dc.drawLine(centerX, topBarHeight, centerX, infoFields[2].y);
    dc.drawLine(centerX, infoFields[5].y, centerX, dcHeight - bottomBarHeight - 1);

    // Horizontal line 1
    dc.drawLine(0, infoFields[2].y, dcWidth, infoFields[2].y);

    // Horizontal line 2
    dc.drawLine(0, infoFields[5].y, dcWidth, infoFields[5].y);

    // Draw central ring, if present
    if (centerRingRadius > 0) {
      dc.setColor(backgroundColor, backgroundColor);
      dc.fillCircle(centerX, topBarHeight + centerAreaHeight / 2, centerRingRadius);

      dc.setColor(gridColor, Graphics.COLOR_TRANSPARENT);
      dc.drawCircle(centerX, topBarHeight + centerAreaHeight / 2, centerRingRadius + 1);
    }

    dc.setPenWidth(1);

    var cellHeaderOffset = dcHeight / 19;
    var cellValueOffset = dcHeight / 6;

    // Draw each info cell
    for (var i = 0; i < NUM_INFO_FIELDS; i++) {
      var valueStr = "";
      var headerStyle = FONT_HEADER_STR;

      if (InfoHeaderMapping[i] != TYPE_NONE) {
        infoFields[i].headerStr = InfoValues[InfoHeaderMapping[i]];
        headerStyle = FONT_HEADER_VAL;
      }

      if (InfoValueMapping[i] != TYPE_NONE) {
        valueStr = InfoValues[InfoValueMapping[i]];
      }

      // TODO: Get rid of this when we add themes / custom colors
      var valColor = textColor;
      if (InfoValueMapping[i] == TYPE_HR) {
        valColor = hrColor;
      }

      dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
      dc.drawText(infoFields[i].x, infoFields[i].y + cellHeaderOffset, headerStyle, infoFields[i].headerStr, FONT_JUSTIFY);
      dc.setColor(valColor, Graphics.COLOR_TRANSPARENT);
      dc.drawText(infoFields[i].x, infoFields[i].y + cellValueOffset, fontValue, valueStr, FONT_JUSTIFY);
    }

    // Draw daylight remaining
    if (InfoValueMapping[INFO_CELL_RING_ARC] == TYPE_DAYLIGHT_REMAINING && daylightAtStart > 0 && daylightRemaining > 0) {
      var ring_fill_level = daylightRemaining.toFloat() / daylightAtStart.toFloat();

      if (ring_fill_level > 1.0) {
        ring_fill_level = 1.0;
      }

      dc.setPenWidth(arcThickness[centralRingThickness]);

      if (ring_fill_level < 0.10) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
      } else if (ring_fill_level < 0.20) {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
      } else {
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
      }

      dc.drawArc(centerX, topBarHeight + centerAreaHeight / 2, centerRingRadius + 1, Graphics.ARC_CLOCKWISE, 90, 90 - (360.0 * ring_fill_level));
    }
  }

  function drawBottomBar(dc) {
    var bottomBarY = topBarHeight + centerAreaHeight;
    var bottomTextY = bottomBarY + Graphics.getFontHeight(FONT_NOTIFICATIONS) / 2;

    // Fill in the bottom bar
    dc.setColor(inverseBackgroundColor, inverseBackgroundColor);
    dc.fillRectangle(0, dcHeight - bottomBarHeight, dcWidth, bottomBarHeight);
    dc.setPenWidth(1);

    // Draw number of notifications
    if (settingsNotification) {
      var notificationVal = "-";
      if (phoneConnected) {
        notificationVal = notificationCount.format("%d");
      }

      dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
      dc.drawText(centerX, bottomTextY, FONT_NOTIFICATIONS, notificationVal, FONT_JUSTIFY);
    }

    //battery and gps start
    var batteryHeight = dcHeight / 25;
    drawBattery(System.getSystemStats().battery, dc, centerX - dcWidth / 7, bottomTextY - batteryHeight / 2, dcWidth / 15, batteryHeight);

    var gpsHeight = dcHeight / 20;
    var gpsX = centerX + dcWidth / 15;
    var gpsY = bottomTextY + gpsHeight / 2 - gpsHeight * 0.1;
    var barWidth = dcWidth / 60;

    // Draw GPS bars
    for (var i = 0; i < 3; i++) {
      var barHeight = gpsHeight * (i + 2) / 5;
      var barX = gpsX + barWidth * i;

      // Draw bar outline
      dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
      dc.drawRectangle(barX, gpsY - barHeight, barWidth, barHeight);

      // Fill bar
      if (gpsSignal < i + 2) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
      } else {
        dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
      }
      dc.fillRectangle(barX + 1, gpsY - barHeight + 1, barWidth - 2, barHeight - 2);
    }
  }

  function onTimerStart() {
    activityRunning = true;
    stepPrev = ActivityMonitor.getInfo().steps;
    checkStorage = true;
  }

  function onTimerResume() {
    activityRunning = true;
    stepPrev = ActivityMonitor.getInfo().steps;
  }

  function onTimerPause() { activityRunning = false; }

  function onTimerStop() {
    var sum = 0;
    Storage.setValue("startTime", Activity.getActivityInfo().startTime.value());
    Storage.setValue("totalSteps", stepCount);
    Storage.setValue("stepsPerLap", stepsPerLap);
    activityRunning = false;
    totalStepsField.setData(stepCount);
    for (var i = 0; i < stepsPerLap.size(); i++) {
      sum += stepsPerLap[i];
    }
    lapStepsField.setData(stepCount - sum);
  }

  function onTimerLap() {
    stepsPerLap.add(stepCount - stepPrevLap);
    stepPrevLap = stepCount;
  }

  function drawBattery(battery, dc, xStart, yStart, width, height) {
    dc.setColor(batteryBackground, inactiveGpsBackground);
    dc.fillRectangle(xStart, yStart, width, height);

    if (battery < 10) {
      dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
      dc.drawText(xStart + 3 + width / 2, yStart + 7, FONT_HEADER_STR, battery.format("%d") + "%", FONT_JUSTIFY);
    } else if (battery < 30) {
      dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    } else {
      dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
    }
    dc.fillRectangle(xStart + 1, yStart + 1, (width - 2) * battery / 100, height - 2);

    dc.setColor(batteryBackground, batteryBackground);
    dc.fillRectangle(xStart + width - 1, yStart + 3, 4, height - 6);
  }
}
