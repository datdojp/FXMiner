string Com;
bool done = false;
void OnTick()
{
if (done) {
return;
}
for(int i=0;i < SymbolsTotal(false); i++) {
  string name = SymbolName(i,False);
  Com += "'" + name + "' => { current: " + (MarketInfo(name, MODE_ASK) +  MarketInfo(name, MODE_ASK))/2 + ", spread: " + MarketInfo(name,MODE_SPREAD) /*+ ", swap_long: " + MarketInfo(name,MODE_SWAPLONG) + ", swap_short: " + MarketInfo(name,MODE_SWAPSHORT)*/ + " },\n";
}
Alert (Com);
done = true;
}