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

1. TBA

## Implementation considerations

The approach I will follow is usign Redis to cache the rates since Redis is native-TTL, seems pretty logic to go this route instead of using Rails.cache. I will consider also the quota for a 24 hours window.

### Cache Key Design
Each cached entry is keyed (Format TBD). TTL is set to 300 seconds (5 minutes) on write.
The service never serves a stale entry so if the TTL has expired, Redis will have evicted it and a fresh upstream fetch is triggered.

### Quota Awareness
The service tracks upstream call count in Redis with a 24-hour rolling TTL.

## Pending work

TBA

## Development plan

- [x] Init project repository
- [x] README: constraints, assumptions, implementation approach

# PricingService — Core behaviour
- [ ] PricingService tests: happy path, single room (Red)
- [ ] PricingService: implement happy path, single room (Green + Refactor)
- [ ] PricingService tests: upstream error handling (5xx), timeout, bad JSON, missing rate (Red)
- [ ] PricingService: implement error handling (Green + Refactor)

# RateApiClient — Catch support
- [ ] RateApiClient: extend get_rate to support multiple rooms (get_rates)
- [ ] PricingService tests: internal batching via get_rates (Red)
- [ ] PricingService: implement internal batching (Green + Refactor)

# Caching
- [ ] Environment: add Redis to docker-compose and Gemfile
- [ ] Research: Redis + Puma threading model
- [ ] RateCache (TBC) tests: write, fetch, TTL, quota counter (Red)
- [ ] RateCache (TBC): implement (Green + Refactor)
- [ ] PricingService tests: cache hit, cache miss, quota exhausted (Red)
- [ ] PricingService: integrate RateCache (Green + Refactor)

# Controller
- [ ] PricingController tests: update response format
- [ ] PricingController: fix response shape (Green + Refactor)
- [ ] PricingController tests: upstream error scenarios handled correctly as HTTP status codes
- [ ] PricingController: implement error response mapping (Green + Refactor)

## How to run
TBA
