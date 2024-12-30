using Toybox.Activity as Activity;
using Toybox.Application as App;
using Toybox.Application.Storage as Storage;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.Time as Time;
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
  TYPE_PRESSURE = 20,
  TYPE_DAY_STEPS = 21,
  TYPE_DAY_STEP_GOAL = 22,
  TYPE_WEEK_ACT_MIN = 23,
  TYPE_WEEK_ACT_GOAL = 24,
  TYPE_CALORIES = 25,
  TYPE_AVG_HR = 26,
  TYPE_BATTERY = 27,
  TYPE_DATA_MAX = 28,
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
  // Coordinates of top-left of grid entry
  var x;
  var y;

  var headerStr = "";

  function initialize(x_pos, y_pos) {
    x = x_pos;
    y = y_pos;
  }
}

class HikeView extends Ui.DataField {
  hidden var ready = false;
  hidden var settingsLoaded = false;

  const FONT_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
  const FONT_HEADER = Graphics.FONT_XTINY;
  var fontValue = Graphics.FONT_NUMBER_MILD;
  const FONT_NOTIFICATIONS = Graphics.FONT_SMALL;
  const FONT_TIME = Graphics.FONT_SMALL;
  const NUM_INFO_FIELDS = 7;  // Number of primary configurable cells (each cell has a header and data)
  const NUM_DATA_FIELDS = INFO_CELL_MAX;  // Total number of configurable data items. The first group correspond to the info cells
  const arcThickness = [1, 3, 5, 7, 10];
  const sunsetTypes = [SUNSET, DUSK, NAUTIC_DUSK, ASTRO_DUSK];
  const valueFontTypes = [Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE, Graphics.FONT_NUMBER_MILD,
                          Graphics.FONT_SYSTEM_SMALL, Graphics.FONT_SYSTEM_MEDIUM, Graphics.FONT_SYSTEM_LARGE];

  const NUM_HRZ_COLORS = 7;
  const hrzColors = [
      // Light background
      Graphics.COLOR_DK_GRAY,     // No zone
      Graphics.COLOR_BLACK,       // Warm-up
      Graphics.COLOR_BLUE,        // Easy
      Graphics.COLOR_GREEN,       // Aerobic
      Graphics.COLOR_YELLOW,      // Threshold
      Graphics.COLOR_RED,         // Max
      Graphics.COLOR_RED,        // Max (filled)

       // Dark background
       Graphics.COLOR_LT_GRAY,   // No zone
       Graphics.COLOR_WHITE,     // Warm-up
       Graphics.COLOR_BLUE,      // Easy
       Graphics.COLOR_GREEN,     // Aerobic
       Graphics.COLOR_YELLOW,    // Threshold
       Graphics.COLOR_RED,       // Max
       Graphics.COLOR_RED];      // Max (filled)

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
  hidden var batteryColor1 = Graphics.COLOR_GREEN;
  hidden var hrColor = Graphics.COLOR_RED;
  hidden var headerColor = Graphics.COLOR_DK_GRAY;
  hidden var gridColor = Graphics.COLOR_LT_GRAY;

  hidden var sunriseUtc = null;
  hidden var sunsetUtc = null;

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

  hidden var ringFillLevel = -1;

  hidden var hasAmbientPressure = false;

  hidden var checkStorage = false;

  hidden var phoneConnected = false;
  hidden var notificationCount = 0;

  hidden var hasBackgroundColorOption = false;

  hidden var doUpdates = 0;
  hidden var activityRunning = false;

  hidden var centerAreaHeight = 0;

  hidden var infoFields = new[NUM_INFO_FIELDS];
  hidden var timeOffsetY;
  hidden var bottomBarHeight;
  hidden var centerRingRadius;

  hidden var settingsNotification;
  hidden var settingsGradePressure;
  hidden var firstLocation = null;

  hidden var hrZoneInfo;
  hidden var currentHrZone;
  hidden var currentHrzColor;

  hidden var gradeBuffer = new[10];
  hidden var gradeBufferPos = 0;
  hidden var gradeBufferSkip = 0;
  hidden var gradePrevData = 0.0;
  hidden var gradePrevDistance = 0.0;
  hidden var gradeFirst = true;
  hidden var centralRingThickness = 2;
  hidden var sunsetType = 0;
  hidden var useHrzColors;

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
    speed = getValue(speed) * 3600 / kmOrMileInMeters;
    InfoValues[speedFieldType] = speed.format("%.1f");

