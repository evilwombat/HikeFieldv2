using Toybox.Activity as Activity;
using Toybox.Application as App;
using Toybox.Application.Storage as Storage;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.Timer as Timer;
using Toybox.FitContributor as FitContributor;
using Toybox.UserProfile as UserProfile;

enum {
    TYPE_DURATION,
    TYPE_DISTANCE,
    TYPE_SPEED,
    TYPE_HR,
    TYPE_STEPS,
    TYPE_ELEVATION,
    TYPE_ASCENT,
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

class HikeView extends Ui.DataField {

    hidden const FONT_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    //hidden const FONT_HEADER = Graphics.FONT_XTINY;
    hidden const FONT_HEADER = Ui.loadResource(Rez.Fonts.roboto_20);
    hidden const FONT_VALUE = Graphics.FONT_NUMBER_MILD;
    hidden const FONT_VALUE_SMALLER = FONT_HEADER;
    hidden const ZERO_TIME = "0:00";
    hidden const ZERO_DISTANCE = "0.00";

    hidden const STEPS_FIELD_ID = 0;
    hidden const STEPS_LAP_FIELD_ID = 1;

    var totalStepsField;
    var lapStepsField;

    hidden var kmOrMileInMeters = 1000;
    hidden var mOrFeetsInMeter = 1;
    hidden var is24Hour = true;

    //colors
    hidden var distanceUnits = System.UNIT_METRIC;
    hidden var elevationUnits = System.UNIT_METRIC;
    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var inverseTextColor = Graphics.COLOR_WHITE;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var inverseBackgroundColor = Graphics.COLOR_BLACK;
    hidden var inactiveGpsBackground = Graphics.COLOR_LT_GRAY;
    hidden var batteryBackground = Graphics.COLOR_WHITE;
    hidden var batteryColor1 = Graphics.COLOR_GREEN;
    hidden var hrColor = Graphics.COLOR_RED;
    hidden var headerColor = Graphics.COLOR_DK_GRAY;

    //strings
    hidden var durationStr, distanceStr, cadenceStr, hrStr, stepsStr, speedStr, elevationStr, ascentStr, notificationStr;

    //data
    hidden var elapsedTime= 0;
    hidden var distance = 0;
    hidden var cadence = 0;
    hidden var hr = 0;
    hidden var hrZone = 0;
    hidden var elevation = 0;
    hidden var maxelevation = -65536;
    hidden var speed = 0;
    hidden var ascent = 0;
    hidden var descent = 0;
    hidden var gpsSignal = 0;
    hidden var stepPrev = 0;
    hidden var stepCount = 0;
    hidden var stepPrevLap = 0;
    hidden var stepsPerLap = [];
    hidden var startTime = [];
    hidden var stepsAddedToField = 0;

    hidden var checkStorage = false;

    hidden var phoneConnected = false;
    hidden var notificationCount = 0;

    hidden var hasBackgroundColorOption = false;

    hidden var doUpdates = 0;
    hidden var activityRunning = false;

    hidden var dcWidth = 0;
    hidden var dcHeight = 0;

    hidden var points = new [21];
    hidden var topBarHeight;
    hidden var bottomBarHeight;
    hidden var firstRowOffset;
    hidden var secondRowOffset;
    hidden var lineUp;
    hidden var lineUpSides;
    hidden var lineDown;
    hidden var lineDownSides;

    hidden var settingsUnlockCode = Application.getApp().getProperty("unlockCode");
    hidden var settingsShowCadence = Application.getApp().getProperty("showCadence");
    hidden var settingsShowHR = Application.getApp().getProperty("showHR");
    hidden var settingsShowHRZone = Application.getApp().getProperty("showHRZone");
    hidden var settingsMaxElevation = Application.getApp().getProperty("showMaxElevation");
    hidden var settingsNotification = Application.getApp().getProperty("showNotification");
    hidden var settingsAvaiable = false;

    hidden var hrZoneInfo;

