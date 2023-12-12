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
    TYPE_NONE,
    TYPE_DURATION,
    TYPE_DISTANCE,
    TYPE_DISTANCE_TO_NEXT_POINT,
    TYPE_DISTANCE_FROM_START,
    TYPE_CADENCE,
    TYPE_SPEED,
    TYPE_PACE,
    TYPE_AVG_SPEED,
    TYPE_AVG_PACE,
    TYPE_HR,
    TYPE_HR_ZONE,
    TYPE_STEPS,
    TYPE_ELEVATION,
    TYPE_MAX_ELEVATION,
    TYPE_ASCENT,
    TYPE_DESCENT,
    TYPE_GRADE,

enum {
    INFO_CELL_TOP_LEFT = 0,
    INFO_CELL_TOP_RIGHT = 1,
    INFO_CELL_MIDDLE_LEFT = 2,
    INFO_CELL_MIDDLE_RIGHT = 3,
    INFO_CELL_CENTER = 4,
    INFO_CELL_BOTTOM_LEFT = 5,
    INFO_CELL_BOTTOM_RIGHT = 6,
    INFO_CELL_RING_ARC = 7,
}

enum {
    STEPS_FIELD_ID = 0,
    STEPS_LAP_FIELD_ID = 1,
}

class HikeField extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new HikeView();
        return [ view ];
    }
}

class InfoField {
    hidden var FONT_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    // Coordinates of top-left of grid entry
    var x = 0;
    var y = 0;

    var headerStyle = "";
    var headerStr = "";
    var valueStr = "";

    // Vertical padding between grid Y and header Y
    hidden var firstRowOffset = 0;

    // Vertical padding between grid Y and value Y
    hidden var secondRowOffset = 0;

    function initialize(dcHeight, x_pos, y_pos) {
        x = x_pos;
        y = y_pos;
        firstRowOffset = dcHeight / 24;
        secondRowOffset = dcHeight / 6;
    }

    function draw(dc, headerColor, valueStyle, valueColor) {
        dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + firstRowOffset, headerStyle, headerStr, FONT_JUSTIFY);
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + secondRowOffset, valueStyle, valueStr, FONT_JUSTIFY);
    }
}

class HikeView extends Ui.DataField {
    hidden var ready = false;

    hidden var FONT_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden var FONT_HEADER_STR = Graphics.FONT_XTINY;
    hidden var FONT_HEADER_VAL = Graphics.FONT_XTINY;
    hidden var FONT_VALUE = Graphics.FONT_NUMBER_MILD;
    const NUM_INFO_FIELDS = 7;

    var totalStepsField;
    var lapStepsField;

    hidden var kmOrMileInMeters = 1000;
    hidden var mOrFeetsInMeter = 1;
    hidden var is24Hour = true;

    //colors
    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var inverseTextColor = Graphics.COLOR_WHITE;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var inverseBackgroundColor = Graphics.COLOR_BLACK;
    hidden var inactiveGpsBackground = Graphics.COLOR_LT_GRAY;
    hidden var batteryBackground = Graphics.COLOR_WHITE;
    hidden var batteryColor1 = Graphics.COLOR_GREEN;
    hidden var hrColor = Graphics.COLOR_RED;
    hidden var headerColor = Graphics.COLOR_DK_GRAY;

    var InfoHeaderMapping = [
        TYPE_NONE,
        TYPE_DISTANCE_FROM_START,
        TYPE_NONE,
        TYPE_NONE,
        TYPE_NONE,
        TYPE_MAX_ELEVATION,
        TYPE_DESCENT
    ];

    var InfoValueMapping = [
        TYPE_DURATION,
        TYPE_DISTANCE,
        TYPE_PACE,
        TYPE_STEPS,
        TYPE_HR,
        TYPE_ELEVATION,
        TYPE_ASCENT
    ];

    //strings
    hidden var timeVal, distVal, distToNextPointVal, distanceFromStartVal, notificationVal, paceVal, avgPaceVal;

