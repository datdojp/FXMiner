class Miner {
    private:
        double mLots;
        double mDistance;
        double mTakeProfit;
        int mCommand;
        double mBottomPrice;
        double mTopPrice;
        int mMagic;

        void onCommandFailure();
    public:
        Miner(double lots, double distance, double takeProfit, int command, double bottomPrice, double topPrice, int magic);
        void onTick();
};

Miner::Miner(double lots, double distance, double takeProfit, int command, double bottomPrice, double topPrice, int magic) {
    if (command != OP_BUY && command != OP_SELL) {
        Alert("[Miner] Error: 'command' must be OP_BUY or OP_SELL");
        ExpertRemove();
        return;
    }
    if (topPrice < bottomPrice) {
        Alert("[Miner] Error: 'topPrice' must be greater than 'bottomPrice'");
        ExpertRemove();
        return;
    }
    mLots = lots;
    mDistance = distance;
    mTakeProfit = takeProfit;
    mCommand = command;
    mBottomPrice = bottomPrice;
    mTopPrice = topPrice;
    mMagic = magic;
}

Miner::onTick() {
    // take profit if possible
    // also get lowest distance
    double lowestDistance = 1000000;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
            return;
        }
        if (OrderSymbol() != _Symbol) { continue; }
        if (OrderType() != mCommand) { continue; }
        if (OrderMagicNumber() != mMagic) { continue; }
        double profit = OrderType() == OP_BUY ? Bid - OrderOpenPrice() : OrderOpenPrice() - Ask;
        double distance = OrderType() == OP_BUY ? OrderOpenPrice() - Ask : Bid - OrderOpenPrice();
        if (profit > mTakeProfit) {
            if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), slippage)) {
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

    // send new order if lowestDistance >= distance
    if (lowestDistance >= mDistance) {
        double currentPrice = mCommand == OP_BUY ? Ask : Bid;
        if (mBottomPrice <= currentPrice && currentPrice <= mTopPrice) {
            if (OrderSend(_Symbol, mCommand, mLots, currentPrice, slippage, 0, 0, NULL, mMagic) == -1) {
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