    function hex2int(ch)
    {
        if (ch >= '0' && ch <= '9') {
            return ch.toNumber() - '0'.toNumber();
        }
        if (ch >= 'A' && ch <= 'F') {
            return ch.toNumber() - 'A'.toNumber() + 10;
        }
        if (ch >= 'a' && ch <= 'f') {
            return ch.toNumber() - 'a'.toNumber() + 10;
        }
        return -1;
    }

    function checkUnlockCode(code) {
        code = code.toCharArray();
        var uuid = System.getDeviceSettings().uniqueIdentifier.toCharArray();
        var secret = "jtymejczykgarminasia".toCharArray();
        var calculated = new [uuid.size() / 2];
        var code_provided = new [code.size() / 2];
        var correct = true;

        if (code.size() != 20) {
            return false;
        }

        for (var i = 0; i < code.size(); i += 2) {
            code_provided[i / 2] = hex2int(code[i]) * 16 + hex2int(code[i + 1]);
        }

        for (var i = 0; i < uuid.size(); i += 2) {
            calculated[i / 2] = hex2int(uuid[i]) * 16 + hex2int(uuid[i + 1]);
        }

        for (var i = 0; i < calculated.size(); i += 1) {
            calculated[i] = calculated[i] ^ secret[i].toNumber();
        }

        for (var i = 0; i < calculated.size() / 2; i += 1) {
            calculated[i] = calculated[i] ^ calculated[i + 10];
        }

        for (var i = 0; i < code_provided.size(); i += 1) {
            if (calculated[i] != code_provided[i]) {
                correct = false;
                break;
            }
        }

        return correct;
    }

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

        if (checkUnlockCode(settingsUnlockCode)) {
            settingsAvaiable = true;
        }

        hrZoneInfo = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
    }

    function calculateHRZone(hr) {
        var zone = 0;

        for (var i = hrZoneInfo.size(); i > 0; i--) {
            if (hr > hrZoneInfo[i - 1]) {
                zone = i;
                break;
            }
        }

        if (zone == 0) {
            zone = 0;
        } else if (zone == 6) {
            zone = 5;
        } else {
            var diff = 0;
            diff = hrZoneInfo[zone] - hrZoneInfo[zone - 1];
            diff = (hr.toFloat() - hrZoneInfo[zone - 1]) / diff;
            zone = zone + diff - 1;
        }

        return zone;
    }

