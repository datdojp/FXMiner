class Martingale {
    private:
        bool mStopped;
        int mStopReason;
        double mPrevAsk;
        double mPrevBid;
        double mTopPrice;
        double mBottomPrice;
        double mLots;
        double mTakeProfitPoints;
        int mMagic;
    public:
        static const int STOP_REASON_CMD_FAILURE;
        static const int STOP_REASON_MAX_LOTS_EXCEEDED;
        static const int STOP_REASON_PROFIT_TAKEN;
        Martingale(double topPrice, double bottomPrice, int magic);
        void onTick();
        bool isStopped();
        int getStopReason();
};

const int Martingale::STOP_REASON_CMD_FAILURE = 0;
const int Martingale::STOP_REASON_MAX_LOTS_EXCEEDED = 1;
const int Martingale::STOP_REASON_PROFIT_TAKEN = 2;

Martingale::Martingale(double bottomPrice, double topPrice, int magic) {
    mStopped = false;
    mStopReason = -1;
    mPrevAsk = Ask;
    mPrevBid = Bid;
    mTopPrice = topPrice;
    mBottomPrice = bottomPrice;
    mLots = initialLots;
    mTakeProfitPoints = takeProfitPoints;
    mMagic = magic;
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
    if (mPrevAsk <= mTopPrice && mTopPrice <= Ask) {
        if (hasOrder) {
            if (OrderType() == OP_SELL) {
                double nextLots = mLots * 2;
                if (nextLots <= maxLots) {
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
                }
            }
        } else {
            if (mLots <= maxLots) {
                if (OrderSend(_Symbol, OP_BUY, mLots, Ask, slippage, 0, 0, NULL, mMagic) == -1) {
                    mStopped = true;
                    mStopReason = STOP_REASON_CMD_FAILURE;
                    return;
                }
            } else {
                mStopped = true;
                mStopReason = STOP_REASON_MAX_LOTS_EXCEEDED;
            }
        }
    // if price crosses over bottomPrice => close BUY order and open SELL
    } else if (Bid <= mBottomPrice && mBottomPrice <= mPrevBid) {
        if (hasOrder) {
            if (OrderType() == OP_BUY) {
                if (!OrderClose(OrderTicket(), OrderLots(), Bid, slippage)) {
                    mStopped = true;
                    mStopReason = STOP_REASON_CMD_FAILURE;
                    return;
                }
                mLots *= 2;
                if (mLots <= maxLots) {
                    if (OrderSend(_Symbol, OP_SELL, mLots, Bid, slippage, 0, 0, NULL, mMagic) == -1) {
                        mStopped = true;
                        mStopReason = STOP_REASON_CMD_FAILURE;
                        return;
                    }
                } else {
                    mStopped = true;
                    mStopReason = STOP_REASON_MAX_LOTS_EXCEEDED;
                }
            }
        } else {
            if (mLots <= maxLots) {
                if (OrderSend(_Symbol, OP_SELL, mLots, Bid, slippage, 0, 0, NULL, mMagic) == -1) {
                    mStopped = true;
                    mStopReason = STOP_REASON_CMD_FAILURE;
                    return;
                }
            } else {
                mStopped = true;
                mStopReason = STOP_REASON_MAX_LOTS_EXCEEDED;
            }
        }
    // take profit
    } else if (hasOrder) {
        double profitPoints;
        double closePrice;
        if (OrderType() == OP_BUY) {
            profitPoints = (Bid - OrderOpenPrice()) / _Point;
            closePrice = Bid;
        } else {
            profitPoints = (OrderOpenPrice() - Ask) / _Point;
            closePrice = Ask;
        }
        if (profitPoints >= mTakeProfitPoints) {
            if (!OrderClose(OrderTicket(), OrderLots(), closePrice, slippage)) {
                mStopped = true;
                mStopReason = STOP_REASON_CMD_FAILURE;
                return;
            }
            mLots = initialLots;
            mStopped = true;
            mStopReason = STOP_REASON_PROFIT_TAKEN;
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
