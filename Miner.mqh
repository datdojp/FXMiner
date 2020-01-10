struct MinerConfig {
    string symbol;
    double lots;
    double distance;
    double takeProfit;
    int command;
    bool shouldTrailingStop;
    int magic;
    int slippage;
};

class Miner {
    private:
        MinerConfig mConfig;
        void onCommandFailure();
    public:
        Miner(MinerConfig &config);
        void onTick(bool shouldCreateOrder);
};

Miner::Miner(MinerConfig &config) {
    if (config.command != OP_BUY && config.command != OP_SELL) {
        Alert("[Miner] Error: 'command' must be OP_BUY or OP_SELL");
        ExpertRemove();
        return;
    }
    mConfig = config;
}

void Miner::onTick(bool shouldCreateOrder) {
    // take profit if possible
    // also get lowest distance
    double ask = MarketInfo(mConfig.symbol, MODE_ASK);
    double bid = MarketInfo(mConfig.symbol, MODE_BID);
    double lowestDistance = 1000000;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
            return;
        }
        if (OrderSymbol() != mConfig.symbol) { continue; }
        if (OrderType() != mConfig.command) { continue; }
        if (OrderMagicNumber() != mConfig.magic) { continue; }
        double profit = OrderType() == OP_BUY ? bid - OrderOpenPrice() : OrderOpenPrice() - ask;
        double distance = OrderType() == OP_BUY ? OrderOpenPrice() - ask : bid - OrderOpenPrice();
        if (profit > mConfig.takeProfit) {
            if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), mConfig.slippage)) {
                onCommandFailure();
                return;
            }
            pos = 0;
        } else {
            if (distance < lowestDistance) {
                lowestDistance = distance;
            }
        }
    }

    if (shouldCreateOrder) {
        // send new order if lowestDistance >= distance
        if (lowestDistance >= mConfig.distance) {
            double currentPrice = mConfig.command == OP_BUY ? ask : bid;
            if (OrderSend(mConfig.symbol, mConfig.command, mConfig.lots, currentPrice, mConfig.slippage, 0, 0, NULL, mConfig.magic) == -1) {
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
