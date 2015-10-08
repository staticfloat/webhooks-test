include("GitHubWebhooks.jl")
include("BenchmarkTrackers.jl")

using BenchmarkTrackers

# Write some functions to benchmark #
#-----------------------------------#
const TEST_INPUT = rand(100)

bench_sum() = sum(TEST_INPUT)
bench_prod() = prod(TEST_INPUT)

# Create a tracker #
#------------------#
access_token = ENV["WEBHOOK_TOKEN"]
secret = ENV["WEBHOOK_SECRET"]
user = "jrevels"
repo = "webhooks-test"
benchmarks = [bench_sum, bench_prod]

tracker = BenchmarkTracker(access_token, secret, user, repo, benchmarks)

# Run the tracker #
#-----------------#
BenchmarkTrackers.run(tracker; host=IPv4(127,0,0,1), port=8000)
