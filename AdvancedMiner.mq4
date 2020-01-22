#include "lib.mqh";

const string inputSymbol = "USDJPY";
const double inputLots = 0.02;
const double inputDistance = 100 * MarketInfo(inputSymbol, MODE_POINT);
const double inputTakeProfit = 100 * MarketInfo(inputSymbol, MODE_POINT);
const int inputCommand = OP_BUY;
const int inputMagic = 4891804;
const int inputSlippage = 1;

const int inputHeikinAshiTimeFrame = PERIOD_H1;

const int inputATRTimeFrame = PERIOD_H1;

MinerConfig minerConfig = {};

void init() {
    minerConfig.symbol = inputSymbol;
    minerConfig.lots = inputLots;
    minerConfig.distance = inputDistance;
    minerConfig.takeProfit = inputTakeProfit;
    minerConfig.command = inputCommand;
    minerConfig.magic = inputMagic;
    minerConfig.slippage = inputSlippage;
    minerConfig.shouldSetTrailingStop = false;
    minerConfig.trailingStopMinDistance = 30 * MarketInfo(inputSymbol, MODE_POINT);
    minerConfig.trailingStopBuffer = 10 * MarketInfo(inputSymbol, MODE_POINT);
}

void OnTick() {
    // use ATR to determine distance and takeprofit
    const double atr = iATR(inputSymbol, inputATRTimeFrame, 14, 0);
    minerConfig.distance = NormalizeDouble(atr, MarketInfo(inputSymbol, MODE_DIGITS));
    minerConfig.takeProfit = NormalizeDouble(atr, MarketInfo(inputSymbol, MODE_DIGITS));

    // use heikinashi to check if we should create new order
    HeikinAshiBar bars[] = {};
    getHeikinAshiBars(inputSymbol, inputHeikinAshiTimeFrame, 10, bars);
    minerConfig.shouldCreateOrder = shouldCreateOrder(bars, minerConfig);

    // execute miner
    minerOnTick(minerConfig);
}

bool shouldCreateOrder(HeikinAshiBar &bars[], MinerConfig &minerConfig) {
    int direction = minerConfig.command == OP_BUY ? 1 : -1;
    bool shouldCreateOrder =
        // price is on good trending/reversal
        (
            direction * (bars[0].close - bars[0].open) > 0 &&
            direction * (bars[1].close - bars[1].open) > 0 &&
            direction * (bars[2].close - bars[2].open) > 0 &&
            (bars[1].high - bars[1].low) >= minerConfig.distance * 0.5
        )
        ||
        // or price is moving very fast
        (
            direction * (bars[0].close - bars[0].open) > 0 &&
            direction * (bars[1].close - bars[1].open) >= minerConfig.distance * 1.5
        );
    return shouldCreateOrder;
}

void deinit() {
    delete miner;
    miner = NULL;
}
