// Martingale v0.1
#include "Martingale.mqh";

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
    double topPrice, bottomPrice;
    if (startMode == BUY) {
        topPrice = Ask + (slippage + 1) * _Point;
        bottomPrice = topPrice - corridorHeightPoints * _Point;
    } else if (startMode == SELL) {
        bottomPrice = Bid - (slippage + 1) * _Point;
        topPrice = bottomPrice + corridorHeightPoints * _Point;
    } else { // startMode == WAIT
        topPrice = (Ask + Bid) / 2 + corridorHeightPoints * _Point / 2;
        bottomPrice = (Ask + Bid) / 2 - corridorHeightPoints * _Point / 2;
    }
    martingale = new Martingale(bottomPrice, topPrice, takeProfitPoints * _Point, initialLots, MAGIC);

    // alert & log
    string message = "Started martingale for " + _Symbol + " with price range: " + topPrice + " .. " + bottomPrice;
    Alert(message);
    Print(message);
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
        Print(message);

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
