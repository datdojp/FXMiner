class Martingale {
    private:
        bool mStopped;
        int mStopReason;
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
        double calcNextLots();
        double calcCeil(double val);
    public:
        static const int STOP_REASON_CMD_FAILURE;
        static const int STOP_REASON_MAX_LOTS_EXCEEDED;
        static const int STOP_REASON_PROFIT_TAKEN;
        static const int STOP_REASON_INVALID_ARGUMENTS;
        Martingale(double bottomPrice, double topPrice, double takeProfit, double initialLots, double maxLots, int magic);
        void onTick();
        bool isStopped();
        int getStopReason();
};

const int Martingale::STOP_REASON_CMD_FAILURE = 0;
const int Martingale::STOP_REASON_MAX_LOTS_EXCEEDED = 1;
const int Martingale::STOP_REASON_PROFIT_TAKEN = 2;
const int Martingale::STOP_REASON_INVALID_ARGUMENTS = 3;

Martingale::Martingale(double _bottomPrice, double _topPrice, double _takeProfit, double _initialLots, double _maxLots, int _magic) {
    if (_topPrice < _bottomPrice) {
        Alert("Error: 'topPrice' must be greater than 'bottomPrice'");
        mStopped = true;
        mStopReason = STOP_REASON_INVALID_ARGUMENTS;
        return;
    }
    if (_topPrice - _bottomPrice <= Ask - Bid) {
        Alert("Error: corridor 's height must be greater than spread");
        mStopped = true;
        mStopReason = STOP_REASON_INVALID_ARGUMENTS;
        return;
    }
    mStopped = false;
    mStopReason = -1;
    mPrevAsk = Ask;
    mPrevBid = Bid;
    mTopPrice = _topPrice;
    mBottomPrice = _bottomPrice;
    mInitialLots = _initialLots;
    mLots = _initialLots;
    mMaxLots = _maxLots;
    mTakeProfit = _takeProfit;
    mAccumulatedLoss = 0;
    mMagic = _magic;
}

void Martingale::onTick() {
    if (mStopped) {
        return;
    }

    // check if there is order opened by this EA
    bool hasOrder = false;
    for (int pos = OrdersTotal()-1; pos >= 0; pos--) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            mStopped = true;
            mStopReason = STOP_REASON_CMD_FAILURE;
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
                        mStopped = true;
                        mStopReason = STOP_REASON_CMD_FAILURE;
                        return;
                    }
                    mLots = nextLots;
                    if (OrderSend(_Symbol, OP_BUY, mLots, Ask, slippage, 0, 0, NULL, mMagic) == -1) {
                        mStopped = true;
                        mStopReason = STOP_REASON_CMD_FAILURE;
                        return;
                    }
                } else {
                    mStopped = true;
                    mStopReason = STOP_REASON_MAX_LOTS_EXCEEDED;
                    return;
                }
            }
        } else {
            if (mLots <= mMaxLots) {
                if (OrderSend(_Symbol, OP_BUY, mLots, Ask, slippage, 0, 0, NULL, mMagic) == -1) {
                    mStopped = true;
                    mStopReason = STOP_REASON_CMD_FAILURE;
                    return;
                }
            } else {
                mStopped = true;
                mStopReason = STOP_REASON_MAX_LOTS_EXCEEDED;
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
                        mStopped = true;
                        mStopReason = STOP_REASON_CMD_FAILURE;
                        return;
                    }
                    mLots = nextLots;
                    if (OrderSend(_Symbol, OP_SELL, mLots, Bid, slippage, 0, 0, NULL, mMagic) == -1) {
                        mStopped = true;
                        mStopReason = STOP_REASON_CMD_FAILURE;
                        return;
                    }
                } else {
                    mStopped = true;
                    mStopReason = STOP_REASON_MAX_LOTS_EXCEEDED;
                    return;
                }
            }
        } else {
            if (mLots <= mMaxLots) {
                if (OrderSend(_Symbol, OP_SELL, mLots, Bid, slippage, 0, 0, NULL, mMagic) == -1) {
                    mStopped = true;
                    mStopReason = STOP_REASON_CMD_FAILURE;
                    return;
                }
            } else {
                mStopped = true;
                mStopReason = STOP_REASON_MAX_LOTS_EXCEEDED;
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
                mStopped = true;
                mStopReason = STOP_REASON_CMD_FAILURE;
                return;
            }
            mLots = initialLots;
            mStopped = true;
            mStopReason = STOP_REASON_PROFIT_TAKEN;
            return;
        }
    }
    mPrevAsk = Ask;
    mPrevBid = Bid;
}

bool Martingale::isStopped() {
    return mStopped;
}

int Martingale::getStopReason() {
    return mStopReason;
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

