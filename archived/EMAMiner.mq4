#include "Miner.mqh";

void OnTick() {

}

double calculateAverageEMATiltAngle(int n) {
    double tiltAngle[];
    ArrayResize(tiltAngle, n);
    int timeframe = PERIOD_H1;
    int period = 25;
    int maMethod = MODE_EMA
    int appliedPrice = PRICE_CLOSE;
    double currentEMA = iMA(NULL, timeframe, period, 0, maMethod, appliedPrice, 0);
    for (int shift = 1; shift < n; shift++) {
        double pastEMA = iMA(NULL, timeframe, period, 0, maMethod, appliedPrice, shift);
        
    }
    
}
