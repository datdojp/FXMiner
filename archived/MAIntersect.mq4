double prevFastMA = 0;
double prevSlowMA = 0;
int prevTime = -1;

const double Lots = 2;
const int Slippage = 1;
const int MAGIC = 489483;
const int INTERSET_UP = 1;
const int INTERSET_DOWN = 2;

void OnTick() {
    if (prevTime == -1 || prevTime != Hour()) {
        handleOnTick();
        prevTime = Hour();
    }
}

void handleOnTick() {
    double fastMA = iMA(NULL, PERIOD_H1, 5, 0, MODE_EMA, PRICE_CLOSE, 0);
    double slowMA = iMA(NULL, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    if (prevFastMA != 0 && prevSlowMA != 0) {
        bool didIntersect = (fastMA - slowMA) * (prevFastMA - prevSlowMA) < 0;
        if (didIntersect) {
            for (int pos = OrdersTotal()-1; pos >= 0; pos--) {
                if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
                    if (OrderSymbol() != _Symbol) { continue; }
                    if (OrderType() != OP_BUY && OrderType() != OP_SELL) { continue; }
                    if (OrderMagicNumber() != MAGIC) { continue; }
                    if (!OrderClose(OrderTicket(), OrderLots(), OrderType() == OP_BUY ? Bid : Ask, Slippage)) {
                        return;
                    }
                }
            }
            if (MathAbs((Ask+Bid)/2 - (fastMA + slowMA)/2) < 20 * _Point) {
                if (fastMA > slowMA) { // up
                    if (OrderSend(_Symbol, OP_BUY, Lots, Ask, Slippage, 0, 0, NULL, MAGIC) == -1) {
                        return;
                    }
                } else { // down
                    if (OrderSend(_Symbol, OP_SELL, Lots, Bid, Slippage, 0, 0, NULL, MAGIC) == -1) {
                        return;
                    }
                }
            }
        }
    }
    prevFastMA = fastMA;
    prevSlowMA = slowMA;
}