require 'byebug'
require 'rest-client'
require 'json'

$currencies = [ 'EUR', 'GBP', 'AUD', 'NZD', 'USD', 'CAD', 'CHF', 'JPY' ]
$market_info = {
'AUDCAD' => { current: 0.97709, spread: 21, swap_long: 0.34, swap_short: -0.64 },
'AUDCHF' => { current: 0.74453, spread: 28, swap_long: 0, swap_short: 0 },
'AUDHKD' => { current: 5.88474, spread: 137, swap_long: 0, swap_short: 0 },
'AUDJPY' => { current: 81.5, spread: 16, swap_long: 1.23, swap_short: -1.77 },
'AUDNZD' => { current: 1.08542, spread: 33, swap_long: -0.38, swap_short: -0.02 },
'AUDSGD' => { current: 1.00873, spread: 35, swap_long: 0, swap_short: 0 },
'AUDUSD' => { current: 0.75013, spread: 14, swap_long: 0.26, swap_short: -0.54 },
'CADCHF' => { current: 0.76206, spread: 27, swap_long: 0.56, swap_short: -0.96 },
'CADHKD' => { current: 6.02327, spread: 124, swap_long: 0, swap_short: 0 },
'CADJPY' => { current: 83.422, spread: 20, swap_long: 0.74, swap_short: -1.38 },
'CADSGD' => { current: 1.03247, spread: 33, swap_long: 0, swap_short: 0 },
'CHFHKD' => { current: 7.90554, spread: 206, swap_long: 0, swap_short: 0 },
'CHFJPY' => { current: 109.484, spread: 25, swap_long: 0.19, swap_short: -0.63 },
'CHFZAR' => { current: 12.77561, spread: 1288, swap_long: 0, swap_short: 0 },
'EURAUD' => { current: 1.53869, spread: 27, swap_long: -1.35, swap_short: 0.81 },
'EURCAD' => { current: 1.50333, spread: 32, swap_long: -0.42, swap_short: -0.09 },
'EURCHF' => { current: 1.14548, spread: 22, swap_long: 0.59, swap_short: -1.17 },
'EURCZK' => { current: 25.95278, spread: 2778, swap_long: 0, swap_short: 0 },
'EURDKK' => { current: 7.44254, spread: 144, swap_long: 0, swap_short: 0 },
'EURGBP' => { current: 0.87077, spread: 18, swap_long: -0.45, swap_short: 0.19 },
'EURHKD' => { current: 9.05383, spread: 163, swap_long: 0, swap_short: 0 },
'EURHUF' => { current: 321.01, spread: 313, swap_long: 0, swap_short: 0 },
'EURJPY' => { current: 125.39, spread: 13, swap_long: 0.85, swap_short: -1.76 },
'EURNOK' => { current: 9.57256, spread: 629, swap_long: 0, swap_short: 0 },
'EURNZD' => { current: 1.67, spread: 46, swap_long: -1.9, swap_short: 1.21 },
'EURPLN' => { current: 4.34204, spread: 321, swap_long: 0, swap_short: 0 },
'EURSEK' => { current: 10.34898, spread: 475, swap_long: 0, swap_short: 0 },
'EURSGD' => { current: 1.55195, spread: 46, swap_long: 0, swap_short: 0 },
'EURTRY' => { current: 5.24868, spread: 1109, swap_long: 0, swap_short: 0 },
'EURUSD' => { current: 1.15406, spread: 8, swap_long: -0.55, swap_short: 0.06 },
'EURZAR' => { current: 14.63128, spread: 1357, swap_long: 0, swap_short: 0 },
'GBPAUD' => { current: 1.76727, spread: 36, swap_long: 1.92, swap_short: -2.76 },
'GBPCAD' => { current: 1.7266, spread: 36, swap_long: 1.92, swap_short: -2.76 },
'GBPCHF' => { current: 1.31562, spread: 31, swap_long: 1.92, swap_short: -2.76 },
'GBPHKD' => { current: 10.39918, spread: 234, swap_long: 0, swap_short: 0 },
'GBPJPY' => { current: 144.02, spread: 28, swap_long: 2.28, swap_short: -3.6 },
'GBPNZD' => { current: 1.91803, spread: 58, swap_long: 0, swap_short: 0 },
'GBPPLN' => { current: 4.98747, spread: 472, swap_long: 0, swap_short: 0 },
'GBPSGD' => { current: 1.78256, spread: 61, swap_long: 0, swap_short: 0 },
'GBPUSD' => { current: 1.32552, spread: 13, swap_long: 0.14, swap_short: -0.85 },
'GBPZAR' => { current: 16.80541, spread: 1634, swap_long: 0, swap_short: 0 },
'HKDJPY' => { current: 13.85119, spread: 260, swap_long: 0, swap_short: 0 },
'NZDCAD' => { current: 0.90038, spread: 30, swap_long: 0, swap_short: 0 },
'NZDCHF' => { current: 0.68607, spread: 31, swap_long: 0, swap_short: 0 },
'NZDHKD' => { current: 5.42267, spread: 166, swap_long: 0, swap_short: 0 },
'NZDJPY' => { current: 75.104, spread: 30, swap_long: 1.16, swap_short: -1.65 },
'NZDSGD' => { current: 0.92952, spread: 39, swap_long: 0, swap_short: 0 },
'NZDUSD' => { current: 0.69122, spread: 17, swap_long: 0, swap_short: 0 },
'SGDCHF' => { current: 0.73822, spread: 28, swap_long: 0, swap_short: 0 },
'SGDHKD' => { current: 5.83485, spread: 135, swap_long: 0, swap_short: 0 },
'SGDJPY' => { current: 80.815, spread: 25, swap_long: 0, swap_short: 0 },
'TRYJPY' => { current: 23.954, spread: 80, swap_long: 0, swap_short: 0 },
'USDCAD' => { current: 1.30265, spread: 19, swap_long: -0.07, swap_short: -0.27 },
'USDCHF' => { current: 0.99255, spread: 20, swap_long: 0.68, swap_short: -1.06 },
'USDCNH' => { current: 6.42328, spread: 82, swap_long: 0, swap_short: 0 },
'USDCZK' => { current: 22.48967, spread: 2387, swap_long: 0, swap_short: 0 },
'USDDKK' => { current: 6.4495, spread: 171, swap_long: 0, swap_short: 0 },
'USDHKD' => { current: 7.84506, spread: 46, swap_long: 0, swap_short: 0 },
'USDHUF' => { current: 278.2, spread: 359, swap_long: 0, swap_short: 0 },
'USDINR' => { current: 67.786, spread: 55, swap_long: 0, swap_short: 0 },
'USDJPY' => { current: 108.654, spread: 8, swap_long: 0.86, swap_short: -1.48 },
'USDMXN' => { current: 19.8232, spread: 839, swap_long: 0, swap_short: 0 },
'USDNOK' => { current: 8.2951, spread: 594, swap_long: 0, swap_short: 0 },
'USDPLN' => { current: 3.7622, spread: 390, swap_long: 0, swap_short: 0 },
'USDSAR' => { current: 3.75125, spread: 170, swap_long: 0, swap_short: 0 },
'USDSEK' => { current: 8.96801, spread: 444, swap_long: 0, swap_short: 0 },
'USDSGD' => { current: 1.34475, spread: 23, swap_long: 0, swap_short: 0 },
'USDTHB' => { current: 32.158, spread: 26, swap_long: 0, swap_short: 0 },
'USDTRY' => { current: 4.54597, spread: 945, swap_long: 0, swap_short: 0 },
'USDZAR' => { current: 12.67787, spread: 1022, swap_long: 0, swap_short: 0 },
'ZARJPY' => { current: 8.58, spread: 13, swap_long: 0, swap_short: 0 },

}
$combinations = []
$pairs = {
  'AUDCAD' => { min: 0.91570, max: 1.04050, point: 0.00001, },
  'AUDCHF' => { min: 0.65360, max: 0.84061, point: 0.00001, },
  'AUDNZD' => { min: 1.00395, max: 1.14799, point: 0.00001, },
  'AUDUSD' => { min: 0.68325, max: 0.81686, point: 0.00001, },
  'CADCHF' => { min: 0.68317, max: 0.86336, point: 0.00001, },
  'EURAUD' => { min: 1.36455, max: 1.66214, point: 0.00001, },
  'EURCAD' => { min: 1.30367, max: 1.61519, point: 0.00001, },
  'EURCHF' => { min: 1.02655, max: 1.20322, point: 0.00001, },
  'EURGBP' => { min: 0.69486, max: 0.93056, point: 0.00001, },
  'EURNZD' => { min: 1.39049, max: 1.89602, point: 0.00001, },
  'EURUSD' => { min: 1.03506, max: 1.25596, point: 0.00001, },
  'GBPAUD' => { min: 1.53676, max: 2.24529, point: 0.00001, },
  'GBPCAD' => { min: 1.54795, max: 2.10000, point: 0.00001, },
  'GBPCHF' => { min: 1.14923, max: 1.55807, point: 0.00001, },
  'GBPNZD' => { min: 1.62529, max: 2.59341, point: 0.00001, },
  'GBPUSD' => { min: 1.16381, max: 1.59304, point: 0.00001, },
  'NZDCAD' => { min: 0.82947, max: 0.99312, point: 0.00001, },
  'NZDCHF' => { min: 0.56619, max: 0.79769, point: 0.00001, },
  'NZDUSD' => { min: 0.60974, max: 0.77477, point: 0.00001, },
  'USDCAD' => { min: 1.19170, max: 1.46971, point: 0.00001, },
  'USDCHF' => { min: 0.83990, max: 1.03386, point: 0.00001, },

  'AUDJPY' => { min: 72.752,  max: 98.165,  point: 0.001, },
  'CADJPY' => { min: 75.417,  max: 103.652, point: 0.001, },
  'CHFJPY' => { min: 101.961, max: 134.733, point: 0.001, },
  'USDJPY' => { min: 99.161,  max: 125.768, point: 0.001, },
  'EURJPY' => { min: 109.648, max: 145.024, point: 0.001, },
  'GBPJPY' => { min: 125.221, max: 196.382, point: 0.001, },
  'NZDJPY' => { min: 69.305,  max: 93.800,  point: 0.001, },
}

