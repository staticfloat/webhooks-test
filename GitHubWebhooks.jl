module GitHubWebhooks

#################
# import/export #
#################

import HttpCommon, HttpServer, Requests, Nettle

export WebhookTracker

#############
# Constants #
#############

# Status "Enum" #
#---------------#

immutable StatusState
    name::ASCIIString
end

const PENDING = StatusState("pending")
const ERROR = StatusState("error")
const FAILURE = StatusState("failure")
const SUCCESS = StatusState("success")

# Event "Enum" #
#--------------#

immutable Event
    header::ASCIIString
end

Event(request::HttpCommon.Request) = Event(event_header(request))

Base.(:(==))(a::Event, b::Event) = a.header == b.header

const CommitCommentEvent = Event("commit_comment")
const CreateEvent = Event("create")
const DeleteEvent = Event("delete")
const DeploymentEvent = Event("deployment")
const DeploymentStatusEvent = Event("deployment_status")
const DownloadEvent = Event("download")
const FollowEvent = Event("follow")
const ForkEvent = Event("fork")
const ForkApplyEvent = Event("fork_apply")
const GistEvent = Event("gist")
const GollumEvent = Event("gollum")
const IssueCommentEvent = Event("issue_comment")
const IssuesEvent = Event("issues")
const MemberEvent = Event("member")
const MembershipEvent = Event("membership")
const PageBuildEvent = Event("page_build")
const PublicEvent = Event("public")
const PullRequestEvent = Event("pull_request")
const PullRequestReviewCommentEvent = Event("pull_request_review_comment")
const PushEvent = Event("push")
const ReleaseEvent = Event("release")
const RepositoryEvent = Event("repository")
const StatusEvent = Event("status")
const TeamAddEvent = Event("team_add")
const WatchEvent = Event("watch")

# Endpoints #
#-----------#

const API_ENDPOINT = "https://api.github.com/"

###########################
# Utility Types/Functions #
###########################

function authenticate(access_token::AbstractString)
    params = Dict("access_token"=>access_token)
    response = Requests.get(API_ENDPOINT; query=params)
    if !(200 <= response.status < 300)
        error("""Attempt to authenticate with GitHub API failed.
                 Response Code: $(response.status)
                 Response Message: $(Requests.json(response))""")
    end
    return access_token
end

repo_full_name(webhook_payload) = webhook_payload["repository"]["full_name"]

has_event_header(request::HttpCommon.Request) = haskey(request.headers, "X-GitHub-Event")
event_header(request::HttpCommon.Request) = request.headers["X-GitHub-Event"]

has_sig_header(request::HttpCommon.Request) = haskey(request.headers, "X-Hub-Signature")
sig_header(request::HttpCommon.Request) = request.headers["X-Hub-Signature"]

###############
# EventClient #
###############

"""
An `EventClient` is created and fed to a `WebhookTracker`'s handler function
whenever GitHub sends an event to the tracker. The `EventClient` serves as an
interface that can be used by the handler function to easily examine and respond
to the event. Here are the functions defined on `EventClient`:

    payload(event::EventClient)
        returns the JSON payload for the event, represented as a Dict

    respond(event::EventClient,
            sha::AbstractString, # The commit SHA to which the status applies
            state::StatusState;
            description::AbstractString="",
            context::AbstractString="default",
            target_url::AbstractString="")
        Use to respond to the event with a status generated
        from the given arguments. The `state` argument must
        take one of following values:
            GitHubWebhooks.PENDING, GitHubWebhooks.SUCCESS,
            GitHubWebhooks.FAILURE, GitHubWebhooks.ERROR

    kind(event::EventClient) -> The value of the X-Github-Event header
"""
immutable EventClient
    kind::Event
    payload::Dict
    endpoint::AbstractString
    access_token::AbstractString
    function EventClient(kind::Event, payload::Dict, access_token::AbstractString)
        endpoint = "$(API_ENDPOINT)repos/$(repo_full_name(payload))/statuses/"
        return new(kind, payload, endpoint, access_token)
    end
end

