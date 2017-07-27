#property strict

extern double priceDiffBetweenOrders = 100;
extern double priceDiffToTakeProfit = 100;
extern int amount = 1000;
extern double maxPrice = 118;
extern double minPrice = 108;
extern double minMarginLevel = 150;
extern int slippage = 3;
extern bool verbose = true;

const string version = "1.1";

int init() {
   return(0);
}

int deinit() {
   return(0);
}

int start() {
   // convert amount to lots
   const double lots = amount / MarketInfo(Symbol() ,MODE_LOTSIZE);

   if (verbose) {
      Print("start() -> begin: version=", version);
      Print("Ask=", Ask, ", Bid=", Bid, ", MarginLevel=", getMarginLevel());
   }

   // check if symbole is USDJPY
   if (StringFind(_Symbol, "USDJPY", 0) == -1) {
      Alert("This EA is for USDJPY only");
      return(0);
   }
   
   // iterate all orders
   int nOrders = OrdersTotal();
   if (verbose) {
      Print("nOrders=", nOrders);
   }
   int nOrderWillBeClosed = 0;
   int ordersWillBeClosed_Ticket[];
   ArrayResize(ordersWillBeClosed_Ticket, nOrders);
   double ordersWillBeClosed_Losts[];
   ArrayResize(ordersWillBeClosed_Losts, nOrders);
   double ordersWillBeClosed_ClosePrice[];
   ArrayResize(ordersWillBeClosed_ClosePrice, nOrders);
   int nearestBuyOrder_Ticket = -1;
   double nearestBuyOrder_OpenPriceDiff = 0;
   int nearestSellOrder_Ticket = -1;
   double nearestSellOrder_OpenPriceDiff = 0;
   for (int pos = 0; pos < nOrders; pos++) {
      // check order match current symbol and magic number
      if (
         !OrderSelect(pos, SELECT_BY_POS, MODE_TRADES) ||
         OrderSymbol() != _Symbol
      ) {
         Print("Ignored order: ", "pos=", pos, ", ",
                                  "Symbol=", _Symbol, ", ",
                                  "ticket=", OrderTicket(), ", ",
                                  "type=", getTypeString(OrderType()), ", ",
                                  "openPrice=", OrderOpenPrice());
                                  
         continue;
      }
      
      // extract information of selected order
      const int type = OrderType();
      if (type != OP_BUY && type != OP_SELL) {
         continue;
      }
      double openPrice = OrderOpenPrice();
      double openPriceDiff;
      double currentClosePrice;
      double closePriceDiff;
      if (type == OP_BUY) {
         openPriceDiff = Ask - openPrice;
         closePriceDiff = Bid - openPrice;
         currentClosePrice = Bid;
      } else if (type == OP_SELL) {
         openPriceDiff = openPrice - Bid;
         closePriceDiff = openPrice - Ask;
         currentClosePrice = Ask;
      }
      openPriceDiff = openPriceDiff / _Point;
      closePriceDiff = closePriceDiff / _Point;
      const int ticket = OrderTicket();
      if (verbose) {
         Print("Order: ", "pos=", pos, ", ",
                          "ticket=", ticket, ", ",
                          "type=", getTypeString(type), ", ",
                          "openPrice=", openPrice, ", ",
                          "currentClosePrice=", currentClosePrice, ", ",
                          "openPriceDiff=", openPriceDiff, ", ",
                          "closePriceDiff=", closePriceDiff);
      }
      
      // if order already reached its exptected profit, close it
      if (closePriceDiff > priceDiffToTakeProfit) {
         ordersWillBeClosed_Ticket[nOrderWillBeClosed] = ticket;
         ordersWillBeClosed_Losts[nOrderWillBeClosed] = OrderLots();
         ordersWillBeClosed_ClosePrice[nOrderWillBeClosed] = currentClosePrice;
         nOrderWillBeClosed++;
         continue;
      }

      // store nearest buy order
      if (type == OP_BUY) {
         if (
            nearestBuyOrder_Ticket == -1 ||
            nearestBuyOrder_OpenPriceDiff < openPriceDiff
         ) {
            nearestBuyOrder_Ticket = ticket;
            nearestBuyOrder_OpenPriceDiff = openPriceDiff;
         }
      }
      
      // store nearest sell order
      if (type == OP_SELL) {
         if (
            nearestSellOrder_Ticket == -1 ||
            nearestSellOrder_OpenPriceDiff < openPriceDiff
         ) {
            nearestSellOrder_Ticket = ticket;
            nearestSellOrder_OpenPriceDiff = openPriceDiff;
         }
      }
   }
 
   // close orders to take profit
   if (verbose) {
      Print("nOrderWillBeClosed=", nOrderWillBeClosed);
   }
   for (int i = 0; i < nOrderWillBeClosed; i++) {
      int orderTicket = ordersWillBeClosed_Ticket[i];
      double orderLots = ordersWillBeClosed_Losts[i];
      double closePrice = ordersWillBeClosed_ClosePrice[i];
      if (!OrderClose(orderTicket, orderLots, closePrice, slippage, clrNONE)) {
         Alert("Failed to close order: ", "ticket=", orderTicket, ", ",
                                          "lots=", orderLots, ", ",
                                          "closePrice=", closePrice, ", ",
                                          "lastError=", GetLastError());
      }
   }

   // check margin level
   if (!hasEnoughMarginLevel()) {
      return(0);
   }

   // counter for new orders
   int nNewOrders = 0;

   // buy if needed
   if (verbose) {
      Print("nearestBuyOrder_Ticket=", nearestBuyOrder_Ticket, ", ",
            "nearestBuyOrder_OpenPriceDiff=", nearestBuyOrder_OpenPriceDiff, ", ");
   }
   if (minPrice <= Ask && Ask <= maxPrice) {
      int n;
      if (nearestBuyOrder_Ticket == -1) {
         n = 1;
      } else {
         n = (int) MathFloor(-nearestBuyOrder_OpenPriceDiff / priceDiffBetweenOrders);
      }
      if (verbose) {
         Print("Number of order to buy: ", n);
      }
      for (int i = 0; i < n; i++) {
         if (OrderSend(_Symbol, OP_BUY, lots, Ask, slippage, 0, 0) == -1) {
            Print("Failed to buy:", " lots=", lots, ", Ask=", Ask, ", lastError=", GetLastError());
         } else {
            nNewOrders++;
            if (!hasEnoughMarginLevel()) {
               return(0);
            }
         }
      }
   } else {
      Alert("Buy is not allowed because price is out of range:", " ask=", Ask);
   }
   
   // sell if needed
    if (verbose) {
      Print("nearestSellOrder_Ticket=", nearestSellOrder_Ticket, ", ",
            "nearestSellOrder_OpenPriceDiff=", nearestSellOrder_OpenPriceDiff);
   }
   if (minPrice <= Bid && Bid <= maxPrice) {
      int n;
      if (nearestSellOrder_Ticket == -1) {
         n = 1;
      } else {
         n = (int) MathFloor(-nearestSellOrder_OpenPriceDiff / priceDiffBetweenOrders);
      }
      if (verbose) {
         Print("Number of order to sell: ", n);
      }
      for (int i = 0; i < n; i++) {
         if (OrderSend(_Symbol, OP_SELL, lots, Bid, slippage, 0, 0) == -1) {
            Print("Failed to sell:", " lots=", lots, ", Bid=", Bid, ", lastError=", GetLastError()); 
         } else {
            nNewOrders++;
            if (!hasEnoughMarginLevel()) {
               return(0);
            }
         }
      }
   } else {
      Print("Sell is not allowed because price is out of range:", " bid=", Bid);
   }

   if (nNewOrders > 0) {
      if (verbose) {
         Print("New margin level: ", getMarginLevel());
      }
   }

   if (verbose) {
      Print("start() -> end");
   }

   // done
   return(0);
}

bool hasEnoughMarginLevel() {
   const double marginLevel = getMarginLevel();
   if (marginLevel != 0 && marginLevel < minMarginLevel) {
      Alert("Margin level too low: ", marginLevel);
      return(false);
   } else {
      return true;
   }
}

double getMarginLevel() {
   return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
}

string getTypeString(int type) {
   if (type == OP_BUY) {
      return "BUY";
   } else if (type == OP_SELL) {
      return "SELL";
   }
   return "UNKNOWN";
}
