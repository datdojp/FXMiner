// Miner v0.1
#include "Miner.mqh";
#include "ElderImpulseSystem.mqh";

enum COMMAND {
    BUY = 1, // Buy
    SELL = 2, // Sell
    BUY_SELL = 3, // Buy & Sell
};

input double Lots = 0.01;
input int DistancePoints = 100;
input int TakeProfitPoints = 100;
input COMMAND Command = BUY_SELL;
input double BottomPrice = 0; // no limit
input double TopPrice = 1000; // no limit
input int slippage = 1;

const int MAGIC = 105906716;

Miner *buyMiner, *sellMiner;
ElderImpulseSystem *elderImpulseSystem;

void init() {
  if (Command == BUY || Command == BUY_SELL) {
     buyMiner = new Miner(Lots,
                          DistancePoints * _Point,
                          TakeProfitPoints * _Point,
                          OP_BUY,
                          BottomPrice,
                          TopPrice,
                          MAGIC);
  }
  if (Command == SELL || Command == BUY_SELL) {
     sellMiner = new Miner(Lots,
                          DistancePoints * _Point,
                          TakeProfitPoints * _Point,
                          OP_SELL,
                          BottomPrice,
                          TopPrice,
                          MAGIC);
  }
  elderImpulseSystem = new ElderImpulseSystem();
}

void OnTick() {
   elderImpulseSystem.loadImpulses();
   if (buyMiner != NULL && elderImpulseSystem.shouldBuy()) {
      buyMiner.onTick();
   }
   if (sellMiner != NULL && elderImpulseSystem.shouldSell()) {
      sellMiner.onTick();
   }
   //if (elderImpulseSystem.shouldCloseAllBuyOrders()) {
   //   closeAllOrdersOfType(OP_BUY);
   //}
   //if (elderImpulseSystem.shouldCloseAllSellOrders()) {
   //   closeAllOrdersOfType(OP_SELL);
   //}
}

//void closeAllOrdersOfType(int type) {
//    int nOrders = OrdersTotal();
//    int tickets[];
//    ArrayResize(tickets, nOrders);
//    int nTickets = 0;
//    for (int pos = 0; pos < nOrders; pos++) {
//        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
//            continue;
//        }
//        if (OrderSymbol() != _Symbol || OrderType() != type) {
//            continue;
//        }
//        tickets[nTickets] = OrderTicket();
//        nTickets++;
//    }
//    for (int i = 0; i < nTickets; i++) {
//        OrderSelect(tickets[i], SELECT_BY_TICKET, MODE_TRADES);
//        OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), slippage, clrNONE);
//    }
//}