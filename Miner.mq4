// Miner v0.1
#include "Miner.mqh";

enum COMMAND {
    BUY = 1, // Buy
    SELL = 2, // Sell
};

input double Lots = 0.01;
input int DistancePoints = 100;
input int TakeProfitPoints = 100;
input COMMAND Command = BUY;
input double BottomPrice = 0; // no limit
input double TopPrice = 1000; // no limit
input int slippage = 1;

const int MAGIC = 105906716;

Miner *miner;

void init() {
    miner = new Miner(Lots,
                      DistancePoints * _Point,
                      TakeProfitPoints * _Point,
                      Command == BUY ? OP_BUY : OP_SELL,
                      BottomPrice,
                      TopPrice,
                      MAGIC);
}

void OnTick() {
    miner.onTick();
}

void deinit() {
    if (miner != NULL) {
        delete miner;
        miner = NULL;
    }
}
