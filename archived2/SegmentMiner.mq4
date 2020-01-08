input int version = 9;

const int RANGE_SIZE_IN_POINTS = 100;
const int MEGA_RANGE_SIZE_IN_POINTS = RANGE_SIZE_IN_POINTS * 10;
const int BUY_ORDERS_AT_POINTS[] = { 25 };
const int SELL_ORDERS_AT_POINTS[] = { 75 };
const int CLOSE_RANGE_IF_PRICE_LEFT_IN_POINTS = 200;
const double LOTS = 0.5;
const int SLIPPAGE = 1;

double prevAccountEquity;
int debugBadOrders[];

struct ProfitAndTicket {
    double profit;
    int orderTicket;
    int debugOpenPrice;
};

void init() {
    prevAccountEquity = AccountEquity();
}

void OnTick() {
    ArrayResize(debugBadOrders, 0);
    if (AccountEquity() / prevAccountEquity > 1.05) {
        closeAllOrders();
        prevAccountEquity = AccountEquity();
        return;
    }
    const int buyRangeBottom = getRangeBottom(Ask, MEGA_RANGE_SIZE_IN_POINTS);
    const int sellRangeBottom = getRangeBottom(Bid, MEGA_RANGE_SIZE_IN_POINTS);
    if (buyRangeBottom != sellRangeBottom) {
        return;
    }
    const int curMegaRangeBottom = buyRangeBottom;
    int rangeBottom;
    for (
        rangeBottom = curMegaRangeBottom - MEGA_RANGE_SIZE_IN_POINTS;
        rangeBottom < curMegaRangeBottom + 2 * MEGA_RANGE_SIZE_IN_POINTS;
        rangeBottom += RANGE_SIZE_IN_POINTS
    ) {
        setWaitingOrdersForRange(rangeBottom,
                                 rangeBottom + RANGE_SIZE_IN_POINTS,
                                 BUY_ORDERS_AT_POINTS,
                                 SELL_ORDERS_AT_POINTS);
    }
    int allAvailableRanges[];
    getAllAvailableRanges(allAvailableRanges);
    const int allAvailableRangesSize = ArraySize(allAvailableRanges);
    for (int i = 0; i < allAvailableRangesSize; i++) {
        rangeBottom = allAvailableRanges[i];
        int rangeTop = rangeBottom + RANGE_SIZE_IN_POINTS;
        if (
            rangeBottom - ((int)(Ask / _Point)) > CLOSE_RANGE_IF_PRICE_LEFT_IN_POINTS ||
            ((int)(Bid / _Point)) - rangeTop > CLOSE_RANGE_IF_PRICE_LEFT_IN_POINTS
        ) {
            closeOrdersInRange(rangeBottom, rangeTop);
        }
    }
    // debug >>
    if (ArraySize(debugBadOrders) > 0) {
        ArraySort(debugBadOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
        string msg = "====== Ask=" + Ask + ", BadOrders[" + ArraySize(debugBadOrders) + "]=";
        for (int k = 0; k < ArraySize(debugBadOrders); k++) {
            msg = msg + debugBadOrders[k] + ", ";
        }
        Alert(msg);
    }
    // debug <<
}

int getRangeBottom(double price, int rangeSizeInPoints) {
    int priceInPoints = (int)(price / _Point);
    return priceInPoints - (priceInPoints % rangeSizeInPoints);
}

void getAllAvailableRanges(int &allAvailableRanges[]) {
    const int orderTotal = OrdersTotal();
    for (int pos = 0; pos < orderTotal; pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
        }
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        int orderType = OrderType();
        if (orderType != OP_BUY && orderType != OP_SELL) {
            continue;
        }
        int rangeBottom = getRangeBottom(OrderOpenPrice(), RANGE_SIZE_IN_POINTS);
        if (!existInArray(rangeBottom, allAvailableRanges)) {
            appendArray(rangeBottom, allAvailableRanges);
        }
    }
}

void closeOrdersInRange(const int rangeBottom, const int rangeTop) {
    double totalProfit = 0;
    int profitOrderTickets[];
    ProfitAndTicket losses[];
    const int orderTotal = OrdersTotal();
    for (int pos = 0; pos < orderTotal; pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
        }
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        int openPriceInPoints = (int)(OrderOpenPrice() / _Point);
        if (openPriceInPoints < rangeBottom || openPriceInPoints > rangeTop) {
            continue;
        }
        int orderType = OrderType();
        if (orderType != OP_BUY && orderType != OP_SELL) {
            continue;
        }
        double profit = orderType == OP_BUY ? Bid - OrderOpenPrice()
                                            : OrderOpenPrice() - Ask;
        if (profit > 0) {
            totalProfit += profit;
            appendArray(OrderTicket(), profitOrderTickets);
        } else {
            ProfitAndTicket tmp = {};
            tmp.profit = profit;
            tmp.orderTicket = OrderTicket();
            tmp.debugOpenPrice = (int)(OrderOpenPrice() / _Point);
            appendArray(tmp, losses);
        }
    }
    int i;
    const int profitOrderTicketsSize = ArraySize(profitOrderTickets);
    for (i = 0; i < profitOrderTicketsSize; i++) {
        if (!OrderSelect(profitOrderTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
            onCommandFailure();
        }
        if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), SLIPPAGE)) {
            onCommandFailure();
        }
    }
    bubbleSort(losses);
    double remainProfit = totalProfit;
    const int lossesSize = ArraySize(losses);
    for (i = 0; i < lossesSize; i++) {
        double loss = losses[i].profit;
        int orderTicket = losses[i].orderTicket;
        remainProfit += loss;
        if (remainProfit > 0) {
            if (!OrderSelect(orderTicket, SELECT_BY_TICKET, MODE_TRADES)) {
                onCommandFailure();
            }
            if (!OrderClose(orderTicket, OrderLots(), OrderClosePrice(), SLIPPAGE)) {
                onCommandFailure();
            }
        } else {
            //debug >>
            for (int j = i; j < lossesSize; j++) {
                appendArray(losses[j].debugOpenPrice, debugBadOrders);
            }
            //debug <<
            break;
        }
    }
}

