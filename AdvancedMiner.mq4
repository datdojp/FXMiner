#include "lib.mqh";

input double Lots = 0.01;
input int Slippage = 3;
input double MaxOpenPrice = 1000;
input double MinOpenPrice = 0;

const int AI_TimeFrame = PERIOD_H1;

MinerConfig minerConfig = {};

void init() {
    minerConfig.symbol = _Symbol;
    minerConfig.lots = Lots;
    minerConfig.command = getAutoCommand(_Symbol);
    minerConfig.magic = getAutoMagic(_Symbol);
    minerConfig.slippage = Slippage;
    minerConfig.shouldSetTrailingStop = false;
    minerConfig.maxOpenPrice = MaxOpenPrice;
    minerConfig.minOpenPrice = MinOpenPrice;
}

void OnTick() {
    // use ATR to determine distance and takeprofit
    const double atr = iATR(minerConfig.symbol, AI_TimeFrame, 14, 0);
    minerConfig.distance = NormalizeDouble(atr, MarketInfo(minerConfig.symbol, MODE_DIGITS));
    minerConfig.takeProfit = NormalizeDouble(atr, MarketInfo(minerConfig.symbol, MODE_DIGITS));

    // use heikinashi to check if we should create new order
    HeikinAshiBar bars[] = {};
    getHeikinAshiBars(minerConfig.symbol, AI_TimeFrame, 10, bars);
    minerConfig.shouldCreateOrder = shouldCreateOrder(bars, minerConfig);

    // execute miner
    minerOnTick(minerConfig);
}

bool shouldCreateOrder(HeikinAshiBar &bars[], MinerConfig &minerConfig) {
    int direction = minerConfig.command == OP_BUY ? 1 : -1;
    double avg = (minerConfig.distance + minerConfig.takeProfit) / 2;

    const long volume_0 = iVolume(minerConfig.symbol, AI_TimeFrame, 0);
    const long volume_1 = iVolume(minerConfig.symbol, AI_TimeFrame, 1);
    const long volume_2 = iVolume(minerConfig.symbol, AI_TimeFrame, 2);
    const long volume_3 = iVolume(minerConfig.symbol, AI_TimeFrame, 3);
    return ( // 3 candles
        direction * (bars[0].close - bars[0].open) > 0 &&
        direction * (bars[1].close - bars[1].open) > 0 && volume_1 > volume_2 * 1.25 &&
        direction * (bars[2].close - bars[2].open) > 0 && volume_2 > volume_3 * 1.25
    )
    ||
    ( // 2 candles
        direction * (bars[0].close - bars[0].open) > 0 &&
        direction * (bars[1].close - bars[1].open) > 0 && volume_1 > volume_2 * 2
    );

    /*
    bool shouldCreateOrder =
        // 3 candles
        (
            direction * (bars[0].close - bars[0].open) > 0 &&
            (bars[0].high - bars[0].low) >= avg * 0.25 &&

            direction * (bars[1].close - bars[1].open) >= avg * 0.25 &&
            (bars[1].high - bars[1].low) >= avg * 0.5 &&

            direction * (bars[2].close - bars[2].open) >= avg * 0.25 &&
            (bars[2].high - bars[2].low) >= avg * 0.5
        )
        ||
        // 2 candles
        (
            direction * (bars[0].close - bars[0].open) > 0 &&
            direction * (bars[1].close - bars[1].open) >= avg
        );
    return shouldCreateOrder;
    */
}
