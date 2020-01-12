#include "Miner.mqh";
#include "HeikinAshi.mqh";

const string inputSymbol = "USDCHF";
const double inputLots = 0.01;
const double inputDistance = 100 * _Point;
const double inputTakeProfit = 100 * _Point;
const int inputCommand = OP_BUY;
const int inputMagic = 4891804;
const int inputSlippage = 1;

const int inputHeikinAshiTimeFrame = PERIOD_H1;

Miner *miner;

void init() {
    MinerConfig minerConfig = {};
    minerConfig.symbol = inputSymbol;
    minerConfig.lots = inputLots;
    minerConfig.distance = inputDistance;
    minerConfig.takeProfit = inputTakeProfit;
    minerConfig.command = inputCommand;
    minerConfig.magic = inputMagic;
    minerConfig.slippage = inputSlippage;
    miner = new Miner(minerConfig);
}

void OnTick() {
    HeikinAshiBar bars[] = {};
    getHeikinAshiBars(inputSymbol, inputHeikinAshiTimeFrame, 10, bars);
    bool shouldCreateOrder = false;
    int direction = inputCommand == OP_BUY ? 1 : -1;
    shouldCreateOrder = direction * (bars[0].close - bars[0].open) > 0 &&
                        direction * (bars[1].close - bars[1].open) > 0 &&
                        (bars[1].high - bars[1].low) > inputDistance * 0.5;
    miner.onTick(shouldCreateOrder);
}

void deinit() {
    delete miner;
    miner = NULL;
}


/*
    string s;
    for (int i = ArraySize(bars) - 1; i >= 0; i--) {
      HeikinAshiBar bar = bars[i];
      s = StringConcatenate(s, bar.close > bar.open ? 1 : -1, ", ");
    }
    Alert(s);
    ExpertRemove();
    return;
    */