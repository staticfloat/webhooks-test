using

#################################
# Default benchmarker function  #
#################################

# If the parent commit

function BenchmarkTracker(benchmarks::Vector{Function},
                          repo::RepoInfo;
                          log::ASCIIString="benchmark_results")

    function default_benchmarker(req::Request)
        commitsha = # pull from req

        current_log = "$commitsha_$log.csv"
        log_benchmarks(current_log, benchmarks)

        previous_log = get_previous_log(log, count)
        if !(isnull(previous_log)) # if there's a previous log, build a diff
            diff = log_diff(current_log, get(previous_log))
        else
            diff = []
        end

        return # response that includes diff
    end

    return BenchmarkTracker(default_benchmarker, log, repo, events=events)

end

function log_benchmarks(filename::ASCIIString, benchmarks::Vector{Function})
    open(filename, "w") do file
        write(file, "Function,Measurement\n")
        for f in benchmarks
            result = f() # dumb proof of concept
            write(file, "$f,$result\n")
        end
    end
end

function get_previous_log(req::Request, log::ASCIIString)

    # previous_log_regex = Regex(log*"_.*_"*(count-1)*".csv")
    # files_in_dir = readdir()
    # S = eltype(files_in_dir)
    # i = findfirst(x->ismatch(previous_log_regex, x), files_in_dir)
    # if i == 0
    #     return Nullable{S}()
    # else
    #     return Nullable{S}(files_in_dir[i])
    # end
end
