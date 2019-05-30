input int version = 20;

const int RangeSizeInPoints = 350;
const int BuyOrdersAtPoints[3] = { 50, 100, 150 };
const int SellOrdersAtPoints[3] = { 200, 250, 300 };
const double Lots = 0.01;
const int slippage = 1;

int prevRangeBottom = 0;

struct ProfitAndTicket {
    double profit;
    int orderTicket;
};

void init() {

}

void OnTick() {
    int buyRangeBottom = getRangeBottom(Ask);
    int sellRangeBottom = getRangeBottom(Bid);
    if (buyRangeBottom != sellRangeBottom) {
        return;
    }
    int curRangeBottom = buyRangeBottom;
    if (curRangeBottom != prevRangeBottom) {
        if (prevRangeBottom != 0) {
            processOldRange(prevRangeBottom);
        }
        processNewRange(curRangeBottom);
        prevRangeBottom = curRangeBottom;
    }
}

int getRangeBottom(double price) {
    int priceInPoints = (int)(price / _Point);
    return priceInPoints - (priceInPoints % RangeSizeInPoints);
}

void processOldRange(int rangeBottom) {
    double totalProfit = 0;
    double totalLoss = 0;
    int profitOrderTickets[];
    ProfitAndTicket losses[];
    int waitingOrderTickets[];
    int i;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
        }
        int orderType = OrderType();
        if (
            orderType == OP_BUYSTOP ||
            orderType == OP_BUYLIMIT ||
            orderType == OP_SELLSTOP ||
            orderType == OP_SELLLIMIT
        ) {
            appendArray(OrderTicket(), waitingOrderTickets);
            continue;
        }
        if (orderType != OP_BUY && orderType != OP_SELL) {
            continue;
        }
        double profit = orderType == OP_BUY ? Bid - OrderOpenPrice()
                                            : OrderOpenPrice() - Ask;
        if (profit > 0) {
            totalProfit += profit;
            appendArray(OrderTicket(), profitOrderTickets);
        } else {
            totalLoss += profit;
            ProfitAndTicket tmp = {};
            tmp.profit = profit;
            tmp.orderTicket = OrderTicket();
            appendArray(tmp, losses);
        }
    }
    for (i = 0; i < ArraySize(waitingOrderTickets); i++) {
        if (!OrderDelete(waitingOrderTickets[i])) {
            onCommandFailure();
        }
    }
    for (i = 0; i < ArraySize(profitOrderTickets); i++) {
        if (!OrderSelect(profitOrderTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
            onCommandFailure();
        }
        if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), slippage)) {
            onCommandFailure();
        }
    }
    bubbleSort(losses);

    double remainProfit = totalProfit;
    for (i = 0; i < ArraySize(losses); i++) {
        double loss = losses[i].profit;
        int orderTicket = losses[i].orderTicket;
        remainProfit += loss;
        if (remainProfit > 0) {
            if (!OrderSelect(orderTicket, SELECT_BY_TICKET, MODE_TRADES)) {
                onCommandFailure();
            }
            if (!OrderClose(orderTicket, OrderLots(), OrderClosePrice(), slippage)) {
                onCommandFailure();
            }
        } else {
            break;
        }
    }
}

void processNewRange(int rangeBottom) {
    int rangeTop = rangeBottom + RangeSizeInPoints;
    int existingBuyOrderAtPoints[];
    int existingSellOrderAtPoints[];
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
        }
        int openPriceInPoints = (int)(OrderOpenPrice() / _Point);
        if (openPriceInPoints < rangeBottom || openPriceInPoints > rangeTop) {
            continue;
        }
        if (OrderType() == OP_BUY) {
            appendArray(OrderMagicNumber(), existingBuyOrderAtPoints);
        }
        if (OrderType() == OP_SELL) {
            appendArray(OrderMagicNumber(), existingSellOrderAtPoints);
        }
    }
    int askInPoint = (int)(Ask / _Point);
    int i, atPoint, command;
    for (i = 0; i < ArraySize(BuyOrdersAtPoints); i++) {
        if (existInArray(BuyOrdersAtPoints[i], existingBuyOrderAtPoints)) {
            continue;
        }
        atPoint = rangeBottom + BuyOrdersAtPoints[i];
        if (askInPoint < atPoint) {
            command = OP_BUYSTOP;
        } else {
            command = OP_BUYLIMIT;
        }
        if (OrderSend(_Symbol, command, Lots, atPoint * _Point, slippage, 0, 0, NULL, BuyOrdersAtPoints[i]) == -1) {
            onCommandFailure();
        }
    }
    int bidInPoint = (int)(Bid / _Point);
    for (i = 0; i < ArraySize(SellOrdersAtPoints); i++) {
        if (existInArray(SellOrdersAtPoints[i], existingSellOrderAtPoints)) {
            continue;
        }
        atPoint = rangeBottom + SellOrdersAtPoints[i];
        if (bidInPoint > atPoint) {
            command = OP_SELLSTOP;
        } else {
            command = OP_SELLLIMIT;
        }
        if (OrderSend(_Symbol, command, Lots, atPoint * _Point, slippage, 0, 0, NULL, SellOrdersAtPoints[i]) == -1) {
            onCommandFailure();
        }
    }
}

void onCommandFailure() {
    Alert("Command failure: lastError=" + GetLastError());
    ExpertRemove();
}

bool existInArray(int val, int &arr[]) {
    int n = ArraySize(arr);
    for (int i = 0; i < n; i++) {
        if (arr[i] == val) {
            return true;
        }
    }
    return false;
}

void appendArray(int val, int &arr[]) {
    int n = ArraySize(arr);
    ArrayResize(arr, n + 1);
    arr[n] = val;
}

void appendArray(ProfitAndTicket &val, ProfitAndTicket &arr[]) {
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
