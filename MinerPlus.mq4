// MinerMA20RSI v0.1
#include "Miner.mqh";

double slippage = 1;

void OnTick() {
  double highest = iHigh(NULL, PERIOD_H1, iHighest(NULL, PERIOD_H1, MODE_HIGH, 24, 1));
  double lowest = iLow(NULL, PERIOD_H1, iLowest(NULL, PERIOD_H1, MODE_LOW, 24, 1));
  Miner *miner = new Miner(0.01, 100 * _Point, 100 * _Point, OP_BUY, 0, lowest, 0);
  miner.onTick();
  delete miner;
  miner = new Miner(0.01, 100 * _Point, 100 * _Point, OP_SELL, highest, 1000, 0);
  miner.onTick();
  delete miner;
  miner = NULL;

  
}