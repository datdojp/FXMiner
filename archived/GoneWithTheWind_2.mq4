#property strict

extern double lots = 1;
extern int bufferPoints = 2;
extern int slippage = 1;
extern int version = 2;

bool stopped = false;
double prevAsk;
int prevTrend = 0;
datetime prevTime;
int init() {
    prevAsk = Ask;
    prevTime = TimeCurrent();
    return 0;
}
void OnTick() {
    if (stopped) {
        return;
    }
    datetime now = TimeCurrent();
    if (now - prevTime < 5 * 60) {
        return;
    }

    // detect trend change
    int trend = Ask > prevAsk ? 1 : -1;
    bool isTrendChanged = trend != prevTrend;

    int ticket = -1;
    for (int pos = OrdersTotal()-1; pos >= 0; pos--) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            stopped = true;
            return;
        }
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) {
            continue;
        }
        ticket = OrderTicket();
        break;
    }
    if (ticket != -1) {
        if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
            stopped = true;
            return;
        }
        const int type = OrderType();
        double profitPoints = 0;
        if (type == OP_BUY) {
            profitPoints = (Bid - OrderOpenPrice()) / _Point;
        } else if (type == OP_SELL) {
            profitPoints = (OrderOpenPrice() - Ask) / _Point;
        }
        const double compensationPoints = MarketInfo(_Symbol, MODE_SPREAD) + bufferPoints;
        if (-compensationPoints <= profitPoints && profitPoints <= 0) {
            // do nothing
        }
        if (profitPoints < -compensationPoints) {
            if (!OrderClose(ticket, OrderLots(), type == OP_BUY ? Bid : Ask, slippage)) {
                stopped = true;
                return;
            }
            if (!OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS, MODE_HISTORY)) {
                stopped = true;
                return;
            }
            Print("===SL: ", OrderProfit());
            if (OrderSend(_Symbol, type == OP_BUY ? OP_SELL : OP_BUY, lots, type == OP_BUY ? Bid : Ask, slippage, 0, 0) == -1) {
                stopped = true;
                return;
            }
        }
        if (profitPoints > 0) {
            if ((type == OP_BUY && isTrendChanged && trend == -1) || (type == OP_SELL && isTrendChanged && trend == 1)) {
                if (!OrderClose(ticket, OrderLots(), type == OP_BUY ? Bid : Ask, slippage)) {
                    stopped = true;
                    return;
                }
                if (!OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS, MODE_HISTORY)) {
                    stopped = true;
                    return;
                }
                Print("===TP: ", OrderProfit());
                if (OrderSend(_Symbol, trend == -1 ? OP_SELL : OP_BUY, lots, trend == -1 ? Bid : Ask, slippage, 0, 0) == -1) {
                    stopped = true;
                    return;
                }
            }
        }
    } else {
        if (OrderSend(_Symbol, OP_BUY, lots, Ask, slippage, 0, 0) == -1) {
            stopped = true;
            return;
        }
    }
    prevAsk = Ask;
    prevTrend = trend;
    prevTime = now;
}
