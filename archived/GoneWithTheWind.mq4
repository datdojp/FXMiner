#property strict

extern double lots = 0.01;
extern int bufferPoints = 2;
extern int takeProfitPoints = 100;
extern int slippage = 1;
extern int version = 4;

int failureCount = 0;
bool hasLoss = false;
bool prevHasLoss = false;
const int failureTolerance = 0;

void OnTick() {
    int ticket = -1;
    for (int pos = 0; pos < OrdersTotal(); pos++) {
        OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != _Symbol) {
            continue;
        }
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) {
            continue;
        }
        ticket = OrderTicket();
        break;
    }
    if (ticket != -1) {
        OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
        const int type = OrderType();
        double profitPoints;
        if (type == OP_BUY) {
            profitPoints = (Bid - OrderOpenPrice()) / _Point;
        } else { // type == OP_SELL
            profitPoints = (OrderOpenPrice() - Ask) / _Point;
        }
        const int compensationPoints = MarketInfo(_Symbol, MODE_SPREAD) + bufferPoints;
        if (-compensationPoints <= profitPoints && profitPoints <= 0 ) {
            return;
        }
        hasLoss = profitPoints < -compensationPoints;
        // if (hasLoss) {
        //     Print("===Hass loss: tolerance=", failureCount, "/", failureTolerance, ", loss=", OrderProfit(), ", holdingTime=", OrderOpenTime() - TimeCurrent());
        // }
        if (hasLoss != prevHasLoss) {
            if (hasLoss) {
                failureCount++;
                if (failureCount > failureTolerance) {
                    OrderClose(OrderTicket(), OrderLots(), type == OP_BUY ? Bid : Ask, slippage);
                    OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS, MODE_HISTORY);
                    Print("===SL: ", OrderProfit());
                    OrderSend(_Symbol, type == OP_BUY ? OP_SELL : OP_BUY, lots, type == OP_BUY ? Bid : Ask, slippage, 0, 0);
                    failureCount = 0;
                    hasLoss = false;
                }
            } else if (failureCount > 0 && profitPoints > takeProfitPoints / 10) {
                OrderClose(OrderTicket(), OrderLots(), type == OP_BUY ? Bid : Ask, slippage);
                OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS, MODE_HISTORY);
                Print("===TP: ", OrderProfit());
                OrderSend(_Symbol, type == OP_BUY ? OP_SELL : OP_BUY, lots, type == OP_BUY ? Bid : Ask, slippage, 0, 0);
                failureCount = 0;
                hasLoss = false;
            }
        } else if (profitPoints >= takeProfitPoints) {
            OrderClose(OrderTicket(), OrderLots(), type == OP_BUY ? Bid : Ask, slippage);
            OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS, MODE_HISTORY);
            Print("===TP: ", OrderProfit());
            OrderSend(_Symbol, type == OP_BUY ? OP_SELL : OP_BUY, lots, type == OP_BUY ? Bid : Ask, slippage, 0, 0);
            failureCount = 0;
            hasLoss = false;
        } else if (profitPoints < -takeProfitPoints / 5) {
            OrderClose(OrderTicket(), OrderLots(), type == OP_BUY ? Bid : Ask, slippage);
            OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS, MODE_HISTORY);
            Print("===SL: ", OrderProfit());
            OrderSend(_Symbol, type == OP_BUY ? OP_SELL : OP_BUY, lots, type == OP_BUY ? Bid : Ask, slippage, 0, 0);
            failureCount = 0;
            hasLoss = false;
        }
        prevHasLoss = hasLoss;
    } else {
        OrderSend(_Symbol, OP_BUY, lots, Ask, slippage, 0, 0);
        prevHasLoss = false;
    }
}
