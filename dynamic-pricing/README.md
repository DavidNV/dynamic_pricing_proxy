<div align="center">
   <img src="/img/logo.svg?raw=true" width=600 style="background-color:white;">
</div>

# Dynamic Pricing Proxy Service

A Ruby on Rails service acting as a rate-limit aware proxy between consumers and a costly upstream hotel room pricing API.

## Constrains

Besides the inherit cost the princig API has, we also have the following constraints/limitations.

| Constrain| Value |
| -------- | -------- |
| Upstream API Limit   | 1,000 request/day  |
| Required consumer throughput  | 10,000 request/day  |
| Rate validiy window | 5 minutes |

## Assumptions

1. Requests per day is treated as a fixed 24-hour window starting from the first upstream call of the day — the Redis key expires after 24 hours and resets automatically
2. The upstream host is provided via RATE_API_URL
3. The rate field is a string (e.g. "12000"). I didnt convert it to any number or currency.
4. Redis availability is required.

## Implementation considerations

The approach I will follow is usign Redis to cache the rates since Redis is native-TTL, seems pretty logic to go this route instead of using Rails.cache. I will consider also the quota for a 24 hours window.

### Cache Key Design

Each cached entry is keyed (Format TBD). TTL is set to 300 seconds (5 minutes) on write.
The service never serves a stale entry so if the TTL has expired, Redis will have evicted it and a fresh upstream fetch is triggered.

### Quota Awareness

The service tracks upstream call count in Redis with a 24-hour rolling TTL.


## Selected Strategy

The strategy I chose involved Redis and new endpoint in order to support to support batch requests.
In the case when we receive a single room request and it is not cached there is not much we can do but perform the upstream
request and store the value for five minutes but when the batching comes into place, say for 20 rooms of which 15 are missing, we avoid performing 15 call but retrieve 5 from cache and perform one call for the remaining 15. This also means that the cache compounds so the more user we have requesting it could, in theory at least, be less demanding for the upstream service.


## Implementation

### App Structure

| Class| Location | Responsibility
| -------- | -------- |-------- |
| PricingController | app/controllers/api/v1 | HTTP layer: params validation, routing to service, HTTP status mapping |
| PricingService | app/services/api/v1/ | Core business logic: Basically, cache resolution, upstream calls, quota checks |
| RateCache | lib/ | Redis inerface: In charge of caching rates (TTL=5min), and tracking quota(TTL=24Hr). I left it in the lib directory since it could be extended and I didnt consider it belonged to the business logic|
| RateApiClient | lib/ | Upstream HTTP client: Upstream HTTP client, support both single and batch calls now |
| SingleRateExtractor / BatchRateExtractor  | app/extractors/ | Utilies injection: Extractors are injected and retrieve the PricingService result |


### Design decisions

- Extractors: PricingService accepts a result_extractor object that will handle the result so it is not concerned with the kind of request is using him. The controller decides which extractor to inject based on the request format which means that it removes the PricingService responsibility of providing different responses.

- RateApiClient: Modifying it to translate base network exceptions into its domain exceptions. I figure, that this could be extende in some way to suggest retries or inform about quota abuse so just capturing the low-level exception in the Pricing0Service was going to leak some HTTP implementation outside of the actual HTTP upstream client.

- PricingServiec: As mentioned above, for single request not much can be done if they are not in the cache. Regarding batch request, before performing any upstream call, cache is checked. Requested params are partitioned and whatever is missing is upstreamed in one single call. 

- Quota counter: I learnt that Redis.incr is atomic which means that no other command can interrupt it mid-execution so as far as I could check the docs, atomic operations are thread-safe which goes well with the multiple Redis instances and the connection_pool

- Connection pooling: Not much to say here. I just checked online how to do it and first tiem doing it since most of the monolith I have worked on already have this set up.


## API Contract

### Single room lookup

```bash
GET /api/v1/pricing?period=Summer&hotel=FloatingPointResort&room=SingletonRoom
```