    //data
    hidden var elapsedTime= 0;
    hidden var distance = 0;
    hidden var distanceToNextPoint = 0;
    hidden var distanceFromStart = 0;
    hidden var cadence = 0;
    hidden var hr = 0;
    hidden var hrZone = 0;
    hidden var elevation = 0;
    hidden var maxelevation = -65536;
    hidden var speed = 0;
    hidden var avgSpeed = 0;
    hidden var pace = 0;
    hidden var avgPace = 0;
    hidden var ascent = 0;
    hidden var descent = 0;
    hidden var grade = 0;
    hidden var pressure = 0;
    hidden var gpsSignal = 0;
    hidden var stepPrev = 0;
    hidden var stepCount = 0;
    hidden var stepPrevLap = 0;
    hidden var stepsPerLap = [];
    hidden var startTime = [];
    hidden var stepsAddedToField = 0;

    hidden var hasDistanceToNextPoint = false;
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

    hidden var infoFields = new [NUM_INFO_FIELDS];
    hidden var timeOffsetY;
    hidden var topBarHeight;
    hidden var bottomBarHeight;
    hidden var bottomOffset;

    hidden var settingsUnlockCode = Application.getApp().getProperty("unlockCode");
    hidden var settingsShowCadence = Application.getApp().getProperty("showCadence");
    hidden var settingsShowHR = Application.getApp().getProperty("showHR");
    hidden var settingsShowHRZone = Application.getApp().getProperty("showHRZone");
    hidden var settingsMaxElevation = Application.getApp().getProperty("showMaxElevation");
    hidden var settingsNotification = Application.getApp().getProperty("showNotification");
    hidden var settingsGrade = Application.getApp().getProperty("showGrade");
    hidden var settingsGradePressure = Application.getApp().getProperty("showGradePressure");
    hidden var settingsDistanceToNextPoint = Application.getApp().getProperty("showDistanceToNextPoint");
    hidden var settingsShowPace = Application.getApp().getProperty("showPace");
    hidden var settingsShowAvgSpeed = Application.getApp().getProperty("showAvgSpeed");
    hidden var firstLocation = null;

    hidden var hrZoneInfo;

    hidden var gradeBuffer = new[10];
    hidden var gradeBufferPos = 0;
    hidden var gradeBufferSkip = 0;
    hidden var gradePrevData = 0.0;
    hidden var gradePrevDistance = 0.0;
    hidden var gradeFirst = true;


    function initialize() {
        DataField.initialize();

        totalStepsField = createField(
            Ui.loadResource(Rez.Strings.steps_label),
            STEPS_FIELD_ID,
            FitContributor.DATA_TYPE_UINT32,
            {:mesgType=>FitContributor.MESG_TYPE_SESSION , :units=>Ui.loadResource(Rez.Strings.steps_unit)}
        );

        lapStepsField = createField(
            Ui.loadResource(Rez.Strings.steps_label),
            STEPS_LAP_FIELD_ID,
            FitContributor.DATA_TYPE_UINT32,
            {:mesgType=>FitContributor.MESG_TYPE_LAP , :units=>Ui.loadResource(Rez.Strings.steps_unit)}
        );

        Application.getApp().setProperty("uuid", System.getDeviceSettings().uniqueIdentifier);

        hrZoneInfo = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);

        for (var i = 0; i < 10; i++){
            gradeBuffer[i] = null;
        }

        if (Activity.Info has :distanceToNextPoint) {
            hasDistanceToNextPoint = true;
        }