void setWaitingOrdersForRange(const int rangeBottom,
                              const int rangeTop,
                              const int &buyOrdersAtPoints[],
                              const int &sellOrdersAtPoints[]) {
    int existingBuyOrderAtPoints[];
    int existingSellOrderAtPoints[];
    const int orderTotal = OrdersTotal();
    for (int pos = 0; pos < orderTotal; pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
        }
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        int openPriceInPoints = (int)(OrderOpenPrice() / _Point);
        if (openPriceInPoints < rangeBottom || openPriceInPoints > rangeTop) {
            continue;
        }
        int orderType = OrderType();
        if (
            orderType == OP_BUY ||
            orderType == OP_BUYLIMIT ||
            orderType == OP_BUYSTOP
        ) {
            appendArray(OrderMagicNumber(), existingBuyOrderAtPoints);
        }
        if (
            orderType == OP_SELL ||
            orderType == OP_SELLLIMIT ||
            orderType == OP_SELLSTOP
        ) {
            appendArray(OrderMagicNumber(), existingSellOrderAtPoints);
        }
    }
    int askInPoint = (int)(Ask / _Point);
    int i, atPoint, command;
    for (i = 0; i < ArraySize(buyOrdersAtPoints); i++) {
        if (existInArray(buyOrdersAtPoints[i], existingBuyOrderAtPoints)) {
            continue;
        }
        atPoint = rangeBottom + buyOrdersAtPoints[i];
        if (askInPoint < atPoint) {
            command = OP_BUYSTOP;
        } else {
            command = OP_BUYLIMIT;
        }
        if (OrderSend(_Symbol, command, LOTS, atPoint * _Point, SLIPPAGE, 0, 0, NULL, buyOrdersAtPoints[i]) == -1) {
            onCommandFailure();
        }
    }
    int bidInPoint = (int)(Bid / _Point);
    for (i = 0; i < ArraySize(sellOrdersAtPoints); i++) {
        if (existInArray(sellOrdersAtPoints[i], existingSellOrderAtPoints)) {
            continue;
        }
        atPoint = rangeBottom + sellOrdersAtPoints[i];
        if (bidInPoint > atPoint) {
            command = OP_SELLSTOP;
        } else {
            command = OP_SELLLIMIT;
        }
        if (OrderSend(_Symbol, command, LOTS, atPoint * _Point, SLIPPAGE, 0, 0, NULL, sellOrdersAtPoints[i]) == -1) {
            onCommandFailure();
        }
    }
}

void onCommandFailure() {
    Alert("Command failure: lastError=" + GetLastError());
    ExpertRemove();
}

bool existInArray(const int val, const int &arr[]) {
    int n = ArraySize(arr);
    for (int i = 0; i < n; i++) {
        if (arr[i] == val) {
            return true;
        }
    }
    return false;
}

void appendArray(const int val, int &arr[]) {
    int n = ArraySize(arr);
    ArrayResize(arr, n + 1);
    arr[n] = val;
}

void appendArray(const ProfitAndTicket &val, ProfitAndTicket &arr[]) {
    int n = ArraySize(arr);
    ArrayResize(arr, n + 1);
    arr[n] = val;
}

void bubbleSort(ProfitAndTicket &arr[]) {
    int n = ArraySize(arr);
    for (int i = 0; i < n-1; i++) {
        for (int j = 0; j < n-i-1; j++) {
            if (arr[j].profit < arr[j+1].profit) {
              ProfitAndTicket tmp = arr[j];
              arr[j] = arr[j+1];
              arr[j+1] = tmp;
            }
        }
    }
}

void closeAllOrders() {
    int orderTickets[];
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
        }
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        int orderType = OrderType();
        if (orderType != OP_BUY && orderType != OP_SELL) {
            continue;
        }
        appendArray(OrderTicket(), orderTickets);
    }
    const int orderTicketsSize = ArraySize(orderTickets);
    for (int i = 0; i < orderTicketsSize; i++) {
        if (!OrderSelect(orderTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
            onCommandFailure();
        }
        if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), SLIPPAGE)) {
            onCommandFailure();
        }
    }
}
