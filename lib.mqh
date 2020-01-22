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
};

void minerOnTick(MinerConfig &config) {
    // validate config
    if (config.command != OP_BUY && config.command != OP_SELL) {
        Alert("[Miner] Error: 'command' must be OP_BUY or OP_SELL");
        ExpertRemove();
        return;
    }

    int i;

    // collect data from current open postions
    double ask = MarketInfo(config.symbol, MODE_ASK);
    double bid = MarketInfo(config.symbol, MODE_BID);
    int closablePositionTickets[];
    int trailingStoppablePositionTickets[];
    double trailingStoppablePositionProfits[];
    double lowestDistance = 1000000;
    int ordersTotal = OrdersTotal();
    for (int pos = 0; pos < ordersTotal; pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
            return;
        }
        if (OrderSymbol() != config.symbol) { continue; }
        if (OrderType() != config.command) { continue; }
        if (OrderMagicNumber() != config.magic) { continue; }
        double profit = OrderType() == OP_BUY ? bid - OrderOpenPrice() : OrderOpenPrice() - ask;
        double distance = OrderType() == OP_BUY ? OrderOpenPrice() - ask : bid - OrderOpenPrice();
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
            onCommandFailure();
            return;
        }
        if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), config.slippage)) {
            onCommandFailure();
            return;
        }
    }

    // set trailing-stop if setable
    if (config.shouldSetTrailingStop) {
        for (i = 0; i < ArraySize(trailingStoppablePositionTickets); i++) {
            if (!OrderSelect(trailingStoppablePositionTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
                onCommandFailure();
                return;
            }
            const double buffer = config.trailingStopBuffer * (OrderType() == OP_BUY ? 1 : -1);
            const double stoploss = NormalizeDouble(OrderOpenPrice() + buffer, MarketInfo(config.symbol, MODE_DIGITS));
            if (!OrderModify(OrderTicket(), OrderOpenPrice(), stoploss, OrderTakeProfit(), OrderExpiration())) {
                onCommandFailure();
                return;
            }
        }
    }

    // open new position if needed
    if (config.shouldCreateOrder) {
        if (lowestDistance >= config.distance) {
            double currentPrice = config.command == OP_BUY ? ask : bid;
            if (OrderSend(config.symbol, config.command, config.lots, currentPrice, config.slippage, 0, 0, NULL, config.magic) == -1) {
                onCommandFailure();
                return;
            }
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
void onCommandFailure() {
    Alert("[Miner] Error: command failure: lastError=" + GetLastError());
    ExpertRemove();
}
