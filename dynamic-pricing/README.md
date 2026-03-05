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

- [x] Init project repository.
- [x] First README with update with constrains, assumptions, and implementation sections.
- [ ] Research on how to scale Redis with Puma.
- [ ] PricingService Tests: support current scenario (Non-batched requests)(Red run).
- [ ] PricingService Tests: Add test for batched requests (Red run).
- [ ] PricingService: Add implementation for Batched requests (Green run and Refactor).
- [ ] Princing Endpoint Tests: add test for batched requests (Red run).
- [ ] Princing Endpoint: add implementation for batched requests (Green run and refactor).
- [ ] Environment: Add Redis to development env.
- [ ] RateCacheService (TBC) Tests: add test for caching behaviour.
- [ ] RateCacheService (TBC): implement caching behaviour for upstream quota and rates.
- [ ] PricingService Tests: Add test scenarios for cached requests.
- [ ] Princing Endpoint Tests: TBC: Perhaps mocks will be necessary but I consider the integration tests in PricingService would be enough

## How to run
TBA
