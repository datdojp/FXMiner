// Martingale v0.1
#include "Martingale.mqh";
#include "EAConfigUtil.mqh";

enum START_MODE {
    BUY = 1, // Buy
    SELL = 2, // Sell
    WAIT = 3, // Wait
};

input double TakeProfitPoints = 150;
input double CorridorHeightPoints = 100;
input START_MODE StartMode = WAIT;
input double InitialLots = 0.1;
input double MaxLots = 0.8;
input int slippage = 1;

const int MAGIC = 17090425;

Martingale *martingale;

void init() {
    string alertMessage;
    EAConfigUtil *configUtil = new EAConfigUtil("Martingale");
    double bottomPrice, topPrice, takeProfit, initialLots, maxLots;
    Field configs[] = {
        { "bottomPrice", DOUBLE },
        { "topPrice", DOUBLE },
        { "takeProfit", DOUBLE },
        { "initialLots", DOUBLE },
        { "maxLots", DOUBLE }
    };
    if (configUtil.hasConfigs()) {
        configUtil.readConfigs(configs);
        bottomPrice = configs[0].doubleValue;
        topPrice = configs[1].doubleValue;
        takeProfit = configs[2].doubleValue;
        initialLots = configs[3].doubleValue;
        maxLots = configs[4].doubleValue;
        alertMessage = "Create Martingale from configs file for " + _Symbol + ": " +
                       "bottomPrice=" + DoubleToString(bottomPrice) + ", " +
                       "topPrice=" + DoubleToString(topPrice) + ", " +
                       "takeProfit=" + DoubleToString(takeProfit) + ", " +
                       "initialLots=" + DoubleToString(initialLots) + ", " +
                       "maxLots=" + DoubleToString(maxLots);
    } else {
        if (StartMode == BUY) {
            topPrice = Ask + (slippage + 1) * _Point;
            bottomPrice = topPrice - CorridorHeightPoints * _Point;
        } else if (StartMode == SELL) {
            bottomPrice = Bid - (slippage + 1) * _Point;
            topPrice = bottomPrice + CorridorHeightPoints * _Point;
        } else { // StartMode == WAIT
            topPrice = (Ask + Bid) / 2 + CorridorHeightPoints * _Point / 2;
            bottomPrice = (Ask + Bid) / 2 - CorridorHeightPoints * _Point / 2;
        }
        takeProfit = TakeProfitPoints * _Point;
        initialLots = InitialLots;
        maxLots = MaxLots;
        configs[0].doubleValue = bottomPrice;
        configs[1].doubleValue = topPrice;
        configs[2].doubleValue = takeProfit;
        configs[3].doubleValue = initialLots;
        configs[4].doubleValue = maxLots;
        configUtil.writeConfigs(configs);
        alertMessage = "Create Martingale from inputs for " + _Symbol;
    }

    // create Martingale object
    martingale = new Martingale(bottomPrice, topPrice, takeProfit, initialLots, maxLots, MAGIC);
    Alert(alertMessage);
}

void OnTick() {
    martingale.onTick();
}

void deinit() {
    if (martingale != NULL) {
        delete martingale;
        martingale = NULL;
    }
}
