const double Lots = 1;
const int TimeFrame = PERIOD_H1;
const double TakeProfit = 100 * _Point;
const double StopLoss = 2 * TakeProfit;
const int Slippage = 1;
const int Magic = 382948394;

datetime prevTime;
double prevStoch;
int prevOverstretched;
int prevOrderTicket;
int state;

const int STATE_WAITING = 0;
const int STATE_OVERSTRETCHED = 1;
const int STATE_ORDER_OPENED = 2;

const int NONE_OVERSTRETCHED = 0;
const int UPPER_OVERSTRETCHED = 1;
const int LOWER_OVERSTRETCHED = -1;

void OnInit() {
    state = STATE_WAITING;
    prevTime = iTime(NULL, TimeFrame, 0);
}

void OnTick() {
    if (state == STATE_ORDER_OPENED) {
        if (!OrderSelect(prevOrderTicket, SELECT_BY_TICKET, MODE_TRADES)) { return; }
        double profit = OrderType() == OP_BUY ? Bid - OrderOpenPrice() : OrderOpenPrice() - Ask;
        if (profit >= TakeProfit || profit <= -StopLoss) {
            if (!OrderClose(prevOrderTicket, OrderLots(), OrderType() == OP_BUY ? Bid : Ask, Slippage)) { return; }
            state = STATE_WAITING;
        }
    }
    datetime currentTime = iTime(NULL, TimeFrame, 0);
    if (prevTime != currentTime) {
        onCandleClose();
        prevTime = currentTime;
    }
}

void onCandleClose() {
    double upperBB = iBands(NULL, TimeFrame, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double lowerBB = iBands(NULL, TimeFrame, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    double stoch =  iStochastic(NULL, TimeFrame, 5, 3, 3, MODE_SMA, 1, MODE_MAIN, 0);
    int overstretched;
    if (stoch > 80 && Bid > upperBB) {
        overstretched = UPPER_OVERSTRETCHED;
    } else if (stoch < 20 && Ask < lowerBB) {
        overstretched = LOWER_OVERSTRETCHED;
    } else {
        overstretched = NONE_OVERSTRETCHED;
    }
    if (state == STATE_WAITING) {
        if (overstretched != NONE_OVERSTRETCHED) {
            state = STATE_OVERSTRETCHED;
            prevOverstretched = overstretched;
            prevStoch = stoch;
        }
    } else if (state == STATE_OVERSTRETCHED) {
        if (prevOverstretched == UPPER_OVERSTRETCHED && Bid < upperBB) {
            if (Bid > upperBB - 100 * _Point && stoch < prevStoch) {
                if (OrderSend(NULL, OP_SELL, Lots, Bid, Slippage, 0, 0, NULL, Magic) == -1) { return; }
                saveTicketOfJustOpenedOrder();
                state = STATE_ORDER_OPENED;
            } else {
                state = STATE_WAITING;
            }
        } else if (prevOverstretched == LOWER_OVERSTRETCHED && Ask > lowerBB) {
            if (Ask < lowerBB + 100 * _Point && stoch > prevStoch) {
                if (OrderSend(NULL, OP_BUY, Lots, Ask, Slippage, 0, 0, NULL, Magic) == -1) { return; }
                saveTicketOfJustOpenedOrder();
                state = STATE_ORDER_OPENED;
            } else {
                state = STATE_WAITING;
            }
        } else if (overstretched != NONE_OVERSTRETCHED) {
            prevOverstretched = overstretched;
            prevStoch = stoch;
        }
    } else if (state == STATE_ORDER_OPENED) {
        if (overstretched != NONE_OVERSTRETCHED) {
            state = STATE_OVERSTRETCHED;
            prevOverstretched = overstretched;
            prevStoch = stoch;
            if (!OrderSelect(prevOrderTicket, SELECT_BY_TICKET, MODE_TRADES)) { return; }
            if (!OrderClose(prevOrderTicket, OrderLots(), OrderType() == OP_BUY ? Bid : Ask, Slippage)) { return; }
        }
    }
}

void saveTicketOfJustOpenedOrder() {
    datetime maxOpenTime;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        if (
            OrderSelect(pos, SELECT_BY_POS, MODE_TRADES) &&
            OrderSymbol() == _Symbol &&
            (OrderType() == OP_BUY || OrderType() == OP_SELL) &&
            OrderMagicNumber() == Magic &&
            maxOpenTime < OrderOpenTime()
        ) {
            prevOrderTicket = OrderTicket();
            maxOpenTime = OrderOpenTime();
        }
    }
}
