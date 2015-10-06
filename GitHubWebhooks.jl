module GitHubWebhooks

#################
# import/export #
#################

import HttpServer,
       JSON

export WebhookTracker

##################
# WebhookTracker #
##################

immutable WebhookTracker
    server::HttpServer.Server
end

"""
A `WebhookTracker` is a wrapper over an `HttpServer.Server` that expects
requests from GitHub Webhooks (https://developer.github.com/webhooks/).

Syntax for constructing a `WebhookTracker`:

    ```julia

    tracker = WebhookTracker("user", "repo"; secret="mysecret") do payload
        # show payload in REPL
        println("Our webhook sent us some JSON! Take a look: ")
        dump(payload)

        # generate some status
        status = make_some_status(payload)

        # send the status back to the event source
        reply(payload, status)
    end

    ```
"""
function WebhookTracker(handler, user_name, repo_name, events; secret::ASCIIString="")
    repo = user_name * `/` * repo_name

    wrapper = HttpServer.HttpHandler() do request, response
        if has_expected_headers(request)
            payload = JSON.parse(mapreduce(Char, string, request.data))
            if has_secret(payload, secret)  && from_repo(payload, repo)
                handler(payload)
            end
        end
    end

    return WebhookTracker(HttpServer.Server(wrapper))
end

# Functions on WebhookTrackers #
#------------------------------#
run(tracker::WebhookTracker, args...) = HttpServer.run(tracker.server, args...)

# Utility Functions #
#-------------------#
function has_expected_headers(request)
    headers = request.headers
    return haskey(headers, "X-Github-Event") &&
           haskey(headers, "X-Hub-Signature") &&
           haskey(headers, "X-Github-Delivery")
end

has_secret(payload, secret) = payload["config"]["secret"] == secret

from_repo(payload, repo) = payload["repository"]["full_name"] == repo

##################################################
# Functions for working with GitHub's Status API #
##################################################

# TODO
# reply(payload, status)

end # module GitHubWebhooks