    if (speed >= 1) {
      var pace = (3600 / speed).toLong();
      InfoValues[paceFieldType] = (pace / 60).format("%d") + ":" + (pace % 60).format("%02d");
    } else {
      InfoValues[paceFieldType] = "--:--";
    }
  }

  function getValue(value) {
    if (value == null) {
      value = 0;
    }
    return value;
  }

  function setRingLevel(val, full_val) {
    val = getValue(val).toFloat();
    full_val = getValue(full_val).toFloat();

    if (full_val <= 0) {
      ringFillLevel = -1;
      return;
    }
    ringFillLevel = val / full_val;
  }

  function compute(info) {
    if (!settingsLoaded) {
      return;
    }

    InfoValues[TYPE_DURATION] = formatTime(getValue(info.timerTime) / 1000);

    var daylightAtStart = secondsToSunset(info.currentLocation, info.startTime);
    var daylightRemaining = secondsToSunset(info.currentLocation, Time.now());
    InfoValues[TYPE_DAYLIGHT_REMAINING] = formatTime(daylightRemaining);

    if (InfoValueMapping[INFO_CELL_RING_ARC] == TYPE_DAYLIGHT_REMAINING) {
      setRingLevel(daylightRemaining, daylightAtStart);
    }

    var hr = getValue(info.currentHeartRate);
    InfoValues[TYPE_HR] = hr;
    InfoValues[TYPE_AVG_HR] = getValue(info.averageHeartRate);

    InfoValues[TYPE_BATTERY] = getValue(System.getSystemStats().battery).format("%d");

    var distance = getValue(info.elapsedDistance);
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

    gpsSignal = getValue(info.currentLocationAccuracy);
    InfoValues[TYPE_CADENCE] = getValue(info.currentCadence);
    InfoValues[TYPE_CALORIES] = getValue(info.calories);

    formatSpeed(TYPE_SPEED, TYPE_PACE, info.currentSpeed);
    formatSpeed(TYPE_AVG_SPEED, TYPE_AVG_PACE, info.averageSpeed);

    InfoValues[TYPE_ASCENT] = (getValue(info.totalAscent) * mOrFeetsInMeter).format("%.0f");
    InfoValues[TYPE_DESCENT] = (getValue(info.totalDescent) * mOrFeetsInMeter).format("%.0f");
    var elevation = getValue(info.altitude);

    if (hasAmbientPressure) {
      pressure = getValue(info.ambientPressure);
      InfoValues[TYPE_PRESSURE] = (pressure / 100.0).format("%7.2f");
    }

    var hrZone = 0;

    var zone_max = hrZoneInfo[5];
    if (hr >= zone_max) {
      hr = zone_max;
    }

    for (var i = 6; i > 0; i--) {
      if (hr > hrZoneInfo[i - 1]) {
        hrZone = i;
        break;
      }
    }

    // Special case for zone 0
    var zone_start = hrZoneInfo[0] / 2;
    var zone_range = zone_start;

    if (hrZone > 0) {
      zone_start = hrZoneInfo[hrZone - 1];
      zone_range = hrZoneInfo[hrZone] - zone_start;
    }

    // Offsetting the HRZ color table by light/dark background is more space-efficient than
    // doing a lookup in two arrays. Ideally, we'd just use a pointer to the array we want,
    // but Monkey C lacks such a feature.
    currentHrzColor = hrzColors[hrZone + ((backgroundColor == Graphics.COLOR_BLACK) ? NUM_HRZ_COLORS : 0)];

    if (hr >= zone_start) {
      hrZone += (hr.toFloat() - zone_start) / zone_range;
    }

    InfoValues[TYPE_HR_ZONE] = hrZone.format("%.1f");

    currentHrZone = hrZone;

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
      } else {
        stepCount = stepCount + stepCur - stepPrev;
      }
      stepPrev = stepCur;
    }

    InfoValues[TYPE_STEPS] = stepCount;
    InfoValues[TYPE_DAY_STEPS] = getValue(ActivityMonitor.getInfo().steps);
    InfoValues[TYPE_DAY_STEP_GOAL] = getValue(ActivityMonitor.getInfo().stepGoal);

    if (InfoValueMapping[INFO_CELL_RING_ARC] == TYPE_DAY_STEP_GOAL) {
      setRingLevel(ActivityMonitor.getInfo().steps, ActivityMonitor.getInfo().stepGoal);
    }

    InfoValues[TYPE_WEEK_ACT_MIN] = getValue(ActivityMonitor.getInfo().activeMinutesWeek.total);
    InfoValues[TYPE_WEEK_ACT_GOAL] = getValue(ActivityMonitor.getInfo().activeMinutesWeekGoal);

    if (InfoValueMapping[INFO_CELL_RING_ARC] == TYPE_WEEK_ACT_GOAL) {
      setRingLevel(ActivityMonitor.getInfo().activeMinutesWeek.total, ActivityMonitor.getInfo().activeMinutesWeekGoal);
    }

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

      gradeBufferSkip++;
      if (gradeBufferSkip == 5) {
        gradeBufferSkip = 0;

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

    InfoValues[TYPE_ELEVATION] = elevation.format("%.0f");
    InfoValues[TYPE_MAX_ELEVATION] = maxelevation.format("%.0f");

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

  (:elevationUnitsAvailable)
  function loadUnits() {
    if (System.getDeviceSettings().distanceUnits != System.UNIT_METRIC) {
      kmOrMileInMeters = 1609.344;
    }

    if (System.getDeviceSettings().elevationUnits != System.UNIT_METRIC) {
      mOrFeetsInMeter = 3.2808399;
    }
  }

  (:elevationUnitsMissing)
  function loadUnits() {
    // Some devices don't have a user-facing elevation units setting.
    // For these devices, fall back to using the distance units for elevation
    if (System.getDeviceSettings().distanceUnits != System.UNIT_METRIC) {
      kmOrMileInMeters = 1609.344;
      mOrFeetsInMeter = 3.2808399;
    }
  }

  function onLayout(dc) {
    loadUnits();

    var fieldTitles = {
      TYPE_NONE                     => null,
      TYPE_DURATION                 => :duration,
      TYPE_DISTANCE                 => :distance,
      TYPE_DISTANCE_TO_NEXT_POINT   => :distanceNextPoint,
      TYPE_DISTANCE_FROM_START      => :distanceFromStart,
      TYPE_CADENCE                  => :cadence,
      TYPE_SPEED                    => :speed,
      TYPE_PACE                     => :pace,
      TYPE_AVG_SPEED                => :avgSpeed,
      TYPE_AVG_PACE                 => :avgPace,
      TYPE_HR                       => :hr,
      TYPE_HR_ZONE                  => :hrz,
      TYPE_STEPS                    => :steps,
      TYPE_ELEVATION                => :elevation,
      TYPE_MAX_ELEVATION            => :maxElevation,
      TYPE_ASCENT                   => :ascent,
      TYPE_DESCENT                  => :descent,
      TYPE_GRADE                    => :grade,
      TYPE_DAYLIGHT_REMAINING       => :daylight,
      TYPE_CLOCK                    => :clock,
      TYPE_PRESSURE                 => :pressure,
      TYPE_DAY_STEPS                => :day_steps,
      TYPE_DAY_STEP_GOAL            => :day_step_goal,
      TYPE_WEEK_ACT_MIN             => :week_act_min,
      TYPE_WEEK_ACT_GOAL            => :week_act_goal,
      TYPE_CALORIES                 => :calories,
      TYPE_AVG_HR                   => :avg_hr,
      TYPE_BATTERY                  => :battery,
    };

    var shortFieldTitles = {
      TYPE_NONE                     => null,
      TYPE_HR                       => :hr,
      TYPE_HR_ZONE                  => :hrz_center,
      TYPE_GRADE                    => :grade_center,
      TYPE_AVG_HR                   => :avg_hr_center,
      TYPE_BATTERY                  => :battery_center,
    };

    is24Hour = System.getDeviceSettings().is24Hour;

    // clang-format off
    hasBackgroundColorOption = (self has :getBackgroundColor);
    // clang-format on

    var dcHeight = dc.getHeight();
    var dcWidth = dc.getWidth();
    var topBarHeight = dcHeight / 7;
    timeOffsetY = topBarHeight - Graphics.getFontHeight(FONT_TIME) / 2;
    bottomBarHeight = dcHeight / 8;
    centerAreaHeight = dcHeight - topBarHeight - bottomBarHeight;

    // Layout positions for the seven grid items we'll be displaying
    // Each grid item has a header (small font) and a value (large font)
    // In some situations, the header may contain a title; in others, this
    // may be an auxiliary value
    infoFields[INFO_CELL_TOP_LEFT] = new InfoField(dcWidth * 2 / 7, topBarHeight);
    infoFields[INFO_CELL_TOP_RIGHT] = new InfoField(dcWidth - dcWidth * 2 / 7, topBarHeight);
    infoFields[INFO_CELL_MIDDLE_LEFT] = new InfoField(dcWidth * 2 / 11, topBarHeight + centerAreaHeight / 3);
    infoFields[INFO_CELL_MIDDLE_RIGHT] = new InfoField(dcWidth - dcWidth * 2 / 11, topBarHeight + centerAreaHeight / 3);
    infoFields[INFO_CELL_CENTER] = new InfoField(dcWidth / 2, topBarHeight + centerAreaHeight / 3);
    infoFields[INFO_CELL_BOTTOM_LEFT] = new InfoField(dcWidth / 3.5, topBarHeight + centerAreaHeight / 3 * 2);
    infoFields[INFO_CELL_BOTTOM_RIGHT] = new InfoField(dcWidth - dcWidth / 3.5, topBarHeight + centerAreaHeight / 3 * 2);

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
        var mapping = fieldTitles;

        // The center cell uses shorter field titles than the rest
        if (i == INFO_CELL_CENTER) {
          mapping = shortFieldTitles;
        }

        var res = mapping.get(valueMapping);
        if (headerMapping == TYPE_NONE && res != null) {
          infoFields[i].headerStr = Ui.loadResource(Rez.Strings[res]);
        }
      }
    }

    centralRingThickness = app.getProperty("CRT");  // centralRingThickness
    sunsetType = app.getProperty("SST");  // sunsetType
    fontValue = valueFontTypes[app.getProperty("FT")];  // valueFontType
    settingsNotification = Application.getApp().getProperty("SN");    // showNotifications
    settingsGradePressure = Application.getApp().getProperty("SGP");  // showGridPressure

    // Default radius, if arc indicator is OFF (but there's a data item in the center cell)
    // alwaysDrawCentralRing
    centerRingRadius = app.getProperty("ADCR") ? dcHeight / 8 : 0;

    useHrzColors = app.getProperty("HC");  // Heart rate colors

    // If arc indicator is enabled, force-enable the central ring and enlarge the radius
    if (InfoValueMapping[INFO_CELL_RING_ARC] != TYPE_NONE) {
      centerRingRadius = dcHeight / 7.3;
    } else {
      // Hide the central ring if there's nothing mapped to it
      if (InfoHeaderMapping[INFO_CELL_CENTER] == TYPE_NONE && InfoValueMapping[INFO_CELL_CENTER] == TYPE_NONE) {
        centerRingRadius = 0;
      }
    }

    settingsLoaded = true;
  }

  function onShow() { doUpdates = true; }

  function onHide() { doUpdates = false; }

  function secondsToSunset(position, to_moment) {
    if (position == null || to_moment == null) {
      return 0;
    }

    var location = position.toRadians();

    if (location == null) {
      return 0;
    }

    var now = Time.now().value();

    if (sunriseUtc == null) {
      sunriseUtc = sunCalc.calculate(now, location, SUNRISE);
    }

    if (sunsetUtc == null) {
      sunsetUtc = sunCalc.calculate(now, location, sunsetTypes[sunsetType]);
    }

    if (sunriseUtc == null || sunsetUtc == null) {
      return 0;
    }

    to_moment = to_moment.value();

    var sec_until_sunrise = sunriseUtc - to_moment;
    var sec_until_sunset = sunsetUtc - to_moment;

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
        } else {
          textColor = Graphics.COLOR_BLACK;
          batteryColor1 = Graphics.COLOR_GREEN;
          hrColor = Graphics.COLOR_RED;
          headerColor = Graphics.COLOR_DK_GRAY;
          gridColor = Graphics.COLOR_LT_GRAY;
        }
      }
    }

    var dcWidth = dc.getWidth();
    var dcHeight = dc.getHeight();
    var centerX = dcWidth / 2;
    var topBarHeight = dcHeight / 7;

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

    var centerY = topBarHeight + centerAreaHeight / 2;

    // Draw central ring, if present
    if (centerRingRadius > 0) {
      dc.setColor(backgroundColor, backgroundColor);
      dc.fillCircle(centerX, centerY, centerRingRadius);

      dc.setColor(gridColor, Graphics.COLOR_TRANSPARENT);
      dc.drawCircle(centerX, centerY, centerRingRadius + 1);
    }

    dc.setPenWidth(1);

    var cellHeaderOffset = dcHeight / 19;
    var cellValueOffset = dcHeight / 6;

    // Draw each info cell
    for (var i = 0; i < NUM_INFO_FIELDS; i++) {
      var valueStr = null;

      if (InfoHeaderMapping[i] != TYPE_NONE) {
        infoFields[i].headerStr = InfoValues[InfoHeaderMapping[i]];
      }

      if (InfoValueMapping[i] != TYPE_NONE) {
        valueStr = InfoValues[InfoValueMapping[i]];
      }

      // TODO: Get rid of this when we add themes / custom colors
      var valColor = textColor;
      if (InfoValueMapping[i] == TYPE_HR) {
        valColor = hrColor;

        if (useHrzColors) {
          valColor = currentHrzColor;
        }
      }

      var font = fontValue;

      if (valueStr == null) {
        valueStr = "?";
      }

      if (valueStr.toString().length() > 6) {
        font = Graphics.FONT_SYSTEM_SMALL;
      }

      dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
      dc.drawText(infoFields[i].x, infoFields[i].y + cellHeaderOffset, FONT_HEADER, infoFields[i].headerStr, FONT_JUSTIFY);
      dc.setColor(valColor, Graphics.COLOR_TRANSPARENT);
      dc.drawText(infoFields[i].x, infoFields[i].y + cellValueOffset, font, valueStr, FONT_JUSTIFY);
    }

    dc.setPenWidth(arcThickness[centralRingThickness]);

    var radius = centerRingRadius + 1;

    // Draw central ring. HRZ requires a special case
    if (InfoValueMapping[INFO_CELL_RING_ARC] == TYPE_HR_ZONE) {
      dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);

      for (var i = 0; i < 6 * 48; i += 48) {
        var tick_start = 210 - i;
        dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, tick_start, tick_start - TICK_WIDTH);
      }

      if (currentHrZone >= 1) {
        dc.setColor(currentHrzColor, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 210, 210 - (48 * (currentHrZone - 1)));
      }
    } else if (ringFillLevel > 0) {
      if (ringFillLevel > 1.0) {
        ringFillLevel = 1.0;
      }

      if (ringFillLevel < 0.10) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
      } else if (ringFillLevel < 0.20) {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
      } else {
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
      }

      dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 90, 90 - (360.0 * ringFillLevel));
    }
  }

  function drawBottomBar(dc) {
    var dcWidth = dc.getWidth();
    var dcHeight = dc.getHeight();
    var topBarHeight = dcHeight / 7;
    var bottomBarY = topBarHeight + centerAreaHeight;
    var bottomTextY = bottomBarY + Graphics.getFontHeight(FONT_NOTIFICATIONS) / 2;
    var centerX = dcWidth / 2;

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
    if (Activity != null && Activity.getActivityInfo() != null && Activity.getActivityInfo().startTime != null) {
      Storage.setValue("startTime", Activity.getActivityInfo().startTime.value());
    }

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

  hidden function drawBattery(battery, dc, xStart, yStart, width, height) {
    dc.setColor(batteryBackground, gridColor);
    dc.fillRectangle(xStart, yStart, width, height);

    if (battery < 10) {
      dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
      dc.drawText(xStart + 3 + width / 2, yStart + 7, FONT_HEADER, battery.format("%d") + "%", FONT_JUSTIFY);
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
