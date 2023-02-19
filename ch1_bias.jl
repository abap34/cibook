using DataFrames
using Statistics

# p.12 の疑似データ
data = [
    300 300 400 0
    600 500 600 1
    600 500 600 1
    300 300 400 0
    300 300 400 0
    600 500 600 1
    600 500 600 1
    300 300 400 0
    600 500 600 1
    300 300 400 0
]

data = DataFrame(
    data,
    [:Y, :Y0, :Y1, :Z]
)

z0_idx = data.Z .== 0
z1_idx = data.Z .== 1

τ̂_naive = mean(data[z1_idx, :Y1]) - mean(data[z0_idx, :Y0])

τ = mean(data.Y1) - mean(data.Y0)

mean(data[z1_idx, :Y1] - data[z1_idx, :Y0]) == mean(data[z0_idx, :Y1] - data[z0_idx, :Y0])

selection_bias = mean(data[z1_idx, :Y0]) - mean(data[z0_idx, :Y0])

τ̂_naive - τ == selection_bias

# ========= ここからサンプルコードの翻訳  =========

using CSV

# wget http://www.minethatdata.com/Kevin_Hillstrom_MineThatData_E-MailAnalytics_DataMiningChallenge_2008.03.20.csv 
# などでファイルをダウンロードしてください

email_data = CSV.read("Kevin_Hillstrom_MineThatData_E-MailAnalytics_DataMiningChallenge_2008.03.20.csv", DataFrame)

# 女性向けメールが配信されたデータを削除したデータを作成
male_df = subset(
    email_data,
    :segment => (segment -> segment .!= "Womens E-Mail")
)

# 介入を表すtreatment変数を追加
male_df[!, :treatment] = (male_df[!, :segment] .== "Mens E-Mail")

male_df

# groupbyによる集計

gd = groupby(
    male_df,
    :treatment
)

summary_by_segment = combine(
    gd,
    :conversion => (mean => :conversion_mean),
    :spend => (mean => :spend_mean),
    nrow => :count
)

# t検定を行う

using HypothesisTests

mens_mail = male_df[male_df[!, :treatment] .== 1, :spend]
no_mail = male_df[male_df[!, :treatment] .== 0, :spend]

EqualVarianceTTest(mens_mail, no_mail)


# セレクションバイアスのあるデータの準備

using Random
using StatsBase
Random.seed!(0)

# history > 300, recency < 3, channel == "Multichannel"のいずれかを満たす/満たさないデータのうち、
# 半数をランダムに選んで削除
obs_rate_c = 0.5
obs_rate_t = 0.5

male_df[!, :obs_rate_c] = ifelse.(
    (male_df.history .> 300) .| (male_df.recency .< 6) .| (male_df.channel .== "Multichannel"),
    obs_rate_c,
    1 # 条件を満たさない => フィルター(108行目)に引っかからないので消えない
)


male_df[!, :obs_rate_t] = ifelse.(
    (male_df.history .> 300) .| (male_df.recency .< 6) .| (male_df.channel .==  "Multichannel"),
    1,   # 条件を満たす => フィルター(109行目)に引っかからないので消えない
    obs_rate_t
)



male_df[!, :random_number] = rand(nrow(male_df))

cond_z0 = ((male_df.treatment .== 0) .& (male_df.random_number .< male_df.obs_rate_c))
cond_z1 = ((male_df.treatment .== 1) .& (male_df.random_number .< male_df.obs_rate_t))

biased_data = male_df[cond_z0 .| cond_z1, :]

biased_data

# 同様のgroupbyによる集計
gd = groupby(
    biased_data,
    :treatment
)

summary_by_segment = combine(
    gd,
    :conversion => (mean => :conversion_mean),
    :spend => (mean => :spend_mean),
    nrow => :count
)

mens_mail_biased = biased_data[biased_data[!, :treatment] .== 1, :spend]
no_mail_biased = biased_data[biased_data[!, :treatment] .== 0, :spend]

EqualVarianceTTest(mens_mail_biased, no_mail_biased)