#include "Miner.mqh";
#include "HeikinAshi.mqh";

const string inputSymbol = "USDJPY";
const double inputLots = 0.02;
const double inputDistance = 100 * MarketInfo(inputSymbol, MODE_POINT);
const double inputTakeProfit = 100 * MarketInfo(inputSymbol, MODE_POINT);
const int inputCommand = OP_BUY;
const int inputMagic = 4891804;
const int inputSlippage = 1;

const int inputHeikinAshiTimeFrame = PERIOD_H1;

const int inputATRTimeFrame = PERIOD_H1;

Miner *miner;
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

    miner = new Miner();
}

void OnTick() {
    // use heikinashi to check if we should create new order
    HeikinAshiBar bars[] = {};
    getHeikinAshiBars(inputSymbol, inputHeikinAshiTimeFrame, 10, bars);
    bool shouldCreateOrder = false;
    int direction = inputCommand == OP_BUY ? 1 : -1;
    shouldCreateOrder = direction * (bars[0].close - bars[0].open) > 0 &&
                        direction * (bars[1].close - bars[1].open) > 0 &&
                        (bars[1].high - bars[1].low) > inputDistance * 0.5;
    minerConfig.shouldCreateOrder = shouldCreateOrder;

    // use ATR to determine distance and takeprofit
    const double atr = iATR(inputSymbol, inputATRTimeFrame, 14, 0);
    const int degits = MarketInfo(inputSymbol, MODE_DIGITS);
    minerConfig.distance = NormalizeDouble(atr * 2/3, degits);
    minerConfig.takeProfit = NormalizeDouble(atr * 2/3, degits);

    // execute miner
    miner.onTick(minerConfig);
}

void deinit() {
    delete miner;
    miner = NULL;
}
