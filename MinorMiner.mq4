extern int version = 1;

const int timeFrame = PERIOD_H1;
const int command = OP_BUY;
const double lots = 0.1;
const int slippage = 1;

datetime prev;
void OnTick() {
    // check time
    datetime cur = iTime(Symbol(), timeFrame, 0);
    if (prev == cur) {
        return;
    }

    // clear profitable orders
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
        if (OrderProfit() > 0) {
            OrderClose(OrderTicket(), OrderLots(), OrderType() == OP_BUY ? Bid : Ask, slippage);
            pos = 0;
        }
    }

    // open new order
    OrderSend(Symbol(), command, lots, command == OP_BUY ? Ask : Bid, slippage, 0, 0);

    // save current time
    prev = cur;
}
