class Martingale {
    private:
        double mPrevAsk;
        double mPrevBid;
        double mTopPrice;
        double mBottomPrice;
        double mInitialLots;
        double mMaxLots;
        double mLots;
        double mTakeProfit;
        double mAccumulatedLoss;
        int mMagic;

        void onCommandFailure();
        void onMaxLotsExceeded();
        double calcNextLots();
        double calcCeil(double val);
    public:
        Martingale(double bottomPrice, double topPrice, double takeProfit, double initialLots, double maxLots, int magic);
        void onTick();
};

Martingale::Martingale(double bottomPrice, double topPrice, double takeProfit, double initialLots, double maxLots, int magic) {
    if (topPrice < bottomPrice) {
        Alert("[Martingale] Error: 'topPrice' must be greater than 'bottomPrice'");
        ExpertRemove();
        return;
    }
    if (topPrice - bottomPrice <= Ask - Bid) {
        Alert("[Martingale] Error: corridor 's height must be greater than spread");
        ExpertRemove();
        return;
    }
    mPrevAsk = Ask;
    mPrevBid = Bid;
    mTopPrice = topPrice;
    mBottomPrice = bottomPrice;
    mInitialLots = initialLots;
    mLots = initialLots;
    mMaxLots = maxLots;
    mTakeProfit = takeProfit;
    mAccumulatedLoss = 0;
    mMagic = magic;
}

void Martingale::onTick() {
    // check if there is order opened by this EA
    bool hasOrder = false;
    for (int pos = OrdersTotal()-1; pos >= 0; pos--) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            onCommandFailure();
            return;
        }
        if (OrderSymbol() != _Symbol) { continue; }
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) { continue; }
        if (OrderMagicNumber() != mMagic) { continue; }
        hasOrder = true;
        break;
    }

    // if price crosses over topPrice => close SELL order and open BUY
    double nextLots;
    if (mPrevAsk <= mTopPrice && mTopPrice <= Ask) {
        if (hasOrder) {
            if (OrderType() == OP_SELL) {
                nextLots = calcNextLots();
                if (nextLots <= mMaxLots) {
                    if (!OrderClose(OrderTicket(), OrderLots(), Ask, slippage)) {
                        onCommandFailure();
                        return;
                    }
                    mLots = nextLots;
                    if (OrderSend(_Symbol, OP_BUY, mLots, Ask, slippage, 0, 0, NULL, mMagic) == -1) {
                        onCommandFailure();
                        return;
                    }
                } else {
                    onMaxLotsExceeded();
                    return;
                }
            }
        } else {
            if (mLots <= mMaxLots) {
                if (OrderSend(_Symbol, OP_BUY, mLots, Ask, slippage, 0, 0, NULL, mMagic) == -1) {
                    onCommandFailure();
                    return;
                }
            } else {
                onMaxLotsExceeded();
                return;
            }
        }
    // if price crosses over bottomPrice => close BUY order and open SELL
    } else if (Bid <= mBottomPrice && mBottomPrice <= mPrevBid) {
        if (hasOrder) {
            if (OrderType() == OP_BUY) {
                nextLots = calcNextLots();
                if (nextLots <= mMaxLots) {
                    if (!OrderClose(OrderTicket(), OrderLots(), Bid, slippage)) {
                        onCommandFailure();
                        return;
                    }
                    mLots = nextLots;
                    if (OrderSend(_Symbol, OP_SELL, mLots, Bid, slippage, 0, 0, NULL, mMagic) == -1) {
                        onCommandFailure();
                        return;
                    }
                } else {
                    onMaxLotsExceeded();
                    return;
                }
            }
        } else {
            if (mLots <= mMaxLots) {
                if (OrderSend(_Symbol, OP_SELL, mLots, Bid, slippage, 0, 0, NULL, mMagic) == -1) {
                    onCommandFailure();
                    return;
                }
            } else {
                onMaxLotsExceeded();
                return;
            }
        }
    // take profit
    } else if (hasOrder) {
        double profit;
        double closePrice;
        if (OrderType() == OP_BUY) {
            profit = Bid - OrderOpenPrice();
            closePrice = Bid;
        } else {
            profit = OrderOpenPrice() - Ask;
            closePrice = Ask;
        }
        if (profit >= mTakeProfit) {
            if (!OrderClose(OrderTicket(), OrderLots(), closePrice, slippage)) {
                onCommandFailure();
                return;
            }
            mLots = mInitialLots;
            Alert("[Martingale] Error: profit taken");
            ExpertRemove();
            return;
        }
    }
    mPrevAsk = Ask;
    mPrevBid = Bid;
}

void Martingale::onCommandFailure() {
    Alert("[Martingale] Error: command failure: lastError=" + GetLastError());
    ExpertRemove();
}

void Martingale::onMaxLotsExceeded() {
    Alert("[Martingale] Error: max lots exceeded");
    ExpertRemove();
}

double Martingale::calcNextLots() {
    mAccumulatedLoss += mLots * (mTopPrice - mBottomPrice);
    double expectedProfitOfNextOrder = mAccumulatedLoss + mInitialLots * mTakeProfit;
    double nextLots = expectedProfitOfNextOrder / mTakeProfit;
    double minLots = MarketInfo(_Symbol, MODE_MINLOT);
    nextLots = calcCeil(nextLots / minLots) * minLots;
    return nextLots;
}

double Martingale::calcCeil(double val) {
    if (DoubleToString(val) == DoubleToString(MathFloor(val))) {
        return MathFloor(val);
    } else {
        return MathCeil(val);
    }
}
