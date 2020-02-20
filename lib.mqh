/*****************************************************
*************           MINER            *************
******************************************************/
struct MinerConfig {
    string symbol;
    double lots;
    double distance;
    double takeProfit;
    int command;
    int magic;
    int slippage;

    bool shouldCreateOrder;

    bool shouldSetTrailingStop;
    double trailingStopMinDistance;
    double trailingStopBuffer;

    double minOpenPrice;
    double maxOpenPrice;
};

void minerOnTick(MinerConfig &config) {
    int i;

    // collect data from current open postions
    double ask = MarketInfo(config.symbol, MODE_ASK);
    double bid = MarketInfo(config.symbol, MODE_BID);
    double openPrice = config.command == OP_BUY ? ask : bid;
    double closePrice = config.command == OP_BUY ? bid : ask;
    double sign = config.command == OP_BUY ? 1 : -1;
    int closablePositionTickets[];
    int trailingStoppablePositionTickets[];
    double trailingStoppablePositionProfits[];
    double lowestDistance = 1000000;
    int ordersTotal = OrdersTotal();
    for (int pos = 0; pos < ordersTotal; pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSelect, index=" + pos + ", select=SELECT_BY_POS, pool=MODE_TRADES, err=" + GetLastError());
            ExpertRemove();
            return;
        }
        if (OrderSymbol() != config.symbol) { continue; }
        if (OrderType() != config.command) { continue; }
        if (config.magic > 0 && OrderMagicNumber() != config.magic) { continue; }
        double profit = sign * (closePrice - OrderOpenPrice());
        double distance = MathAbs(OrderOpenPrice() - openPrice);
        if (profit > config.takeProfit) {
            ArrayResize(closablePositionTickets, ArraySize(closablePositionTickets) + 1);
            closablePositionTickets[ArraySize(closablePositionTickets) - 1] = OrderTicket();
        } else {
            if (profit >= config.trailingStopMinDistance && OrderStopLoss() == 0) {
                ArrayResize(trailingStoppablePositionTickets, ArraySize(trailingStoppablePositionTickets) + 1);
                ArrayResize(trailingStoppablePositionProfits, ArraySize(trailingStoppablePositionTickets));
                trailingStoppablePositionTickets[ArraySize(trailingStoppablePositionTickets) - 1] = OrderTicket();
                trailingStoppablePositionProfits[ArraySize(trailingStoppablePositionTickets) - 1] = profit;
            }
            if (distance < lowestDistance) {
                lowestDistance = distance;
            }
        }
    }

    // close tickets if closable
    for (i = 0; i < ArraySize(closablePositionTickets); i++) {
        if (!OrderSelect(closablePositionTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSelect, index=" + closablePositionTickets[i] + ", select=SELECT_BY_TICKET, pool=MODE_TRADES, err=" + GetLastError());
            ExpertRemove();
            return;
        }
        if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), config.slippage)) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderClose, ticket=" + OrderTicket() + ", lots=" + OrderLots() + ", price=" + OrderClosePrice() + ", slippage=" + config.slippage + ", err=" + GetLastError());
            ExpertRemove();
            return;
        }
    }

    // set trailing-stop if setable
    if (config.shouldSetTrailingStop) {
        for (i = 0; i < ArraySize(trailingStoppablePositionTickets); i++) {
            if (!OrderSelect(trailingStoppablePositionTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
                Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSelect, index=" + trailingStoppablePositionTickets[i] + ", select=SELECT_BY_TICKET, pool=MODE_TRADES, err=" + GetLastError());
                ExpertRemove();
                return;
            }
            const double buffer = config.trailingStopBuffer * (OrderType() == OP_BUY ? 1 : -1);
            const double stoploss = NormalizeDouble(OrderOpenPrice() + buffer, MarketInfo(config.symbol, MODE_DIGITS));
            if (!OrderModify(OrderTicket(), OrderOpenPrice(), stoploss, OrderTakeProfit(), OrderExpiration())) {
                Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderModify, ticket" + OrderTicket() + ", price=" + OrderOpenPrice() + ", stoploss=" + stoploss + ", takeprofit=" + OrderTakeProfit() + ", expiration=" + OrderExpiration() + ", err=" + GetLastError());
                ExpertRemove();
                return;
            }
        }
    }

    // open new position if needed
    if (
        config.shouldCreateOrder &&
        config.minOpenPrice <= openPrice && openPrice <= config.maxOpenPrice &&
        lowestDistance >= config.distance
    ) {
        if (OrderSend(config.symbol, config.command, config.lots, openPrice, config.slippage, 0, 0, NULL, config.magic) == -1) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSend, symbol=" + config.symbol + ", cmd=" + config.command + ", volume=" + config.lots + ", price=" + openPrice + ", slippage=" + config.slippage + ", stoploss=0, takeprofit=0, magic=" + config.magic + ", err=" + GetLastError());
            ExpertRemove();
            return;
        }
    }
}


/*****************************************************
*************        HEIKIN ASHI         *************
******************************************************/
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


/*****************************************************
*************           UTILS            *************
******************************************************/
enum COMMAND {
    BUY = OP_BUY, // Buy
    SELL = OP_SELL, // Sell
};

int getIndex(string &array[], string val) {
    int length = ArraySize(array);
    for (int i = 0; i < length; i++) {
        if (array[i] == val) {
            return i;
        }
    }
    return -1;
}

string SWAP_STRENGTH[] = { "CHF", "EUR", "JPY", "GBP", "CAD", "NZD", "AUD", "USD" };
int getAutoCommand(string symbol) {
    const int firstCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 0, 3));
    const int secondCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 3, 3));
    if (firstCurrencyIndex < 0 || secondCurrencyIndex < 0) {
        Alert("[" + _Symbol + "][getAutoCommand] Symbol is not supported");
        ExpertRemove();
    }
    if (firstCurrencyIndex >= secondCurrencyIndex) {
        return OP_BUY;
    } else {
        return OP_SELL;
    }
}

int getAutoMagic(string symbol) {
    const int firstCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 0, 3));
    const int secondCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 3, 3));
    if (firstCurrencyIndex < 0 || secondCurrencyIndex < 0) {
        Alert("[" + _Symbol + "][getAutoMagic] Symbol is not supported");
        ExpertRemove();
    }
    return firstCurrencyIndex * 10 + secondCurrencyIndex;
}

/*
bool shouldCreateOrder(int maxOpenPositions, int minDistance) {
    const int poolHisory = 0;
    const int poolTrades = 1;
    int closestPositionCount = 0;
    int closestPositionTickets[];
    int closestPositionPool[];
    int nTradePositions = OrdersTotal();
    int nHistoricalPositions = OrdersHistoryTotal();
    int i;
    for (i = nTradePositions - 1; i > nTradePositions - 1 - maxOpenPositions; i--) {

    }
}
*/
