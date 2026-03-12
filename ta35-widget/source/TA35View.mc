import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;

class TA35View extends WatchUi.View {

    // State
    private var _changePercent as Float = 0.0;
    private var _status as String = "Loading...";  // "loading", "ok", "error", "closed"
    private var _lastUpdate as String = "--:--";
    private var _timer as Timer.Timer?;

    // Refresh interval: 5 minutes in milliseconds
    private const REFRESH_MS = 5 * 60 * 1000;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    function onShow() as Void {
        // Fetch immediately on show
        fetchData();
        // Start periodic timer
        _timer = new Timer.Timer();
        _timer.start(method(:fetchData), REFRESH_MS, true);
    }

    function onHide() as Void {
        stopTimer();
    }

    function stopTimer() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    // ── HTTP fetch ──────────────────────────────────────────────────────────

    function fetchData() as Void {
        var url = "https://query1.finance.yahoo.com/v8/finance/chart/TA35.TA?interval=1d&range=1d";
        var options = {
            :method  => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "User-Agent" => "Mozilla/5.0",
                "Accept"     => "application/json"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, null, options, method(:onReceive));
    }

    function onReceive(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode == 200 && data != null) {
            parseData(data);
        } else if (responseCode == -1) {
            _status = "No Signal";
        } else {
            _status = "Error " + responseCode;
        }
        WatchUi.requestUpdate();
    }

    function parseData(data as Dictionary) as Void {
        try {
            var chart  = data["chart"]    as Dictionary;
            var result = chart["result"]  as Array;

            if (result == null || result.size() == 0) {
                _status = "Closed";
                return;
            }

            var meta           = result[0]["meta"] as Dictionary;
            var pct            = meta["regularMarketChangePercent"] as Float?;
            var marketState    = meta["marketState"] as String?;

            if (pct == null) {
                _status = "Closed";
                return;
            }

            // Market may be pre/post/closed – still show last pct but mark closed
            _changePercent = pct.toFloat();

            if (marketState != null && !marketState.equals("REGULAR")) {
                _status = "closed";
            } else {
                _status = "ok";
            }

            // Update timestamp
            var now    = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var hour   = now.hour.format("%02d");
            var minute = now.min.format("%02d");
            _lastUpdate = hour + ":" + minute;

        } catch (ex instanceof Lang.Exception) {
            _status = "Parse Err";
        }
    }

    // ── Rendering ───────────────────────────────────────────────────────────

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Background
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Title ──
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h * 0.18,
            Graphics.FONT_SMALL,
            "TA-35",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // ── Main content ──
        if (_status.equals("loading") || _status.equals("Loading...") || _status.equals("No Signal")) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_MEDIUM, _status, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        } else if (_status.equals("ok") || _status.equals("closed")) {
            // Choose color
            var color;
            if (_changePercent > 0) {
                color = Graphics.COLOR_GREEN;
            } else if (_changePercent < 0) {
                color = Graphics.COLOR_RED;
            } else {
                color = Graphics.COLOR_WHITE;
            }

            // Format percentage string
            var pctStr = formatPercent(_changePercent);

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2,
                h / 2,
                Graphics.FONT_NUMBER_THAI_HOT,
                pctStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            // "Market Closed" note
            if (_status.equals("closed")) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    w / 2,
                    h * 0.72,
                    Graphics.FONT_XTINY,
                    "Market Closed",
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }

        } else {
            // Error state
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, _status, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── Timestamp at bottom ──
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h * 0.85,
            Graphics.FONT_XTINY,
            _lastUpdate,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    function formatPercent(pct as Float) as String {
        var sign   = pct >= 0 ? "+" : "";
        // Format to 2 decimal places manually
        var abs    = pct < 0 ? -pct : pct;
        var whole  = abs.toNumber();
        var frac   = ((abs - whole) * 100).toNumber();
        return sign + (pct < 0 ? "-" : "") + whole.toString() + "." + frac.format("%02d") + "%";
    }
}