    function compute(info) {
        elapsedTime = info.timerTime != null ? info.timerTime : 0;
        hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
        hrZone = calculateHRZone(hr);
        distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
        gpsSignal = info.currentLocationAccuracy != null ? info.currentLocationAccuracy : 0;
        cadence = info.currentCadence != null ? info.currentCadence : 0;
        speed = info.currentSpeed != null ? info.currentSpeed : 0;
        ascent = info.totalAscent != null ? info.totalAscent : 0;
        descent = info.totalDescent != null ? info.totalDescent : 0;
        elevation = info.altitude != null ? info.altitude : 0;

        if (stepsAddedToField < stepsPerLap.size() * 2) {
            if (stepsAddedToField & 0x1) {
                lapStepsField.setData(stepsPerLap[stepsAddedToField / 2]);
            }
            stepsAddedToField++;
        }

        if (activityRunning) {
            if (checkStorage && Activity.getActivityInfo().startTime != null) {
                checkStorage = false;
                checkValues();
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

        if (elevation > maxelevation) {
            maxelevation = elevation;
        }
		
		var mySettings = System.getDeviceSettings();
        phoneConnected = mySettings.phoneConnected;
        if (phoneConnected) {
            notificationCount = mySettings.notificationCount;
        }
    }

    function onLayout(dc) {
        setDeviceSettingsDependentVariables();
        dcHeight = dc.getHeight();
        dcWidth = dc.getWidth();
        topBarHeight = 30;
        bottomBarHeight = 42;
        firstRowOffset = 10;
        secondRowOffset = 38 - (240 - dcHeight) / 4;
        lineUpSides = 15 + (240 - dcWidth) / 4;
        lineDownSides = 15 + (240 - dcWidth) / 3;

        points[0] = 69 - (240 - dcWidth) / 2;
        points[1] = topBarHeight + firstRowOffset;
        points[2] = topBarHeight + secondRowOffset;

        points[3] = dcWidth - 69 + (240 - dcWidth) / 2;
        points[4] = topBarHeight + firstRowOffset;
        points[5] = topBarHeight + secondRowOffset;

        points[6] = 44 - (240 - dcWidth) / 2;
        points[7] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 + firstRowOffset;
        points[8] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 + secondRowOffset;

        points[9] = dcWidth - 44 + (240 - dcWidth) / 2;
        points[10] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 + firstRowOffset;
        points[11] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 + secondRowOffset;

        points[12] = dcWidth / 2;
        points[13] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 + firstRowOffset;
        points[14] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 + secondRowOffset;

        points[15] = 65 - (240 - dcWidth) / 2;
        points[16] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 * 2 + firstRowOffset;
        points[17] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 * 2 + secondRowOffset;

        points[18] = dcWidth - 65 + (240 - dcWidth) / 2;
        points[19] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 * 2 + firstRowOffset;
        points[20] = topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 3 * 2 + secondRowOffset;
    }

    function onShow() {
        doUpdates = true;
        return true;
    }

    function onHide() {
        doUpdates = false;
    }

    function onUpdate(dc) {
        if(doUpdates == false) {
            return;
        }

        setColors();
        dc.clear();
        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle(0, 0, dcWidth, dcHeight);

        drawValues(dc);
    }

    function checkValues() {
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

    function setDeviceSettingsDependentVariables() {
        hasBackgroundColorOption = (self has :getBackgroundColor);

        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits == System.UNIT_METRIC) {
            kmOrMileInMeters = 1000;
        } else {
            kmOrMileInMeters = 1609.344;
        }

        elevationUnits = System.getDeviceSettings().elevationUnits;
        if (elevationUnits == System.UNIT_METRIC) {
            mOrFeetsInMeter = 1;
        } else {
            mOrFeetsInMeter = 3.2808399;
        }
        is24Hour = System.getDeviceSettings().is24Hour;

        hrStr = Ui.loadResource(Rez.Strings.hr);
        distanceStr = Ui.loadResource(Rez.Strings.distance);
        durationStr = Ui.loadResource(Rez.Strings.duration);
        cadenceStr = Ui.loadResource(Rez.Strings.cadence);
        stepsStr = Ui.loadResource(Rez.Strings.steps);
        speedStr = Ui.loadResource(Rez.Strings.speed);
        elevationStr = Ui.loadResource(Rez.Strings.elevation);
    }

    function setColors() {
        if (hasBackgroundColorOption) {
            backgroundColor = getBackgroundColor();
            textColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            inverseTextColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_WHITE;
            inverseBackgroundColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLACK: Graphics.COLOR_BLACK;
            hrColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLUE : Graphics.COLOR_RED;
            headerColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY: Graphics.COLOR_DK_GRAY;
            batteryColor1 = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_GREEN;
        }
    }

    function drawTime(dc) {
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
        dc.drawText(dcWidth / 2, topBarHeight / 2, Graphics.FONT_MEDIUM, time, FONT_JUSTIFY);
    }

    function drawBatteryAndGPS(dc) {
        dc.setColor(inverseBackgroundColor, inverseBackgroundColor);
        dc.fillRectangle(0, dcHeight - bottomBarHeight, dcWidth, bottomBarHeight);

        drawBattery(System.getSystemStats().battery, dc, dcWidth / 2 - 50, dcHeight - 32, 28, 17); //todo

        if (gpsSignal < 2) {
            drawGpsSign(dc, dcWidth / 2 + 24, dcHeight - 35, inactiveGpsBackground, inactiveGpsBackground, inactiveGpsBackground); //todo
        } else if (gpsSignal == 2) {
            drawGpsSign(dc, dcWidth / 2 + 24, dcHeight - 35, batteryColor1, inactiveGpsBackground, inactiveGpsBackground);
        } else if (gpsSignal == 3) {
            drawGpsSign(dc, dcWidth / 2 + 24, dcHeight - 35, batteryColor1, batteryColor1, inactiveGpsBackground);
        } else {
            drawGpsSign(dc, dcWidth / 2 + 24, dcHeight - 35, batteryColor1, batteryColor1, batteryColor1);
        }
    }

    function drawNotifications(dc) {
        if (!(settingsAvaiable && !settingsNotification)) {
            if (phoneConnected) {
                notificationStr = notificationCount.format("%d");
            } else {
                notificationStr = "-";
            }

            dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dcWidth / 2, dcHeight - 25, Graphics.FONT_MEDIUM, notificationStr, FONT_JUSTIFY);
        }
    }

    function drawGrid(dc) {
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, topBarHeight, dcWidth, topBarHeight);
        dc.drawLine(0, dcHeight - bottomBarHeight, dcWidth, dcHeight - bottomBarHeight);
        dc.drawLine(0, points[3 * 2 + 1] - firstRowOffset, dcWidth / 2 - lineUpSides, points[3 * 2 + 1] - firstRowOffset);
        dc.drawLine(dcWidth, points[3 * 2 + 1]  - firstRowOffset, dcWidth / 2 + lineUpSides, points[3 * 2 + 1] - firstRowOffset);
        dc.drawLine(0, points[3 * 5 + 1]  - firstRowOffset, dcWidth / 2 - lineDownSides, points[3 * 5 + 1] - firstRowOffset);
        dc.drawLine(dcWidth, points[3 * 5 + 1] - firstRowOffset, dcWidth / 2 + lineDownSides, points[3 * 5 + 1] - firstRowOffset);
        dc.drawLine(dcWidth / 2, topBarHeight, dcWidth / 2, topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 2 - 32);
        dc.drawLine(dcWidth / 2, dcHeight - bottomBarHeight - 1, dcWidth / 2, topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 2 + 32);

        if (!(settingsAvaiable && !settingsShowHR)) {
            dc.drawCircle(dcWidth / 2, topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 2, 32);
        } else {
            dc.drawLine(dcWidth / 2 - lineUpSides, points[3 * 2 + 1] - firstRowOffset, dcWidth / 2 + lineUpSides, points[3 * 2 + 1] - firstRowOffset);
            dc.drawLine(dcWidth / 2 - lineUpSides, points[3 * 5 + 1] - firstRowOffset, dcWidth / 2 + lineUpSides, points[3 * 5 + 1] - firstRowOffset);
            dc.drawLine(dcWidth / 2, topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 2 - 32, dcWidth / 2, topBarHeight + (dcHeight - topBarHeight - bottomBarHeight) / 2 + 32);
        }

        dc.setPenWidth(1);
    }

