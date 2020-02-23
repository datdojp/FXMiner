/*****************************************************
*************           MINER            *************
******************************************************/
struct MinerConfig {
    string symbol;
    double lots;
    double distance;
    double takeProfit;
    int command;
    int magic;
    int slippage;

    bool shouldCreateOrder;

    bool shouldSetTrailingStop;
    double trailingStopMinDistance;
    double trailingStopBuffer;

    double minOpenPrice;
    double maxOpenPrice;
};

void minerOnTick(MinerConfig &config) {
    int i;

    // collect data from current open postions
    double ask = MarketInfo(config.symbol, MODE_ASK);
    double bid = MarketInfo(config.symbol, MODE_BID);
    double openPrice = config.command == OP_BUY ? ask : bid;
    double closePrice = config.command == OP_BUY ? bid : ask;
    double sign = config.command == OP_BUY ? 1 : -1;
    int closablePositionTickets[];
    int trailingStoppablePositionTickets[];
    double trailingStoppablePositionProfits[];
    double lowestDistance = 1000000;
    int ordersTotal = OrdersTotal();
    for (int pos = 0; pos < ordersTotal; pos++) {
        if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSelect, index=" + pos + ", select=SELECT_BY_POS, pool=MODE_TRADES, err=" + GetLastError());
            ExpertRemove();
            return;
        }
        if (OrderSymbol() != config.symbol) { continue; }
        if (OrderType() != config.command) { continue; }
        if (config.magic > 0 && OrderMagicNumber() != config.magic) { continue; }
        double profit = sign * (closePrice - OrderOpenPrice());
        double distance = MathAbs(OrderOpenPrice() - openPrice);
        if (profit > config.takeProfit) {
            ArrayResize(closablePositionTickets, ArraySize(closablePositionTickets) + 1);
            closablePositionTickets[ArraySize(closablePositionTickets) - 1] = OrderTicket();
        } else {
            if (profit >= config.trailingStopMinDistance && OrderStopLoss() == 0) {
                ArrayResize(trailingStoppablePositionTickets, ArraySize(trailingStoppablePositionTickets) + 1);
                ArrayResize(trailingStoppablePositionProfits, ArraySize(trailingStoppablePositionTickets));
                trailingStoppablePositionTickets[ArraySize(trailingStoppablePositionTickets) - 1] = OrderTicket();
                trailingStoppablePositionProfits[ArraySize(trailingStoppablePositionTickets) - 1] = profit;
            }
            if (distance < lowestDistance) {
                lowestDistance = distance;
            }
        }
    }

    // close tickets if closable
    for (i = 0; i < ArraySize(closablePositionTickets); i++) {
        if (!OrderSelect(closablePositionTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSelect, index=" + closablePositionTickets[i] + ", select=SELECT_BY_TICKET, pool=MODE_TRADES, err=" + GetLastError());
            ExpertRemove();
            return;
        }
        if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), config.slippage)) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderClose, ticket=" + OrderTicket() + ", lots=" + OrderLots() + ", price=" + OrderClosePrice() + ", slippage=" + config.slippage + ", err=" + GetLastError());
            ExpertRemove();
            return;
        }
    }

    // set trailing-stop if setable
    if (config.shouldSetTrailingStop) {
        for (i = 0; i < ArraySize(trailingStoppablePositionTickets); i++) {
            if (!OrderSelect(trailingStoppablePositionTickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
                Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSelect, index=" + trailingStoppablePositionTickets[i] + ", select=SELECT_BY_TICKET, pool=MODE_TRADES, err=" + GetLastError());
                ExpertRemove();
                return;
            }
            const double buffer = config.trailingStopBuffer * (OrderType() == OP_BUY ? 1 : -1);
            const double stoploss = NormalizeDouble(OrderOpenPrice() + buffer, MarketInfo(config.symbol, MODE_DIGITS));
            if (!OrderModify(OrderTicket(), OrderOpenPrice(), stoploss, OrderTakeProfit(), OrderExpiration())) {
                Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderModify, ticket" + OrderTicket() + ", price=" + OrderOpenPrice() + ", stoploss=" + stoploss + ", takeprofit=" + OrderTakeProfit() + ", expiration=" + OrderExpiration() + ", err=" + GetLastError());
                ExpertRemove();
                return;
            }
        }
    }

    // open new position if needed
    if (
        config.shouldCreateOrder &&
        config.minOpenPrice <= openPrice && openPrice <= config.maxOpenPrice &&
        lowestDistance >= config.distance
    ) {
        if (OrderSend(config.symbol, config.command, config.lots, openPrice, config.slippage, 0, 0, NULL, config.magic) == -1) {
            Alert("[" + _Symbol + "][minerOnTick] Command failure: command=OrderSend, symbol=" + config.symbol + ", cmd=" + config.command + ", volume=" + config.lots + ", price=" + openPrice + ", slippage=" + config.slippage + ", stoploss=0, takeprofit=0, magic=" + config.magic + ", err=" + GetLastError());
            ExpertRemove();
            return;
        }
    }
}