```json
{
  "period": "Summer",
  "hotel": "FloatingPointResort",
  "room": "SingletonRoom",
  "rate": "12000"
}
```

### Batch room lookup

```bash
POST /api/v1/pricing
Content-Type: application/json

{
  "attributes": [
    { "period": "Summer", "hotel": "FloatingPointResort", "room": "SingletonRoom" },
    { "period": "Winter", "hotel": "FloatingPointResort", "room": "BooleanTwin" }
  ]
}
```

```json
{
  "rates": [
    { "period": "Summer", "hotel": "FloatingPointResort", "room": "SingletonRoom", "rate": "12000" },
    { "period": "Winter", "hotel": "FloatingPointResort", "room": "BooleanTwin",   "rate": "46000" }
  ]
}
```

### Valid parameters

| Parameter| Value |
| -------- | -------- |
| period | Summer, Autumn, Winter, Spring |
| hotel | FloatingPointResort, GitawayHotel, RecursionRetreat |
| room | SingletonRoom, BooleanTwin, RestfulKing |

### Error Handling

| Scenario| HTTP Status | Message |
| -------- | -------- | -------- |
| Missing or invalid params | 400 Bad Request| Parameter is invalid|
| Rate not found for combination | 404 Not found | Rate not found for the requested period, hotel and room |
| Upstream timeout| 502 Bad Gateway | The upstream pricing service timed out, please try again later |
| Upstream connection refused | 502 Bad Gateway | The upstream pricing service is unavailable, please try again later |
| Upstream returns malformed JSON | 502 Bad Gateway | Received an invalid response from the upstream service |
| Daily quota exhausted | 503 Service Unavailable | Pricing is temporarily unavailable. Please try again later :( |



## Development plan

- [x] Init project repository
- [x] README: constraints, assumptions, implementation approach

### PricingService — Core behaviour
- [x] PricingService tests: happy path, single room (Red)
- [x] PricingService: implement happy path, single room (Green + Refactor)
- [x] PricingService tests: upstream error handling (5xx), timeout, bad JSON, missing rate (Red)
- [x] PricingService: implement error handling (Green + Refactor)

### RateApiClient — Catch support
- [x] RateApiClient: get_rates supporting single and batch
- [x] PricingService tests: internal batching via get_rates
- [x] PricingService: implement internal batching (Green + Refactor)
- [x] Extractors: SingleRateExtractor + BatchRateExtractor tested and implemented

### Caching
- [x] Environment: add Redis to docker-compose and Gemfile
- [x] Research: Redis + Puma threading model
- [x] RateCache tests: write, fetch, TTL, quota counter (Red)
- [x] RateCache: implement (Green + Refactor)
- [x] PricingService tests: cache hit, cache miss, quota exhausted (Red)
- [x] PricingService: integrate RateCache (Green + Refactor)

### Controller
- [x] PricingController tests: update response format
- [x] PricingController: fix response shape (Green + Refactor)
- [x] PricingController tests: upstream error scenarios handled correctly as HTTP status codes
- [x] PricingController: implement error response mapping (Green + Refactor)

## How to run

### How to build and run

```bash
docker compose up -d --build
```

### How to test

```bash
docker compose exec interview-dev bin/rails test
```

## Future work

So many things I couldn't do mainly because I am short on time but here are some ideas I had while coding.

1. Redis graceful degradation: if Redis is unavailable, fall back to calling upstream directly rather than returning an error.
2. Cache proactive refresh: At some point in time, we will notice that there are some searches that are more common that others. It would be amazing to use one of our upstream calls and perform a batch call so we have them available as soon as they going to expire. I thought about how to implement this but it seemd out of scope. Nice to have tho.
3. Quota alerting: As everything we do, observability should be a must so once a threshold is reached (say 75% or 80%) warnings should raised.
4. Distributed coalescing: Redis-based distributed lock (Redlock) to coordinate upstream calls across multiple processes or instances. I read about this while reading about connection_pool. I have never done it but it sounds interesting.