$pairs.each {
  |pair, info|
  market_info = $market_info[pair]
  info[:spread] = market_info[:spread]
  mid = (info[:max] + info[:min]) / 2
  info[:mid] = mid
  current = market_info[:current]
  if market_info[:swap_long] == 0 && market_info[:swap_short] == 0
    info[:tradability] = (info[:max] - info[:min]) / info[:point] * 0.1
  else
    if current < mid
      info[:tradability] = (mid - current) / info[:point] * market_info[:swap_long]
    else
      info[:tradability] = (current - mid) / info[:point] * market_info[:swap_short]
    end
  end
}

def f(selected, left)
  if left.length == 0
    $combinations << selected
    return
  end
  left.each {
    |c|
    f(selected + [c], left - [c])
  }
end

f([], $currencies)
$combinations = $combinations
  .map {
    |currencies|
    pairs = []
    temp = nil
    currencies.each_with_index {
      |c, i|
      if i % 2 == 0
        temp = c
      else
        pairs << [temp, c].sort { |a,b| $currencies.index(a) <=> $currencies.index(b) }
                          .join
      end
    }
    pairs.sort
  }
  .uniq
  .map {
    |pairs|
    {
      pairs: pairs,
      sum_spread: pairs.inject(0) { |sum, p| sum + $pairs[p][:spread] },
      sum_point_diff: pairs
        .inject(0) {
          |sum, p|
          pair_info = $pairs[p]
          sum + (pair_info[:max] - pair_info[:min]) / pair_info[:point]
        }
        .round,
      sum_tradability: pairs.inject(0) { |sum, p| sum + $pairs[p][:tradability] },
      tradability_diff: lambda {
        all = pairs.map { |p| $pairs[p][:tradability] }.sort
        (all.last - all.first).abs
      }.call(),
    }
  }
  .select {
    |c|
    c[:sum_tradability] > 0
  }
