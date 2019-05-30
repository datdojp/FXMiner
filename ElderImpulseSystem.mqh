class ElderImpulseSystem {
   private:
      int mH1Impulse;
      int mH4Impulse;
      int mD1Impulse;
      int getImpulse(int timeframe);
   public:
      void loadImpulses();
      ElderImpulseSystem();
      bool shouldBuy();
      bool shouldSell();
      //bool shouldCloseAllBuyOrders();
      //bool shouldCloseAllSellOrders();
};

ElderImpulseSystem::ElderImpulseSystem() {}

int ElderImpulseSystem::getImpulse(int timeframe) {
   double currentAlpha = 2.0 / (9 + 1.0);
   double previousAlpha = 1.0 - currentAlpha;
   
   int ShowBars = 100;
   if (ShowBars > Bars) {
      ShowBars = Bars;
   }
   
   double MACDLineBuffer[];
   ArrayResize(MACDLineBuffer, ShowBars);
   double SignalLineBuffer[];
   ArrayResize(SignalLineBuffer, ShowBars);
   
   for (int shift = ShowBars; shift >= 0; shift--) {
      double currentEMAStrength = iMA(Symbol(), timeframe, 13, 0, MODE_EMA, PRICE_CLOSE, shift);
      double previousEMAStrength = iMA(Symbol(), timeframe, 13, 0, MODE_EMA, PRICE_CLOSE, shift+1);
      
      MACDLineBuffer[shift] = iMA(Symbol(), timeframe, 12, 0, MODE_EMA, PRICE_CLOSE, shift) -
                              iMA(Symbol(), timeframe, 26, 0, MODE_EMA, PRICE_CLOSE, shift);
      SignalLineBuffer[shift] = currentAlpha * MACDLineBuffer[shift] +
                                previousAlpha * SignalLineBuffer[shift+1];
      
      double currentMACDStrength = MACDLineBuffer[shift] - SignalLineBuffer[shift];
      double previousMACDStrength = MACDLineBuffer[shift+1] - SignalLineBuffer[shift+1];
      
      if (shift == 0) {
         if (
            currentEMAStrength > previousEMAStrength &&
            currentMACDStrength > previousMACDStrength
         ) {
            return 1;
         }
         if (
            currentEMAStrength < previousEMAStrength &&
            currentMACDStrength < previousMACDStrength
         ) {
            return -1;
         }
         return 0;
      }
   }
   return 0;
}

void ElderImpulseSystem::loadImpulses() {
   mH1Impulse = getImpulse(PERIOD_H1);
   mH4Impulse = getImpulse(PERIOD_H4);
   mD1Impulse = getImpulse(PERIOD_D1);
}

bool ElderImpulseSystem::shouldBuy() {
   return mH1Impulse != -1 && mH4Impulse != -1 && mD1Impulse != -1 &&
          (mH1Impulse == 1 || mH4Impulse == 1 || mD1Impulse == 1);
}

bool ElderImpulseSystem::shouldSell() {
   return mH1Impulse != 1 && mH4Impulse != 1 && mD1Impulse != 1 &&
   (mH1Impulse == -1 || mH4Impulse == -1 || mD1Impulse == -1);
}

//bool ElderImpulseSystem::shouldCloseAllBuyOrders() {
//   int count = 0;
//   if (mH1Impulse == -1) count++;
//   if (mH4Impulse == -1) count++;
//   if (mH4Impulse == -1) count++;
//   return count >= 2;
//}
//
//bool ElderImpulseSystem::shouldCloseAllSellOrders() {
//   int count = 0;
//   if (mH1Impulse == 1) count++;
//   if (mH4Impulse == 1) count++;
//   if (mH4Impulse == 1) count++;
//   return count >= 2;
//}
