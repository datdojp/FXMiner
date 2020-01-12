struct HeikinAshiBar {
  double open;
  double high;
  double low;
  double close;
};

void getHeikinAshiBars(string symbol, int timeframe, int count, HeikinAshiBar &bars[]) {
  count = MathMin(iBars(symbol, timeframe), count);
  ArrayResize(bars, count);
  for (int i = count-1; i >= 0; i--) {
    HeikinAshiBar bar = {};
    HeikinAshiBar prevBar = {};
    if (i == count - 1) {
      prevBar.open = iOpen(symbol, timeframe, i+1);
      prevBar.high = iHigh(symbol, timeframe, i+1);
      prevBar.low = iLow(symbol, timeframe, i+1);
      prevBar.close = iClose(symbol, timeframe, i+1);
    } else {
      prevBar = bars[i+1];
    }
    bar.open = (prevBar.open + prevBar.close) / 2;
    bar.close = (iOpen(symbol, timeframe, i) + iHigh(symbol, timeframe, i) + iLow(symbol, timeframe, i) + iClose(symbol, timeframe, i)) / 4;
    bar.high = MathMax(iHigh(symbol, timeframe, i), MathMax(bar.open, bar.close));
    bar.low = MathMin(iLow(symbol, timeframe, i), MathMin(bar.open, bar.close));

    bars[i] = bar;
  }
}