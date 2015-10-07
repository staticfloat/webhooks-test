include("GitHubWebhooks.jl")
using GitHubWebhooks

access_token = ENV["WEBHOOK_TOKEN"] # pull token from environment variable
mysecret = ENV["WEBHOOK_SECRET"] # pull secret from environment variable
myevents = [GitHubWebhooks.PullRequestEvent] # only track PR events

tracker = WebhookTracker(access_token, mysecret,
                         "jrevels", "webhooks-test";
                         events=myevents) do event
    kind = GitHubWebhooks.kind(event)
    payload = GitHubWebhooks.payload(event)

    # Show payload in REPL
    println("The webhook sent us a $(kind)!")

    # Respond to the PR event
    sha = payload["pull_request"]["head"]["sha"] # sha for the head commit

    GitHubWebhooks.respond(event, sha, GitHubWebhooks.PENDING;
                           description="Doing some work on commit $sha")


    result = 1 + 1 # do some kind of work (usually involving the payload)

    GitHubWebhooks.respond(event, sha, GitHubWebhooks.SUCCESS,
                           description="Here's the result: $result")

    # If everything went well, let's return the proper HTTP status code
    return HttpCommon.Response(200, "woohoo")
end

# Start the tracker on port 8000
GitHubWebhooks.run(tracker; host=IPv4(127,0,0,1), port=8000)
