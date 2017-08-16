#property strict

extern double priceDiffBetweenOrders = 100;
extern double priceDiffToTakeProfit = 100;
extern int amount = 1000;
extern double maxPrice = 118;
extern double minPrice = 108;
extern double minMarginLevel = 150;
extern int slippage = 3;
extern bool verbose = false;
extern bool sendMail = true;

const string version = "1.4";

int init() {
   return(0);
}

int deinit() {
   return(0);
}

int start() {
   // convert amount to lots
   const double lots = amount / MarketInfo(Symbol(), MODE_LOTSIZE);
   
   // email subject and text to send if `sendMail` is enabled
   string emailSubject, emailText;
   if (sendMail) {
      emailSubject = StringConcatenate("[TA001] Account change notification");
      emailText = StringConcatenate("Version: ", version, "\n",
                                    "Market status: ", "Ask=", Ask, ", ",
                                                       "Bid=",  Bid, "\n",
                                    "Account status: ", "MarginLevel=", formatDouble(getMarginLevel(), 0), "%, "
                                                        "AccountBalance=", formatDouble(AccountBalance(), 0),
                                    "\n---");
   }

   if (verbose) {
      Print("start() -> begin: version=", version);
      Print("Current status: ", "Ask=", Ask, ", ",
                                "Bid=", Bid, ", ",
                                "MarginLevel=", getMarginLevel(), "%");
   }

   // iterate all orders
   int nOrders = OrdersTotal();
   if (verbose) {
      Print("nOrders=", nOrders);
   }
   int nOrderWillBeClosed = 0;
   int ordersWillBeClosed_Ticket[];
   ArrayResize(ordersWillBeClosed_Ticket, nOrders);
   double ordersWillBeClosed_ClosePrice[];
   ArrayResize(ordersWillBeClosed_ClosePrice, nOrders);
   int nearestBuyOrder_Ticket = -1;
   double nearestBuyOrder_OpenPriceDiff = 0;
   int nearestSellOrder_Ticket = -1;
   double nearestSellOrder_OpenPriceDiff = 0;
   for (int pos = 0; pos < nOrders; pos++) {
      // select order
      if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
         if (verbose) {
            Print("Failed to select order: pos=", pos);
         }
         continue;
      }
      
      // check order match current symbol and magic number
      if (OrderSymbol() != _Symbol) {
         if (verbose) {
            Print("Ignored order due to different symbol: ", "pos=", pos, ", ",
                                                             "ticket=", OrderTicket(), ", ",
                                                             "OrderSymbol=", OrderSymbol());
         }                         
         continue;
      }
      
      // extract information of selected order
      const int type = OrderType();
      if (type != OP_BUY && type != OP_SELL) {
         if (verbose) {
            Print("Ignored order due to invalid type: ", "pos=", pos, ", ",
                                                         "ticket=", OrderTicket(), ", ",
                                                         "OrderType=", type);
         } 
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
 
   // flag to indicate that there is new action (close/open order)
   bool changed = false;

   // close orders to take profit
   if (verbose) {
      Print("nOrderWillBeClosed=", nOrderWillBeClosed);
   }
   for (int i = 0; i < nOrderWillBeClosed; i++) {
      const int orderTicket = ordersWillBeClosed_Ticket[i];
      const double closePrice = ordersWillBeClosed_ClosePrice[i];
      if (!OrderSelect(orderTicket, SELECT_BY_TICKET, MODE_TRADES)) {
         if (verbose) {
            Print("Failed to select order to take profit: ticket=", orderTicket);
         }
         continue;
      }
      const double orderLots = OrderLots();
      const int orderType = OrderType();
      if (OrderClose(orderTicket, orderLots, closePrice, slippage, clrNONE)) {
         if (sendMail) {
            emailText = StringConcatenate(emailText, "\n", "Closed order: ", "ticket=", orderTicket, ", ",
                                                                             "type=", getTypeString(orderType), ", ",
                                                                             "lots=", orderLots, ", ",
                                                                             "openPrice=", OrderOpenPrice(), ", ",
                                                                             "closePrice=", closePrice, ", ",
                                                                             "expectedProfit=", OrderProfit());
         }
         changed = true;
      } else {
         if (verbose) {
            Print("Failed to close order: ", "ticket=", orderTicket, ", ",
                                             "type=", getTypeString(orderType), ", ",
                                             "lots=", orderLots, ", ",
                                             "openPrice=", OrderOpenPrice(),
                                             "closePrice=", closePrice, ", ",
                                             "lastError=", GetLastError());
         }
      }
   }

   // check margin level
   if (!hasEnoughMarginLevel()) {
      if (changed && sendMail) {
         reportByEmail(emailSubject, emailText);
      }
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
         n = (int) MathMax(0, MathFloor(-nearestBuyOrder_OpenPriceDiff / priceDiffBetweenOrders));
      }
      if (verbose) {
         Print("Number of order to buy: ", n);
      }
      for (int i = 0; i < n; i++) {
         if (OrderSend(_Symbol, OP_BUY, lots, Ask, slippage, 0, 0) == -1) {
            if (verbose) {
               Print("Failed to open order: ", "type=BUY", ", ",
                                               "lots=", lots, ", ",
                                               "price=", Ask, ", ",
                                               "lastError=", GetLastError());
            }
         } else {
            if (sendMail) {
               emailText = StringConcatenate(emailText, "\n", "Opened order: ", "type=BUY", ", ",
                                                                                "lots=", lots, ", ",
                                                                                "price=", Ask);
            }
            changed = true;
            if (!hasEnoughMarginLevel()) {
               if (changed && sendMail) {
                  reportByEmail(emailSubject, emailText);
               }
               return(0);
            }
         }
      }
   } else {
      if (verbose) {
         Print("Buy is not allowed because price is out of range:", " ask=", Ask);
      }
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
         n = (int) MathMax(0, MathFloor(-nearestSellOrder_OpenPriceDiff / priceDiffBetweenOrders));
      }
      if (verbose) {
         Print("Number of order to sell: ", n);
      }
      for (int i = 0; i < n; i++) {
         if (OrderSend(_Symbol, OP_SELL, lots, Bid, slippage, 0, 0) == -1) {
            if (verbose) {
               Print("Failed to open order: ", "type=SELL", ", ",
                                               "lots=", lots, ", ",
                                               "price=", Bid, ", ",
                                               "lastError=", GetLastError()); 
            }
         } else {
            if (sendMail) {
               emailText = StringConcatenate(emailText, "\n", "Opened order: ", "type=SELL", ", ",
                                                                                "lots=", lots, ", ",
                                                                                "price=", Bid);
            }
            changed = true;
            if (!hasEnoughMarginLevel()) {
               if (changed && sendMail) {
                  reportByEmail(emailSubject, emailText);
               }
               return(0);
            }
         }
      }
   } else {
      if (verbose) {
         Print("Sell is not allowed because price is out of range:", " bid=", Bid);
      }
   }

   if (changed) {
      if (verbose) {
         Print("New margin level: ", getMarginLevel(), "%");
      }
      if (sendMail) {
         reportByEmail(emailSubject, emailText);
      }
   }

   if (verbose) {
      Print("start() -> end");
   }

   // done
   return(0);
}

