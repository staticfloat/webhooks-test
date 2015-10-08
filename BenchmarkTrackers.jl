module BenchmarkTrackers

#################
# using/exports #
#################

import HttpCommon, GitHubWebhooks, Benchmarks

export BenchmarkTracker

#####################
# Utility Functions #
#####################

function log_benchmarks(filename::ASCIIString, benchmarks::Vector{Function})
    open(filename, "w") do file
        write(file, "Function,Measurement\n")
        for f in benchmarks
            result = @time f() # will use Benchmarks once API is ready
            write(file, "$f,$result\n")
        end
    end
end

####################
# BenchmarkTracker #
####################

# Only these events will be tracked
const TRACK_EVENTS = [GitHubWebhooks.PullRequestEvent, GitHubWebhooks.PushEvent]

immutable BenchmarkTracker
    tracker::GitHubWebhooks.WebhookTracker
    function BenchmarkTracker(access_token::AbstractString,
                              secret::AbstractString,
                              user_name::AbstractString,
                              repo_name::AbstractString,
                              benchmarks::Vector{Function})
        tracker = GitHubWebhooks.WebhookTracker(access_token, secret,
                                                user_name, repo_name;
                                                events=TRACK_EVENTS) do event

            payload = GitHubWebhooks.payload(event)
            kind = GitHubWebhooks.kind(event)

            dump(payload)

            if kind == GitHubWebhooks.PullRequestEvent
                sha = payload["head"]
            elseif kind == GitHubWebhooks.PushEvent
                sha = payload["pull_request"]["head"]["sha"]
            end

            GitHubWebhooks.respond(event, sha, GitHubWebhooks.PENDING;
                                   description="Running benchmarks...")

            log = "$(sha)_benchmarks.csv"

            print("Logging benchmarks to $(log)...")
            log_benchmarks(log, benchmarks)
            println("done.")

            GitHubWebhooks.respond(event, sha, GitHubWebhooks.SUCCESS,
                                   description="Benchmarks complete!")

            return HttpCommon.Response(200)
        end

        return new(tracker)
    end
end

function run(b::BenchmarkTracker, args...; kwargs...)
    return GitHubWebhooks.run(b.tracker, args...; kwargs...)
end

end # module BenchmarkTrackers