    function drawInfo(dc, field, type) {
        var text_line_1 = "";
        var text_line_2 = "";

        switch (type) {
            case TYPE_DURATION:
                var duration;
                if (elapsedTime != null && elapsedTime > 0) {
                    var hours = null;
                    var minutes = elapsedTime / 1000 / 60;
                    var seconds = elapsedTime / 1000 % 60;

                    if (minutes >= 60) {
                        hours = minutes / 60;
                        minutes = minutes % 60;
                    }

                    if (hours == null) {
                        duration = minutes.format("%d") + ":" + seconds.format("%02d");
                    } else {
                        duration = hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
                    }
                } else {
                    duration = ZERO_TIME;
                }
                text_line_1 = durationStr;
                text_line_2 = duration;
                break;
            case TYPE_DISTANCE:
                var distStr;
                if (distance > 0) {
                    var distanceKmOrMiles = distance / kmOrMileInMeters;
                    if (distanceKmOrMiles < 100) {
                        distStr = distanceKmOrMiles.format("%.2f");
                    } else {
                        distStr = distanceKmOrMiles.format("%.1f");
                    }
                } else {
                    distStr = ZERO_DISTANCE;
                }
                text_line_1 = distanceStr;
                text_line_2 = distStr;
                break;
            case TYPE_SPEED:
                speed = speed * 3600 / kmOrMileInMeters;
                if (!(settingsAvaiable && !settingsShowCadence)) {
                    text_line_1 = cadence;
                } else {
                    text_line_1 = speedStr;
                }
                text_line_2 = speed.format("%.1f");
                break;
            case TYPE_HR:
                if (!(settingsAvaiable && !settingsShowHR)) {
                    if (settingsAvaiable && settingsShowHRZone) {
                        dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
                        dc.drawText(points[3 * 4], points[3 * 4 + 1], FONT_HEADER, hrStr, FONT_JUSTIFY);
                        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
                        dc.drawText(points[3 * 4], points[3 * 4 + 2], FONT_VALUE, hrZone.format("%.1f"), FONT_JUSTIFY);
                    } else {
                        dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
                        dc.drawText(points[3 * 4], points[3 * 4 + 1], FONT_HEADER, hrStr, FONT_JUSTIFY);
                        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
                        dc.drawText(points[3 * 4], points[3 * 4 + 2], FONT_VALUE, hr.format("%d"), FONT_JUSTIFY);
                    }
                }
                return;
                break;
            case TYPE_STEPS:
                text_line_1 = stepsStr;
                text_line_2 = stepCount;
                break;
            case TYPE_ELEVATION:
                var elevationmOrFeets = elevation * mOrFeetsInMeter;
                if (!(settingsAvaiable && !settingsMaxElevation)) {
                    var maxelevationmOrFeets = maxelevation * mOrFeetsInMeter;
                    text_line_1 = maxelevationmOrFeets.format("%.0f");
                } else {
                    text_line_1 = elevationStr;
                }
                text_line_2 = elevationmOrFeets.format("%.0f");
                break;
            case TYPE_ASCENT:
                var descentnmOrFeets = descent * mOrFeetsInMeter;
                var ascentnmOrFeets = ascent * mOrFeetsInMeter;
                text_line_1 = descentnmOrFeets.format("%.0f");
                text_line_2 = ascentnmOrFeets.format("%.0f");
                break;
            default:
                return;
                break;
        }

        dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(points[3 * field], points[3 * field + 1], FONT_HEADER, text_line_1, FONT_JUSTIFY);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(points[3 * field], points[3 * field + 2], FONT_VALUE, text_line_2, FONT_JUSTIFY);
    }