void reportByEmail(string emailSubject, string emailText) {
   emailText = StringConcatenate(emailText, "\n---\n", "Account status: ", "MarginLevel=", formatDouble(getMarginLevel(), 0), "%, ",
                                                                           "AccountBalance=", formatDouble(AccountBalance(), 0));
   SendMail(emailSubject, emailText);
}

bool hasEnoughMarginLevel() {
   const double marginLevel = getMarginLevel();
   if (marginLevel != 0 && marginLevel < minMarginLevel) {
      if (verbose) {
         Print("Margin level too low: ", marginLevel, "%");
      }
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

// Reference:https://www.mql5.com/en/forum/137852#comment_3494445
string formatDouble(double number, int precision, string pcomma=",", string ppoint=".") {
   string snum   = DoubleToStr(number,precision);
   int    decp   = StringFind(snum,".",0);
   string sright = StringSubstr(snum,decp+1,precision);
   string sleft  = StringSubstr(snum,0,decp);
   string formated = "";
   string comma    = "";
   
      while (StringLen(sleft)>3)
      {
         int    length = StringLen(sleft);
         string part   = StringSubstr(sleft,length-3,0);
              formated = part+comma+formated;
              comma    = pcomma;
              sleft    = StringSubstr(sleft,0,length-3);
      }
      
      if (sleft!="")   formated = sleft+comma+formated;
      if (precision>0) formated = formated+ppoint+sright;
   return(formated);
}