/*****************************************************
*************        HEIKIN ASHI         *************
******************************************************/
struct HeikinAshiBar {
  double open;
  double high;
  double low;
  double close;
};

void getHeikinAshiBars(string symbol, int timeframe, int count, HeikinAshiBar &bars[]) {
  count = MathMin(iBars(symbol, timeframe), count);
  ArrayResize(bars, count);
  for (int i = count-1; i >= 0; i--) {
    HeikinAshiBar bar = {};
    HeikinAshiBar prevBar = {};
    if (i == count - 1) {
      prevBar.open = iOpen(symbol, timeframe, i+1);
      prevBar.high = iHigh(symbol, timeframe, i+1);
      prevBar.low = iLow(symbol, timeframe, i+1);
      prevBar.close = iClose(symbol, timeframe, i+1);
    } else {
      prevBar = bars[i+1];
    }
    bar.open = (prevBar.open + prevBar.close) / 2;
    bar.close = (iOpen(symbol, timeframe, i) + iHigh(symbol, timeframe, i) + iLow(symbol, timeframe, i) + iClose(symbol, timeframe, i)) / 4;
    bar.high = MathMax(iHigh(symbol, timeframe, i), MathMax(bar.open, bar.close));
    bar.low = MathMin(iLow(symbol, timeframe, i), MathMin(bar.open, bar.close));

    bars[i] = bar;
  }
}


/******************************************************
*************         LOCAL STORAGE          **********
*******************************************************/
enum LSFieldType {
    LS_DOUBLE = 1,
    LS_INT = 2,
    LS_BOOL = 3,
    LS_STRING = 4,
};

struct LSField {
    string name;
    LSFieldType type;
    double doubleValue;
    int intValue;
    bool boolValue;
    string stringValue;
};

bool lsRead(string filename, LSField &fields[]) {
    if (filename == NULL) {
        // filename = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL4\\Files\\"+ _Symbol + ".txt";
        filename = _Symbol + ".txt";
    }
    if (!FileIsExist(filename)) {
        Alert("[" + _Symbol + "] Local storage file not found: " + filename + ", err=" + GetLastError() + ". You must locate your file in MQL4/Files for real trading and MQL4/Tester/Files for testing");
        return false;
    }
    int fileHandler = FileOpen(filename, FILE_READ | FILE_TXT, "\n");
    if (fileHandler == INVALID_HANDLE) {
        Alert("[" + _Symbol + "][lsRead] Unable to open file: filename=" + filename + ", err=" + GetLastError());
        return false;
    }
    int count = 0;
    while (!FileIsEnding(fileHandler)) {
        int lineSize = FileReadInteger(fileHandler, INT_VALUE);
        string line = FileReadString(fileHandler, lineSize);
        string keyVal[];
        StringSplit(line, StringGetCharacter("=", 0), keyVal);
        if (ArraySize(keyVal) != 2) {
            Alert("[" + _Symbol + "][lsRead] Invalid line format: " + line);
            return false;
        }
        string key = keyVal[0];
        string val = keyVal[1];
        bool found = false;
        for (int j = 0; j < ArraySize(fields); j++) {
            if (StringCompare(key, fields[j].name) == 0) {
                if (fields[j].type == LS_STRING) {
                    fields[j].stringValue = val;
                } else if (fields[j].type == LS_DOUBLE) {
                    fields[j].doubleValue = StringToDouble(val);
                } else if (fields[j].type == LS_INT) {
                    fields[j].intValue = StringToInteger(val);
                } else if (fields[j].type == LS_BOOL) {
                    if (StringCompare(val, "true") == 0) {
                        fields[j].boolValue = true;
                    } else if (StringCompare(val, "false") == 0) {
                        fields[j].boolValue = false;
                    } else {
                        Alert("[" + _Symbol + "][lsRead] Invalid bool value: " + val);
                        return false;
                    }
                }
                found = true;
                break;
            }
        }
        if (found) {
            count++;
        } else {
            Alert("[" + _Symbol + "][lsRead] Unknown field in config file: " + key);
            return false;
        }
    }
    FileClose(fileHandler);
    if (count < ArraySize(fields)) {
        Alert("[" + _Symbol + "][lsRead] Some fields are missing in config file.");
        return false;
    }
    return true;
}

