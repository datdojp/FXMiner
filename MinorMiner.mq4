extern int version = 2;

const int TIME_FRAME = PERIOD_H1;
const double LOTS[] = { 0.01, 0.03, 0.05, 0.07, 0.1 };
const int FIRST_INDEX = 2;
const int POINT_DISTANCE = 50;
const int SLIPPAGE = 1;

int curIndex = FIRST_INDEX;
datetime prev;
void OnTick() {
    // try to clear all previous orders (not include last order)
    int pos;
    for (pos = 0; pos < OrdersTotal(); pos++) {
        OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != _Symbol) { continue; }
        if (OrderOpenTime() >= prev) { continue; }
        if (
            (OrderType() == OP_BUY && OrderOpenPrice() < Bid) ||
            (OrderType() == OP_SELL && OrderOpenPrice() > Ask)
        ) {
            OrderClose(OrderTicket(), OrderLots(), OrderType() == OP_BUY ? Bid : Ask, SLIPPAGE);
            pos = 0;
        }
    }

    // check if it is first tick of new candle
    datetime cur = iTime(Symbol(), TIME_FRAME, 0);
    if (prev == cur) {
        return;
    }

    // if last order has profit => close it
    // otherwise, set its magic number to PREV_ORDER_MAGIC
    for (pos = 0; pos < OrdersTotal(); pos++) {
        OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != _Symbol) { continue; }
        if (OrderOpenTime() < prev) { continue; }
        if (OrderProfit() > 0) {
            OrderClose(OrderTicket(), OrderLots(), OrderType() == OP_BUY ? Bid : Ask, SLIPPAGE);
            curIndex = MathMin(ArraySize(LOTS) - 1, curIndex + 1);
        } else {
            curIndex = MathMax(0, curIndex - 1);
        }
        break;
    }

    // check if market has trend
    double fastEMA = iMA(_Symbol, TIME_FRAME, 12, 0, MODE_EMA, PRICE_CLOSE, 0);
    double slowEMA = iMA(_Symbol, TIME_FRAME, 36, 0, MODE_EMA, PRICE_CLOSE, 0);
    int command = -1;
    if (Ask >= fastEMA + POINT_DISTANCE * _Point && fastEMA >= slowEMA + POINT_DISTANCE * _Point) {
        command = OP_BUY;
    } else if (Bid <= fastEMA - POINT_DISTANCE * _Point && fastEMA <= slowEMA - POINT_DISTANCE * _Point) {
        command = OP_SELL;
    }

    // if market has trend => open new order
    if (command != -1) {
        OrderSend(Symbol(), command, LOTS[curIndex], command == OP_BUY ? Ask : Bid, SLIPPAGE, 0, 0);
    }

    // save current time
    prev = cur;
}
