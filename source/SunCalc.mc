using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Position as Pos;

class SunCalc {
    hidden const PI   = Math.PI,
        RAD  = Math.PI / 180.0,
        PI2  = Math.PI * 2.0,
        DAYS = Time.Gregorian.SECONDS_PER_DAY,
        J1970 = 2440588,
        J2000 = 2451545,
        J0 = 0.0009;

    hidden const TIMES = [
        -18 * RAD,    // ASTRO_DAWN
        -12 * RAD,    // NAUTIC_DAWN
        -6 * RAD,     // DAWN
        -4 * RAD,     // BLUE_HOUR
        -0.833 * RAD, // SUNRISE
        -0.3 * RAD,   // SUNRISE_END
        6 * RAD,      // GOLDEN_HOUR_AM
        null,         // NOON
        6 * RAD,      // GOLDEN_HOUR_PM
        -0.3 * RAD,   // SUNSET_START
        -0.833 * RAD, // SUNSET
        -4 * RAD,     // BLUE_HOUR_PM
        -6 * RAD,     // DUSK
        -12 * RAD,    // NAUTIC_DUSK
        -18 * RAD     // ASTRO_DUSK
        ];


    function initialize() {
    }

    function fromJulian(j) {
        return ((j + 0.5 - J1970) * DAYS).toNumber();
    }

    function round(a) {
        if (a > 0) {
            return (a + 0.5).toNumber().toFloat();
        } else {
            return (a - 0.5).toNumber().toFloat();
        }
    }

    // lat and lng in radians
    function calculate(current_time, pos, what) {
        var	n, ds, M, sinM, C, L, sin2L, dec, Jnoon;
        var lat = pos[0].toDouble();
        var lng = pos[1].toDouble();
        var d = current_time.toDouble() / DAYS - 0.5 + J1970 - J2000;
        n = round(d - J0 + lng / PI2);
//      ds = J0 - lng / PI2 + n;
        ds = J0 - lng / PI2 + n - 1.1574e-5 * 68;
        M = 6.240059967 + 0.0172019715 * ds;
        sinM = Math.sin(M);
        C = (1.9148 * sinM + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M)) * RAD;
        L = M + C + 1.796593063 + PI;
        sin2L = Math.sin(2 * L);
        dec = Math.asin( 0.397783703 * Math.sin(L) );
        Jnoon = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;

        if (what == NOON) {
            return fromJulian(Jnoon);
        }

        var x = (Math.sin(TIMES[what]) - Math.sin(lat) * Math.sin(dec)) / (Math.cos(lat) * Math.cos(dec));

        if (x > 1.0 || x < -1.0) {
            return null;
        }

        ds = J0 + (Math.acos(x) - lng) / PI2 + n - 1.1574e-5 * 68;

        var Jset = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;
        if (what > NOON) {
            return fromJulian(Jset);
        }

        var Jrise = Jnoon - (Jset - Jnoon);

        return fromJulian(Jrise);
    }
}