        if (Activity.Info has :ambientPressure) {
            hasAmbientPressure = true;
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

    function compute(info) {
        elapsedTime = info.timerTime != null ? info.timerTime : 0;

        var hours = null;
        var minutes = elapsedTime / 1000 / 60;
        var seconds = elapsedTime / 1000 % 60;

        if (minutes >= 60) {
            hours = minutes / 60;
            minutes = minutes % 60;
        }

        if (hours == null) {
            timeVal = minutes.format("%d") + ":" + seconds.format("%02d");
        } else {
            timeVal = hours.format("%d") + ":" + minutes.format("%02d");
        }

        hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
        distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
        if (hasDistanceToNextPoint) {
            distanceToNextPoint = info.distanceToNextPoint;
        }

        var distanceKmOrMiles = distance / kmOrMileInMeters;
        if (distanceKmOrMiles < 100) {
            distVal = distanceKmOrMiles.format("%.2f");
        } else {
            distVal = distanceKmOrMiles.format("%.1f");
        }

        if (distanceToNextPoint != null) {
            distanceKmOrMiles = distanceToNextPoint / kmOrMileInMeters;
            if (distanceKmOrMiles < 100) {
                distToNextPointVal = distanceKmOrMiles.format("%.2f");
            } else {
                distToNextPointVal = distanceKmOrMiles.format("%.1f");
            }
        }

        distanceFromStart = 0;

        var startLocation = info.startLocation;
        var currentLocation = info.currentLocation;

        if (startLocation == null) {
            if (firstLocation == null) {
                firstLocation = currentLocation;
            }

            startLocation = firstLocation;
        }

        if (startLocation != null && currentLocation != null) {
            distanceFromStart = computeDistance(startLocation, currentLocation);
            distanceKmOrMiles = distanceFromStart / kmOrMileInMeters;
            if (distanceKmOrMiles < 100) {
                distanceFromStartVal = distanceKmOrMiles.format("%.2f");
            } else {
                distanceFromStartVal = distanceKmOrMiles.format("%.1f");
            }
        } else {
            distanceFromStartVal = "---";
        }


        gpsSignal = info.currentLocationAccuracy != null ? info.currentLocationAccuracy : 0;
        cadence = info.currentCadence != null ? info.currentCadence : 0;
        speed = info.currentSpeed != null ? info.currentSpeed : 0;
        avgSpeed = info.averageSpeed != null ? info.averageSpeed : 0;

        speed = speed * 3600 / kmOrMileInMeters;
        if (speed >= 1) {
            pace = (3600 / speed).toLong();
            paceVal = (pace / 60).format("%d") + ":" + (pace % 60).format("%02d");
        } else {
            paceVal = "--:--";
        }

        avgSpeed = avgSpeed * 3600 / kmOrMileInMeters;
        if (avgSpeed >= 1) {
            avgPace = (3600 / avgSpeed).toLong();
            avgPaceVal = (avgPace / 60).format("%d") + ":" + (avgPace % 60).format("%02d");
        } else {
            avgPaceVal = "--:--";
        }

        ascent = info.totalAscent != null ? (info.totalAscent * mOrFeetsInMeter) : 0;
        descent = info.totalDescent != null ? (info.totalDescent * mOrFeetsInMeter)  : 0;
        elevation = info.altitude != null ? info.altitude : 0;
        if (hasAmbientPressure) {
            pressure = info.ambientPressure != null ? info.ambientPressure : 0;
        }

        hrZone = 0;

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

        var mySettings = System.getDeviceSettings();
        phoneConnected = mySettings.phoneConnected;
        if (phoneConnected) {
            notificationCount = mySettings.notificationCount;
        }

        if (settingsGrade && (distance > 0)) {
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

        elevation *= mOrFeetsInMeter;
        if (elevation > maxelevation) {
            maxelevation = elevation;
        }

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

        hasBackgroundColorOption = (self has :getBackgroundColor);

        dcHeight = dc.getHeight();
        dcWidth = dc.getWidth();
        centerX = dcWidth / 2;
        topBarHeight = dcHeight / 7;
        timeOffsetY = 9;
        bottomBarHeight = dcHeight / 8;
        bottomOffset = dcHeight / 8 - 21;
        centerAreaHeight = dcHeight - topBarHeight - bottomBarHeight;

        // Layout positions for the seven grid items we'll be displaying
        // Each grid item has a header (small font) and a value (large font)
        // In some situations, the header may contain a title; in others, this
        // may be an auxiliary value
        infoFields[INFO_CELL_TOP_LEFT]     = new InfoField(dcHeight, dcWidth * 2 / 7, topBarHeight);
        infoFields[INFO_CELL_TOP_RIGHT]    = new InfoField(dcHeight, dcWidth - dcWidth * 2 / 7, topBarHeight);
        infoFields[INFO_CELL_MIDDLE_LEFT]  = new InfoField(dcHeight, dcWidth * 2 / 11, topBarHeight + centerAreaHeight / 3);
        infoFields[INFO_CELL_MIDDLE_RIGHT] = new InfoField(dcHeight, dcWidth - dcWidth * 2 / 11, topBarHeight + centerAreaHeight / 3);
        infoFields[INFO_CELL_CENTER]       = new InfoField(dcHeight, dcWidth / 2, topBarHeight + centerAreaHeight / 3);
        infoFields[INFO_CELL_BOTTOM_LEFT]  = new InfoField(dcHeight, dcWidth / 3.5, topBarHeight + centerAreaHeight / 3 * 2);
        infoFields[INFO_CELL_BOTTOM_RIGHT] = new InfoField(dcHeight, dcWidth - dcWidth / 3.5, topBarHeight + centerAreaHeight / 3 * 2);

        /* Set up headers for fields that don't show data in the header */
        for (var i = 0; i < NUM_INFO_FIELDS; i++) {
            if (InfoHeaderMapping[i] == TYPE_NONE) {
                infoFields[i].headerStyle = FONT_HEADER_STR;
                infoFields[i].headerStr = fieldTitle(InfoValueMapping[i]);
            } else {
                infoFields[i].headerStyle = FONT_HEADER_VAL;
                infoFields[i].headerStr = "?????";
            }
        }

    }

    function onShow() {
        doUpdates = true;
    }

    function onHide() {
        doUpdates = false;
    }

    function onUpdate(dc) {
        if(doUpdates == false) {
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
                } else {
                    textColor = Graphics.COLOR_BLACK;
                    batteryColor1 = Graphics.COLOR_GREEN;
                    hrColor = Graphics.COLOR_RED;
                    headerColor = Graphics.COLOR_DK_GRAY;
                }
            }
        }

        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle(0, 0, dcWidth, dcHeight);

        //time start
        var clockTime = System.getClockTime();
        var time;
        if (is24Hour) {
            time = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
        } else {
            time = Lang.format("$1$:$2$", [computeHour(clockTime.hour), clockTime.min.format("%.2d")]);
            time += (clockTime.hour < 12) ? " am" : " pm";
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, dcWidth, topBarHeight);
        dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, topBarHeight / 2 + timeOffsetY, Graphics.FONT_SMALL, time, FONT_JUSTIFY);
        //time end