function respond(event::EventClient, sha::AbstractString, state::StatusState;
                 description::AbstractString="",
                 context::AbstractString="default",
                 target_url::AbstractString="")
    status = Dict(
        "state" => state.name,
        "target_url" => target_url,
        "description" => description,
        "context" => context
    )
    params = Dict("access_token"=>event.access_token)
    return Requests.post(event.endpoint * sha; query=params, json=status)
end

payload(event::EventClient) = event.payload
kind(event::EventClient) = event.kind

##################
# WebhookTracker #
##################

"""
A `WebhookTracker` is a server that handles events recieved from GitHub Webhooks
(https://developer.github.com/webhooks/). The tracker extracts the event payload
from the webhook payload, wraps it in an `EventClient` (use the REPL's `help`
mode for more info on `GitHubWebhooks.EventClient`). This `EventClient` is then
fed to the provided `handler` function that defines the tracker's response
behavior to GitHub Events.

The WebhookTracker constructor has the following signature:

    WebhookTracker(handler, # callable object (function, type, etc.)
                   access_token::AbstractString,
                   user_name::AbstractString,
                   repo_name::AbstractString;
                   events::Vector{GitHubWebhooks.Event}=GitHubWebhooks.Event[],
                   secret::AbstractString="")


Here's an example:

    ```julia
    access_token = # token with repo permissions (DON'T HARDCODE THIS)
    mysecret = # webhook secret (DON'T HARDCODE THIS)
    myevents = [GitHubWebhooks.PullRequestEvent] # only track PR events

    tracker = WebhookTracker(access_token, mysecret,
                             "user", "repo";
                             events=myevents) do event
        kind = GitHubWebhooks.kind(event)
        payload = GitHubWebhooks.payload(event)

        # Show payload in REPL
        println("The webhook sent us a $(kind)! Take a look: ")
        dump(payload)

        # Respond to the PR event
        sha = payload["head"]["sha"] # sha for the head commit

        GitHubWebhooks.respond(event, sha, GitHubWebhooks.PENDING;
                               description="Doing some work on commit \$sha")


        result = 1 + 1 # do some kind of work (usually involving the payload)

        GitHubWebhooks.respond(event, sha, GitHubWebhooks.SUCCESS,
                               description="Here's the result: \$result")

        # If everything went well, let's return the proper HTTP status code
        return 200
    end

    # Start the tracker on port 8000
    GitHubWebhooks.run(tracker, 8000)
    ```
"""
immutable WebhookTracker
    server::HttpServer.Server
    function WebhookTracker(handler,
                            access_token::AbstractString,
                            secret::AbstractString,
                            user_name::AbstractString,
                            repo_name::AbstractString;
                            events::Vector{Event}=Event[])
        repo = user_name * "/" * repo_name

        authenticate(access_token)

        wrapper = HttpServer.HttpHandler() do request, response
            try
                if !(has_secret(request, secret))
                    return HttpCommon.Response(400, "invalid signature")
                end

                if !(has_event(request, events))
                    return HttpCommon.Response(400, "invalid event")
                end

                payload = Requests.json(request)

                if !(from_repo(payload, repo))
                    return HttpCommon.Response(400, "invalid repo")
                end

                return handler(EventClient(Event(request), payload, access_token))
            catch err
                println("SERVER ERROR: $err")
                return HttpCommon.Response(500)
            end
        end

        wrapper.events["listen"] = port -> begin
            println("Tracking webhook for repo $repo on $port;")
            println("Events being tracked: $events")
        end

        return new(HttpServer.Server(wrapper))
    end
end

function run(tracker::WebhookTracker, args...; kwargs...)
    return HttpServer.run(tracker.server, args...; kwargs...)
end

# Validation Functions #
#----------------------#

function has_secret(request::HttpCommon.Request, secret::AbstractString)
    payload_body = mapreduce(Char, string, request.data)
    secret_sha = "sha1="*Nettle.hexdigest("sha1", secret, payload_body)
    return has_sig_header(request) && sig_header(request) == secret_sha
end

function has_event(request::HttpCommon.Request, events::Vector{Event})
    return (has_event_header(request) &&
            (isempty(events) || in(Event(request), events)))
end

function from_repo(payload::Dict, repo::AbstractString)
    return repo_full_name(payload) == repo
end

end # module GitHubWebhooks
