*Note: Basically none of this implemented right now, these are just ideas.*

# User Workflow for BenchmarkTrackers.jl

**Step 1: The user writes trackable functions in `benchmarks/runbenchmarks.jl`**

. These functions are annotated with metadata that declares:

- metrics (time, memory, etc.) relevant to the function(s).
- test arguments to be passed to the function(s).
- optional limitations for the benchmarking process
- other optional metadata, e.g. tags

For example (the syntax might change, but you get the idea):

```julia
@track begin
    [Time, GC, Allocations] # Metric enums that apply to functions in this @track block

    begin # `begin` inside of @track block specifies a new function
        function f(x, y) # function definition, or qualified function name
        ⋮
        end

        [test_x, test_y] # arg values used in testing
    end

    begin # multiple functions can belong to the same @track block
        function g(a, b)
        ⋮
        end

        [test_a, test_b]
    end

    # optional args
    iteration_limit = ...
    time_limit = ...
    memory_limit = ...
    tags = ...
    ⋮
end

# Another @track block might contain different settings
@track begin
    [Time, Bytes]

    begin
        function h(args...)
        ⋮
        end

        [test_args...]
    end

    iteration_limit = ...
    ⋮
end
```

**Step 2: The user spins up a `BenchmarkTracker`**

Configurable settings for a `BenchmarkTracker`:

- GitHub credentials (access token, repo path, webhook secret, etc.)
- logging settings (path to logs, log name prefix, how many logs to keep at a time)
- global time/memory limitations
- whether or not the `BenchmarkTracker` should create its own webhook via GitHub's [Webhooks API](https://developer.github.com/v3/repos/hooks/)

**Step 3: Enjoy the fruits of your labor**

As long as the `BenchmarkTracker` stays up and running, no further work is required. Well, unless `runbenchmarks.jl` is altered in any way, in which case step 3 will need to be repeated (maybe that could be automated, but it would probably be more trouble than it's worth).

On a `PullRequestEvent` or `PushEvent`, the `BenchmarkTracker` will respond with mutiple statuses to the relevant commit. Each status will correspond to a metric tracked in `runbenchmarks.jl` (e.g. `Time`, `Bytes`, `Allocations`, etc.) A status's state (e.g. success, failure, etc.) will be determined by comparing the current commit's results for the corresponding metric against that metric's results from the previous commit (or from the head commit of the comparison branch, if the event is a PR).
