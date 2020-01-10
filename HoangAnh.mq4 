// Miner v0.1
#include "Miner.mqh";

Miner *guMiner, *gjMiner;

void init() {
    // miner for selling GBPUSD
    MinerConfig guMinerConfig = {};
    guMinerConfig.symbol = "GBPUSD";
    guMinerConfig.lots = 0.01;
    guMinerConfig.distance = 100 * _Point;
    guMinerConfig.takeProfit = 100 * _Point;
    guMinerConfig.command = OP_SELL;
    guMinerConfig.shouldTrailingStop = false;
    guMinerConfig.magic = 4891804;
    guMinerConfig.slippage = 1;
    guMiner = new Miner(guMinerConfig);

    MinerConfig gjMinerConfig = {};
    gjMinerConfig.symbol = "GBPJPY";
    gjMinerConfig.lots = 0.01;
    gjMinerConfig.distance = 100 * _Point;
    gjMinerConfig.takeProfit = 100 * _Point;
    gjMinerConfig.command = OP_BUY;
    gjMinerConfig.shouldTrailingStop = false;
    gjMinerConfig.magic = 8930843;
    gjMinerConfig.slippage = 1;
    gjMiner = new Miner(gjMinerConfig);
}

void OnTick() {
    guMiner.onTick(true);
    gjMiner.onTick(true);
}

void deinit() {
    delete guMiner;
    guMiner = NULL;

    delete gjMiner;
    gjMiner = NULL;
}



