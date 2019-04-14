#property strict

extern int rangeSizePoints = 100;
extern double lots = 0.01;
extern int slippage = 1;
extern int version = 6;

void OnTick() {
    int askPoint = (int)(Ask / _Point);
    int bidPoint = (int)(Bid / _Point);
    if (askPoint / rangeSizePoints == bidPoint / rangeSizePoints) {
        checkCloseRange(askPoint - (askPoint % rangeSizePoints) + rangeSizePoints);
        checkCloseRange(askPoint - (askPoint % rangeSizePoints) - rangeSizePoints);
    }
    scheduleBuy();
    scheduleSell();
}

void checkCloseRange(int fromPoint) {
    if (fromPoint < 0) {
        return;
    }
    int toPoint = fromPoint + rangeSizePoints;
    double fromPrice = fromPoint * _Point;
    double toPrice = toPoint * _Point;
    int buyOrderTicket = -1;
    int sellOrderTicket = -1;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        if (OrderType() == OP_BUY && isPricesEqual(OrderOpenPrice(), fromPrice)) {
            buyOrderTicket = OrderTicket();
        }
        if (OrderType() == OP_SELL && isPricesEqual(OrderOpenPrice(), toPrice)) {
            sellOrderTicket = OrderTicket();
        }
        if (buyOrderTicket != -1 && sellOrderTicket != -1) {
            break;
        }
    }
    if (buyOrderTicket != -1 && sellOrderTicket != -1) {
        OrderSelect(buyOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
        OrderClose(OrderTicket(), OrderLots(), Bid, slippage);

        OrderSelect(sellOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
        OrderClose(OrderTicket(), OrderLots(), Ask, slippage);
    }
}

void scheduleBuy() {
    int pricePoint = (int)(Ask / _Point);
    if (pricePoint % rangeSizePoints == 0) {
        return;
    }
    double limit = (pricePoint - (pricePoint % rangeSizePoints)) * _Point;
    double stop = (pricePoint - (pricePoint % rangeSizePoints) + rangeSizePoints) * _Point;
    bool isLimitScheduled = false;
    bool isStopScheduled = false;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        if (isPricesEqual(OrderOpenPrice(), limit) && (OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT)) {
            isLimitScheduled = true;
        }
        if (isPricesEqual(OrderOpenPrice(), stop) && (OrderType() == OP_BUY || OrderType() == OP_BUYSTOP)) {
            isStopScheduled = true;
        }
        if (isLimitScheduled && isStopScheduled) {
            break;
        }
    }
    if (!isLimitScheduled) {
        OrderSend(_Symbol, OP_BUYLIMIT, lots, limit, slippage, 0, 0);
    }
    if (!isStopScheduled) {
        OrderSend(_Symbol, OP_BUYSTOP, lots, stop, slippage, 0, 0);
    }
}

void scheduleSell() {
    int pricePoint = (int)(Bid / _Point);
    if (pricePoint % rangeSizePoints == 0) {
        return;
    }
    double stop = (pricePoint - (pricePoint % rangeSizePoints)) * _Point;
    double limit = (pricePoint - (pricePoint % rangeSizePoints) + rangeSizePoints) * _Point;
    bool isLimitScheduled = false;
    bool isStopScheduled = false;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        if (isPricesEqual(OrderOpenPrice(), limit) && (OrderType() == OP_SELL || OrderType() == OP_SELLLIMIT)) {
            isLimitScheduled = true;
        }
        if (isPricesEqual(OrderOpenPrice(), stop) && (OrderType() == OP_SELL || OrderType() == OP_SELLSTOP)) {
            isStopScheduled = true;
        }
        if (isLimitScheduled && isStopScheduled) {
            break;
        }
    }
    if (!isLimitScheduled) {
        OrderSend(_Symbol, OP_SELLLIMIT, lots, limit, slippage, 0, 0);
    }
    if (!isStopScheduled) {
        OrderSend(_Symbol, OP_SELLSTOP, lots, stop, slippage, 0, 0);
    }
}

bool isPricesEqual(double price1, double price2) {
    return MathAbs(price1 - price2) / _Point < 5;
}
