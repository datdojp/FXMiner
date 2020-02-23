#include "lib.mqh";

input string Version = "1.1";

MinerConfig minerConfig = {};

void init() {
    minerConfig.symbol = _Symbol;
    minerConfig.shouldCreateOrder = true;
    minerConfig.shouldSetTrailingStop = false;
    readConfig();
    Alert(
        "[" + _Symbol + "] Loaded config from LocalStorage: " +
        "lots=" + minerConfig.lots + ", " +
        "distance=" + minerConfig.distance + ", " +
        "takeProfit=" + minerConfig.takeProfit + ", " +
        "command=" + minerConfig.command + ", " +
        "magic=" + minerConfig.magic + ", " +
        "slippage=" + minerConfig.slippage + ", " +
        "maxOpenPrice=" + minerConfig.maxOpenPrice + ", " +
        "minOpenPrice=" + minerConfig.minOpenPrice
    );
}

void OnTick() {
    readConfig();
    minerOnTick(minerConfig);
}

void readConfig() {
    LSField fields[] = {
        { "Lots", LS_DOUBLE },
        { "Distance", LS_INT },
        { "TakeProfit", LS_INT },
        { "Command", LS_STRING },
        { "Magic", LS_INT },
        { "Slippage", LS_INT },
        { "MaxOpenPrice", LS_DOUBLE },
        { "MinOpenPrice", LS_DOUBLE },
    };
    if (!lsRead(NULL, fields)) {
        ExpertRemove();
        return;
    }
    minerConfig.lots = fields[0].doubleValue;
    minerConfig.distance = fields[1].intValue * _Point;
    minerConfig.takeProfit = fields[2].intValue * _Point;
    minerConfig.command = lsFieldToCommand(fields[3]);
    minerConfig.magic = fields[4].intValue;
    minerConfig.slippage = fields[5].intValue;
    minerConfig.maxOpenPrice = fields[6].doubleValue;
    minerConfig.minOpenPrice = fields[7].doubleValue;
}
