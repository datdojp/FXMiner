// Martingale v0.1
#include "Martingale.mqh";
#include "EAConfigUtil.mqh";

enum START_MODE {
    BUY = 1, // Buy
    SELL = 2, // Sell
    WAIT = 3, // Wait
};

input double takeProfitPoints = 150;
input double corridorHeightPoints = 100;
input START_MODE startMode = WAIT;
input double initialLots = 0.1;
input double maxLots = 0.8;
input int slippage = 1;

const int MAGIC = 17090425;

Martingale *martingale;

void init() {
    string alertMessage;
    EAConfigUtil *configUtil = new EAConfigUtil("Martingale");
    double _bottomPrice, _topPrice, _takeProfit, _initialLots, _maxLots;
    Field configs[] = {
        { "bottomPrice", DOUBLE },
        { "topPrice", DOUBLE },
        { "takeProfit", DOUBLE },
        { "initialLots", DOUBLE },
        { "maxLots", DOUBLE }
    };
    if (configUtil.hasConfigs()) {
        configUtil.readConfigs(configs);
        _bottomPrice = configs[0].doubleValue;
        _topPrice = configs[1].doubleValue;
        _takeProfit = configs[2].doubleValue;
        _initialLots = configs[3].doubleValue;
        _maxLots = configs[4].doubleValue;
        alertMessage = "Create Martingale from configs file for " + _Symbol + ": " +
                       "bottomPrice=" + DoubleToString(_bottomPrice) + ", " +
                       "topPrice=" + DoubleToString(_topPrice) + ", " +
                       "takeProfit=" + DoubleToString(_takeProfit) + ", " +
                       "initialLots=" + DoubleToString(_initialLots) + ", " +
                       "maxLots=" + DoubleToString(_maxLots);
    } else {
        if (startMode == BUY) {
            _topPrice = Ask + (slippage + 1) * _Point;
            _bottomPrice = _topPrice - corridorHeightPoints * _Point;
        } else if (startMode == SELL) {
            _bottomPrice = Bid - (slippage + 1) * _Point;
            _topPrice = _bottomPrice + corridorHeightPoints * _Point;
        } else { // startMode == WAIT
            _topPrice = (Ask + Bid) / 2 + corridorHeightPoints * _Point / 2;
            _bottomPrice = (Ask + Bid) / 2 - corridorHeightPoints * _Point / 2;
        }
        _takeProfit = takeProfitPoints * _Point;
        _initialLots = initialLots;
        _maxLots = maxLots;
        configs[0].doubleValue = _bottomPrice;
        configs[1].doubleValue = _topPrice;
        configs[2].doubleValue = _takeProfit;
        configs[3].doubleValue = _initialLots;
        configs[4].doubleValue = _maxLots;
        configUtil.writeConfigs(configs);
        alertMessage = "Create Martingale from inputs for " + _Symbol;
    }

    // create Martingale object
    martingale = new Martingale(_bottomPrice, _topPrice, _takeProfit, _initialLots, _maxLots, MAGIC);
    Alert(alertMessage);
}

void OnTick() {
    martingale.onTick();
    if (martingale.isStopped()) {
        // alert & log
        string reason = "";
        if (martingale.getStopReason() == Martingale::STOP_REASON_CMD_FAILURE) {
            reason = "Command failure";
        } else if (martingale.getStopReason() == Martingale::STOP_REASON_MAX_LOTS_EXCEEDED) {
            reason = "Max Lots exceeded";
        } else if (martingale.getStopReason() == Martingale::STOP_REASON_PROFIT_TAKEN) {
            reason = "Profit taken";
        }
        string message = "Martingale EA of " + _Symbol + " was stopped with reason: " + reason;
        Alert(message);

        // terminal EA
        ExpertRemove();
    }
}

void deinit() {
    if (martingale != NULL) {
        delete martingale;
        martingale = NULL;
    }
}