    function drawValues(dc) {

        drawTime(dc);
        drawBatteryAndGPS(dc);
        drawNotifications(dc);
        drawGrid(dc);

        drawInfo(dc, 0, TYPE_DURATION);
        drawInfo(dc, 1, TYPE_DISTANCE);
        drawInfo(dc, 2, TYPE_SPEED);
        drawInfo(dc, 3, TYPE_STEPS);
        drawInfo(dc, 4, TYPE_HR);
        drawInfo(dc, 5, TYPE_ELEVATION);
        drawInfo(dc, 6, TYPE_ASCENT);
    }

    function drawBattery(battery, dc, xStart, yStart, width, height) {
        dc.setColor(batteryBackground, inactiveGpsBackground);
        dc.fillRectangle(xStart, yStart, width, height);
        if (battery < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xStart+3 + width / 2, yStart + 7, FONT_HEADER, format("$1$%", [battery.format("%d")]), FONT_JUSTIFY);
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

    function drawGpsSign(dc, xStart, yStart, color1, color2, color3) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart - 1, yStart + 11, 8, 10);
        dc.setColor(color1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart, yStart + 12, 6, 8);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 6, yStart + 7, 8, 14);
        dc.setColor(color2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart + 7, yStart + 8, 6, 12);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart + 13, yStart + 3, 8, 18);
        dc.setColor(color3, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xStart + 14, yStart + 4, 6, 16);
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
