int stopLossPoints = 40;
int takeProfitPoints = 20;
double lots = 1;
int timeFrame = PERIOD_M30;

void OnTick() {
    bool hasOrder = false;
    for (int position = 0; position < OrdersTotal(); position++) {
        OrderSelect(position, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != _Symbol) { continue; }
        int profitPoints = (OrderType() == OP_BUY ? Bid - OrderOpenPrice() : OrderOpenPrice() - Ask) / _Point;
        if (profitPoints <= -stopLossPoints || profitPoints >= takeProfitPoints) {
            OrderClose(OrderTicket(), OrderLots(), OrderType() == OP_BUY ? Bid : Ask, 1);
        }
        hasOrder = true;
    }
    if (!hasOrder) {
      //  double upperBand = iBands(_Symbol, timeFrame, 21, 2, 0, PRICE_WEIGHTED, MODE_UPPER, 0);
      //  double lowerBand = iBands(_Symbol, timeFrame, 21, 2, 0, PRICE_WEIGHTED, MODE_LOWER, 0);
      //  if ((upperBand - lowerBand) / _Point < stopLossPoints) {
            OrderSend(_Symbol, OP_BUY, lots, Ask, 1, 0, 0);
            OrderSend(_Symbol, OP_SELL, lots, Bid, 1, 0, 0);
     //   }
    }
}
