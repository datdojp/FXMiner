enum FieldType {
    DOUBLE = 1,
    INT = 2,
    BOOL = 3,
    STRING = 4,
};

struct Field {
    string name;
    FieldType type;
    double doubleValue;
    int intValue;
    bool boolValue;
    string stringValue;
};

class EAConfigUtil {
    private:
        string mFilename;
    public:
        EAConfigUtil(string EAName);
        bool hasConfigs();
        void readConfigs(Field &configs[]);
        void writeConfigs(Field &configs[]);
};

EAConfigUtil::EAConfigUtil(string EAName) {
    mFilename = EAName + "_" + _Symbol + "_configs.txt";
}

bool EAConfigUtil::hasConfigs() {
    return FileIsExist(mFilename);
}

void EAConfigUtil::readConfigs(Field &configs[]) {
    int fileHandler = FileOpen(mFilename, FILE_READ | FILE_TXT, "\n");
    if (fileHandler == INVALID_HANDLE) {
        Alert("[EAConfigUtil] Unable to open file: filename=" + mFilename + ", err=" + GetLastError());
        ExpertRemove();
        return;
    }
    int count = 0;
    while (!FileIsEnding(fileHandler)) {
        int lineSize = FileReadInteger(fileHandler, INT_VALUE);
        string line = FileReadString(fileHandler, lineSize);
        string keyVal[];
        StringSplit(line, StringGetCharacter("=", 0), keyVal);
        if (ArraySize(keyVal) != 2) {
            Alert("[EAConfigUtil] Invalid line format: " + line);
            ExpertRemove();
            return;
        }
        string key = keyVal[0];
        string val = keyVal[1];
        bool found = false;
        for (int j = 0; j < ArraySize(configs); j++) {
            if (StringCompare(key, configs[j].name) == 0) {
                if (configs[j].type == STRING) {
                    configs[j].stringValue = val;
                } else if (configs[j].type == DOUBLE) {
                    configs[j].doubleValue = StringToDouble(val);
                } else if (configs[j].type == INT) {
                    configs[j].intValue = StringToInteger(val);
                } else if (configs[j].type == BOOL) {
                    if (StringCompare(val, "true") == 0) {
                        configs[j].boolValue = true;
                    } else if (StringCompare(val, "false") == 0) {
                        configs[j].boolValue = false;
                    } else {
                        Alert("[EAConfigUtil] Invalid bool value: " + val);
                        ExpertRemove();
                        return;
                    }
                }
                found = true;
                break;
            }
        }
        if (found) {
            count++;
        } else {
            Alert("[EAConfigUtil] Unknown field in config file: " + key);
            ExpertRemove();
            return;
        }
    }
    FileClose(fileHandler);
    if (count < ArraySize(configs)) {
        Alert("[EAConfigUtil] Some fields are missing in config file.");
        ExpertRemove();
        return;
    }
}

void EAConfigUtil::writeConfigs(Field &configs[]) {
    string configsData = "";
    for (int i = 0; i < ArraySize(configs); i++) {
        configsData = configsData + configs[i].name + "=";
        if (configs[i].type == STRING) {
            configsData = configsData + configs[i].stringValue;
        } else if (configs[i].type == DOUBLE) {
            configsData = configsData + DoubleToString(configs[i].doubleValue);
        } else if (configs[i].type == INT) {
            configsData = configsData + IntegerToString(configs[i].intValue);
        } else if (configs[i].type == BOOL) {
            configsData = configsData + (configs[i].boolValue ? "true" : "false");
        }
        if (i < ArraySize(configs) - 1) {
            configsData = configsData + "\n";
        }
    }
    int fileHandler = FileOpen(mFilename, FILE_WRITE | FILE_TXT);
    FileWriteString(fileHandler, configsData);
    FileClose(fileHandler);
}