void lsWrite(string filename, LSField &fields[]) {
    string configsData = "";
    for (int i = 0; i < ArraySize(fields); i++) {
        configsData = configsData + fields[i].name + "=";
        if (fields[i].type == LS_STRING) {
            configsData = configsData + fields[i].stringValue;
        } else if (fields[i].type == LS_DOUBLE) {
            configsData = configsData + DoubleToString(fields[i].doubleValue);
        } else if (fields[i].type == LS_INT) {
            configsData = configsData + IntegerToString(fields[i].intValue);
        } else if (fields[i].type == LS_BOOL) {
            configsData = configsData + (fields[i].boolValue ? "true" : "false");
        }
        if (i < ArraySize(fields) - 1) {
            configsData = configsData + "\n";
        }
    }
    int fileHandler = FileOpen(filename, FILE_WRITE | FILE_TXT);
    FileWriteString(fileHandler, configsData);
    FileClose(fileHandler);
}

// convert buy/long => OP_BUY, sell/short => OP_SELL
int lsFieldToCommand(LSField &field) {
    const string commandString = field.stringValue;
    if (commandString == "buy" || commandString == "long") {
        return OP_BUY;
    } else if (commandString == "sell" || commandString == "short") {
        return OP_SELL;
    } else {
        Alert("[" + _Symbol +"][lsFieldToCommand] Invalid command: " + commandString);
        ExpertRemove();
        return 0;
    }
}


/*****************************************************
*************           UTILS            *************
******************************************************/
enum COMMAND {
    BUY = OP_BUY, // Buy
    SELL = OP_SELL, // Sell
};

int getIndex(string &array[], string val) {
    int length = ArraySize(array);
    for (int i = 0; i < length; i++) {
        if (array[i] == val) {
            return i;
        }
    }
    return -1;
}

string SWAP_STRENGTH[] = { "CHF", "EUR", "JPY", "GBP", "CAD", "NZD", "AUD", "USD" };
int getAutoCommand(string symbol) {
    const int firstCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 0, 3));
    const int secondCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 3, 3));
    if (firstCurrencyIndex < 0 || secondCurrencyIndex < 0) {
        Alert("[" + _Symbol + "][getAutoCommand] Symbol is not supported");
        ExpertRemove();
    }
    if (firstCurrencyIndex >= secondCurrencyIndex) {
        return OP_BUY;
    } else {
        return OP_SELL;
    }
}

int getAutoMagic(string symbol) {
    const int firstCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 0, 3));
    const int secondCurrencyIndex = getIndex(SWAP_STRENGTH, StringSubstr(symbol, 3, 3));
    if (firstCurrencyIndex < 0 || secondCurrencyIndex < 0) {
        Alert("[" + _Symbol + "][getAutoMagic] Symbol is not supported");
        ExpertRemove();
    }
    return firstCurrencyIndex * 10 + secondCurrencyIndex;
}

/*
bool shouldCreateOrder(int maxOpenPositions, int minDistance) {
    const int poolHisory = 0;
    const int poolTrades = 1;
    int closestPositionCount = 0;
    int closestPositionTickets[];
    int closestPositionPool[];
    int nTradePositions = OrdersTotal();
    int nHistoricalPositions = OrdersHistoryTotal();
    int i;
    for (i = nTradePositions - 1; i > nTradePositions - 1 - maxOpenPositions; i--) {

    }
}
*/