min_sum_spread = $combinations.map{ |c| c[:sum_spread] }.min
max_sum_spread = $combinations.map{ |c| c[:sum_spread] }.max
min_sum_point_diff = $combinations.map{ |c| c[:sum_point_diff] }.min
max_sum_point_diff = $combinations.map{ |c| c[:sum_point_diff] }.max
min_sum_tradability = $combinations.map{ |c| c[:sum_tradability] }.min
max_sum_tradability = $combinations.map{ |c| c[:sum_tradability] }.max
min_tradability_diff = $combinations.map{ |c| c[:tradability_diff] }.min
max_tradability_diff = $combinations.map{ |c| c[:tradability_diff] }.max
$combinations = $combinations.map {
  |c|
  c[:sum_spread_ratio] = ((c[:sum_spread] - min_sum_spread).to_f / (max_sum_spread - min_sum_spread)).round(4)
  c[:sum_point_diff_ratio] = ((c[:sum_point_diff] - min_sum_point_diff).to_f / (max_sum_point_diff - min_sum_point_diff)).round(4)
  c[:sum_tradability_ratio] = ((max_sum_tradability - c[:sum_tradability]).to_f / (max_sum_tradability - min_sum_tradability)).round(4)
  c[:tradability_diff_ratio] = ((c[:tradability_diff] - min_tradability_diff).to_f / (max_tradability_diff - min_tradability_diff)).round(4)
  c[:total] = c[:sum_spread_ratio] + c[:sum_point_diff_ratio] * 1.4 + c[:sum_tradability_ratio] * 1.2 + c[:tradability_diff_ratio] * 0.8
  c
}
.sort {
  |c1, c2|
  c1[:total] <=> c2[:total]
}

puts "Total combinations: #{$combinations.length}"
puts [ 'Pair1', 'Pair2', 'Pair3', 'Pair4', 'Sum spread', 'Sum point diff', 'Sum Tradability', 'Sum spread ratio', 'Sum point diff ratio', 'Sum Tradability Ratio', 'Tradability Diff Ratio', 'Total' ].join("\t")
$combinations.each {
  |c|
  puts (c[:pairs] + [c[:sum_spread], c[:sum_point_diff], c[:sum_tradability], c[:sum_spread_ratio], c[:sum_point_diff_ratio], c[:sum_tradability_ratio], c[:tradability_diff_ratio], c[:total]]).join("\t")
}

puts "\nBest combination:\n"
$combinations[0..4].each_with_index {
  |c, index|
  puts "##{index+1}"
  c[:pairs].each {
    |p|
    market_info = $market_info[p]
    pair_info = $pairs[p]
    type = ''
    if market_info[:swap_long] == 0 && market_info[:swap_short] == 0
      type = 'BUY/LONG'
    else
      type = market_info[:current] <= pair_info[:mid] ? 'BUY' : 'SELL'
    end
    puts "#{p}: #{market_info.merge(pair_info).merge(type: type).inspect}"
  }
}


