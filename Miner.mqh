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

class Miner {
    private:
        void onCommandFailure();
    public:
        Miner();
        void onTick(MinerConfig &config);
};

Miner::Miner() {
}

void Miner::onTick(MinerConfig &config) {
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

void Miner::onCommandFailure() {
    Alert("[Miner] Error: command failure: lastError=" + GetLastError());
    ExpertRemove();
}
