require 'byebug'
require 'rest-client'
require 'json'

$currencies = [ 'EUR', 'GBP', 'AUD', 'NZD', 'USD', 'CAD', 'CHF', 'JPY' ]
$swap_strength = [ 'USD', 'AUD', 'NZD', 'CAD', 'GBP', 'JPY', 'EUR', 'CHF' ]
$market_info = {
'AUDCAD' => { current: 0.97072, spread: 21 },
'AUDCHF' => { current: 0.73519, spread: 29 },
'AUDJPY' => { current: 82.411, spread: 16 },
'AUDNZD' => { current: 1.09025, spread: 31 },
'AUDUSD' => { current: 0.74068, spread: 14 },
'CADCHF' => { current: 0.75745, spread: 28 },
'CADJPY' => { current: 84.909, spread: 25 },
'CHFJPY' => { current: 112.117, spread: 31 },
'EURAUD' => { current: 1.58353, spread: 19 },
'EURCAD' => { current: 1.53703, spread: 28 },
'EURCHF' => { current: 1.16399, spread: 19 },
'EURGBP' => { current: 0.88499, spread: 17 },
'EURJPY' => { current: 130.484, spread: 13 },
'EURNZD' => { current: 1.7263, spread: 41 },
'EURUSD' => { current: 1.17274, spread: 8 },
'GBPAUD' => { current: 1.78951, spread: 36 },
'GBPCAD' => { current: 1.73693, spread: 35 },
'GBPCHF' => { current: 1.31544, spread: 29 },
'GBPJPY' => { current: 147.462, spread: 28 },
'GBPNZD' => { current: 1.95079, spread: 48 },
'GBPUSD' => { current: 1.32527, spread: 13 },
'NZDCAD' => { current: 0.89054, spread: 26 },
'NZDCHF' => { current: 0.67448, spread: 29 },
'NZDJPY' => { current: 75.607, spread: 30 },
'NZDUSD' => { current: 0.6795, spread: 16 },
'USDCAD' => { current: 1.31068, spread: 22 },
'USDCHF' => { current: 0.9926, spread: 18 },
'USDJPY' => { current: 111.269, spread: 8 },
}
$combinations = []
$pairs = {
  'AUDCAD' => { min: 0.91570, max: 1.04050, point: 0.00001, swap_long: -1, swap_short: -1 },
  'AUDCHF' => { min: 0.65360, max: 0.84061, point: 0.00001, swap_long: 1, swap_short: -1 },
  'AUDNZD' => { min: 1.00395, max: 1.14799, point: 0.00001, swap_long: -1, swap_short: -1 },
  'AUDUSD' => { min: 0.68325, max: 0.81686, point: 0.00001, swap_long: -1, swap_short: -1 },
  'CADCHF' => { min: 0.68317, max: 0.86336, point: 0.00001, swap_long: 1, swap_short: -1 },
  'EURAUD' => { min: 1.36455, max: 1.66214, point: 0.00001, swap_long: -1, swap_short: 1 },
  'EURCAD' => { min: 1.30367, max: 1.61519, point: 0.00001, swap_long: -1, swap_short: 1 },
  'EURCHF' => { min: 1.02655, max: 1.20322, point: 0.00001, swap_long: -1, swap_short: -1 },
  'EURGBP' => { min: 0.69486, max: 0.93056, point: 0.00001, swap_long: -1, swap_short: -1 },
  'EURNZD' => { min: 1.39049, max: 1.89602, point: 0.00001, swap_long: -1, swap_short: 1 },
  'EURUSD' => { min: 1.03506, max: 1.25596, point: 0.00001, swap_long: -1, swap_short: 1 },
  'GBPAUD' => { min: 1.53676, max: 2.24529, point: 0.00001, swap_long: -1, swap_short: 1 },
  'GBPCAD' => { min: 1.54795, max: 2.10000, point: 0.00001, swap_long: -1, swap_short: 1 },
  'GBPCHF' => { min: 1.14923, max: 1.55807, point: 0.00001, swap_long: 0.1, swap_short: -1 },
  'GBPNZD' => { min: 1.62529, max: 2.59341, point: 0.00001, swap_long: -1, swap_short: 1 },
  'GBPUSD' => { min: 1.16381, max: 1.59304, point: 0.00001, swap_long: -1, swap_short: 1 },
  'NZDCAD' => { min: 0.82947, max: 0.99312, point: 0.00001, swap_long: -1 , swap_short: -1 },
  'NZDCHF' => { min: 0.56619, max: 0.79769, point: 0.00001, swap_long: 1, swap_short: -1 },
  'NZDUSD' => { min: 0.60974, max: 0.77477, point: 0.00001, swap_long: -1, swap_short: -1 },
  'USDCAD' => { min: 1.19170, max: 1.46971, point: 0.00001, swap_long: 1, swap_short: -1 },
  'USDCHF' => { min: 0.83990, max: 1.03386, point: 0.00001, swap_long: 1, swap_short: -1 },

  'AUDJPY' => { min: 72.752,  max: 98.165,  point: 0.001, swap_long: 1, swap_short: -1 },
  'CADJPY' => { min: 75.417,  max: 103.652, point: 0.001, swap_long: 1, swap_short: -1 },
  'CHFJPY' => { min: 101.961, max: 134.733, point: 0.001, swap_long: -1, swap_short: -1 },
  'USDJPY' => { min: 99.161,  max: 125.768, point: 0.001, swap_long: 1, swap_short: -1 },
  'EURJPY' => { min: 109.648, max: 145.024, point: 0.001, swap_long: -1, swap_short: -1 },
  'GBPJPY' => { min: 125.221, max: 196.382, point: 0.001, swap_long: -1, swap_short: -1 },
  'NZDJPY' => { min: 69.305,  max: 93.800,  point: 0.001, swap_long: 1, swap_short: -1 },
}

$pairs.each {
  |pair, info|
  market_info = $market_info[pair]
  info[:spread] = market_info[:spread]
  mid = (info[:max] + info[:min]) / 2
  info[:mid] = mid
  current = market_info[:current]
  if info[:swap_long] == 0 && info[:swap_short] == 0
    info[:tradability] = (info[:max] - info[:min]) / info[:point] * 0.1
  else
    if current < mid
      info[:tradability] = (mid - current) / info[:point] * info[:swap_long]
    else
      info[:tradability] = (current - mid) / info[:point] * info[:swap_short]
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
    if 0 < pairs.count {|p| $pairs[p][:swap_long] < 0 && $pairs[p][:swap_short] < 0 }
      nil
    else
      pairs.sort
    end
  }
  .compact
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
$combinations.each_with_index {
  |c, index|
  puts "##{index+1}"
  c[:pairs].each {
    |p|
    market_info = $market_info[p]
    pair_info = $pairs[p]
    type = ''
    if pair_info[:swap_long] == 0 && pair_info[:swap_short] == 0
      type = 'BUY/LONG'
    else
      type = market_info[:current] <= pair_info[:mid] ? 'BUY' : 'SELL'
    end
    puts "#{p}: #{market_info.merge(pair_info).merge(type: type).inspect}"
  }
}