        //battery and gps start
        dc.setColor(inverseBackgroundColor, inverseBackgroundColor);
        dc.fillRectangle(0, dcHeight - bottomBarHeight, dcWidth, bottomBarHeight);

        drawBattery(System.getSystemStats().battery, dc, centerX - 50, dcHeight - bottomOffset, 28, 17); //todo

        var xStart = centerX + 24;
        var yStart = dcHeight - bottomOffset - 5;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart - 1, yStart + 11, 8, 10);
        if (gpsSignal < 2) {
            dc.setColor(inactiveGpsBackground, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(xStart, yStart + 12, 6, 8);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 6, yStart + 7, 8, 14);
        if (gpsSignal < 3) {
            dc.setColor(inactiveGpsBackground, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(xStart + 7, yStart + 8, 6, 12);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 13, yStart + 3, 8, 18);
        if (gpsSignal < 4) {
            dc.setColor(inactiveGpsBackground, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(xStart + 14, yStart + 4, 6, 16);
        //battery and gps end

        //notification start
        if (settingsNotification) {
            if (phoneConnected) {
                notificationVal = notificationCount.format("%d");
            } else {
                notificationVal = "-";
            }

            dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, dcHeight - bottomOffset + 5, Graphics.FONT_MEDIUM, notificationVal, FONT_JUSTIFY);
        }
        //notification end

        //grid start
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, topBarHeight, dcWidth, topBarHeight);
        dc.drawLine(0, dcHeight - bottomBarHeight, dcWidth, dcHeight - bottomBarHeight);

        // Vertical line that runs down the center of the screen
        dc.drawLine(centerX, topBarHeight, centerX, dcHeight - bottomBarHeight - 1);

        // Horizontal line 1
        dc.drawLine(0, infoFields[2].y, dcWidth, infoFields[2].y);

        // Horizontal line 2
        dc.drawLine(0, infoFields[5].y, dcWidth, infoFields[5].y);

        if (settingsShowHR) {
            dc.setColor(backgroundColor, backgroundColor);
            dc.fillCircle(centerX, topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 2, dcHeight / 8);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(centerX, topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 2, dcHeight / 8 + 1);
        }

        dc.setPenWidth(1);
        //grid end

        for (var i = 0; i < NUM_INFO_FIELDS; i++) {
            if (InfoHeaderMapping[i] != TYPE_NONE) {
                infoFields[i].headerStr = formatInfo(InfoHeaderMapping[i]);
            }

            if (InfoValueMapping[i] != TYPE_NONE) {
                infoFields[i].valueStr = formatInfo(InfoValueMapping[i]);
            }

            // TODO: Get rid of this when we add themes / custom colors
            var valColor = textColor;
            if (InfoValueMapping[i] == TYPE_HR) {
                valColor = hrColor;
            }

            infoFields[i].draw(dc, headerColor, FONT_VALUE, valColor);
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

    function onTimerPause() {
        activityRunning = false;
    }

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

    function fieldTitle(type) {
        switch (type) {
            case TYPE_NONE:
                return "";

            case TYPE_DURATION:
                return Ui.loadResource(Rez.Strings.duration);

            case TYPE_DISTANCE:
                return Ui.loadResource(Rez.Strings.distance);

            case TYPE_DISTANCE_TO_NEXT_POINT:
                return Ui.loadResource(Rez.Strings.distanceNextPoint);

            case TYPE_DISTANCE_FROM_START:
                return Ui.loadResource(Rez.Strings.distanceFromStart);

            case TYPE_CADENCE:
                return Ui.loadResource(Rez.Strings.cadence);

            case TYPE_SPEED:
                return Ui.loadResource(Rez.Strings.speed);

            case TYPE_PACE:
                return Ui.loadResource(Rez.Strings.pace);

            case TYPE_AVG_SPEED:
                return Ui.loadResource(Rez.Strings.avgSpeed);

            case TYPE_AVG_PACE:
                return Ui.loadResource(Rez.Strings.avgPace);

            case TYPE_HR:
                return Ui.loadResource(Rez.Strings.hr);

            case TYPE_HR_ZONE:
                return Ui.loadResource(Rez.Strings.hrz);

            case TYPE_STEPS:
                return Ui.loadResource(Rez.Strings.steps);

            case TYPE_ELEVATION:
                return Ui.loadResource(Rez.Strings.distance);

            case TYPE_MAX_ELEVATION:
                return Ui.loadResource(Rez.Strings.maxElevation);

            case TYPE_ASCENT:
                return Ui.loadResource(Rez.Strings.ascent);

            case TYPE_DESCENT:
                return Ui.loadResource(Rez.Strings.descent);

            case TYPE_GRADE:
                return Ui.loadResource(Rez.Strings.grade);

            default:
                return "???";
        }
    }

    function formatInfo(type) {
        switch (type) {
            case TYPE_NONE:
                return "";

            case TYPE_DURATION:
                return timeVal;

            case TYPE_DISTANCE:
                return distVal;

            case TYPE_DISTANCE_TO_NEXT_POINT:
                return distToNextPointVal;

            case TYPE_DISTANCE_FROM_START:
                return distanceFromStartVal;

            case TYPE_CADENCE:
                return cadence;

            case TYPE_SPEED:
                return avgSpeed.format("%.1f");

            case TYPE_PACE:
                return paceVal;

            case TYPE_AVG_SPEED:
                return avgSpeed.format("%.1f");

            case TYPE_AVG_PACE:
                return avgPaceVal;

            case TYPE_HR:
                return hr;

            case TYPE_HR_ZONE:
                return hrZone.format("%.1f");

            case TYPE_STEPS:
                return stepCount;

            case TYPE_ELEVATION:
                return elevation.format("%.0f");

            case TYPE_MAX_ELEVATION:
                return maxelevation.format("%.0f");

            case TYPE_ASCENT:
                return ascent.format("%.0f");

            case TYPE_DESCENT:
                return descent.format("%.0f");

            case TYPE_GRADE:
                grade.format("%.1f");

            default:
                return "???";
        }
    }

    function drawBattery(battery, dc, xStart, yStart, width, height) {
        dc.setColor(batteryBackground, inactiveGpsBackground);
        dc.fillRectangle(xStart, yStart, width, height);
        if (battery < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xStart+3 + width / 2, yStart + 7, FONT_HEADER_STR, format("$1$%", [battery.format("%d")]), FONT_JUSTIFY);
        }

        if (battery < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        } else if (battery < 30) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(xStart + 1, yStart + 1, (width-2) * battery / 100, height - 2);

        dc.setColor(batteryBackground, batteryBackground);
        dc.fillRectangle(xStart + width - 1, yStart + 3, 4, height - 6);
    }

    function computeHour(hour) {
        if (hour < 1) {
            return hour + 12;
        }
        if (hour >  12) {
            return hour - 12;
        }
        return hour;
    }
}
