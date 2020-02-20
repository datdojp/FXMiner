#include "lib.mqh";

input double Lots = 0.01;
input double Distance = 100;
input double TakeProfit = 100;
input COMMAND Command;
input int Magic = 0;
input double MaxOpenPrice = 1000;
input double MinOpenPrice = 0;
input int Slippage = 3;
input string Version = "1.0";

MinerConfig minerConfig = {};

void init() {
    minerConfig.symbol = _Symbol;
    minerConfig.lots = Lots;
    minerConfig.distance = Distance * _Point;
    minerConfig.takeProfit = TakeProfit * _Point;
    minerConfig.command = Command;
    minerConfig.magic = Magic;
    minerConfig.slippage = Slippage;
    minerConfig.shouldCreateOrder = true;
    minerConfig.shouldSetTrailingStop = false;
    minerConfig.maxOpenPrice = MaxOpenPrice;
    minerConfig.minOpenPrice = MinOpenPrice;
}

void OnTick() {
    minerOnTick(minerConfig);
}
