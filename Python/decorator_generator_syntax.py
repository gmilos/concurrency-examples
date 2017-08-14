#!/usr/bin/env python3
from asyncio import (
    as_completed,
    coroutine,
    ensure_future,
    get_event_loop,
    sleep,
)
from random import random


class Request(object):
    pass


class Response(object):
    def __init__(self, id_=0):
        self.id = id_

    def __repr__(self):
        return "Response(id_=%d)" % self.id


class ServiceError(Exception):
    pass


class NoDownstreamService(ServiceError):
    pass


class AllDowntstreamServicesFailed(ServiceError):
    pass


class DelayService(object):
    def __init__(self, id_, delay_secs):
        self.id = id_
        self.delay_secs = delay_secs

    @coroutine
    def service(self, request):
        yield from sleep(self.delay_secs)
        return Response(id_=self.id)


class FirstResponseService(object):
    def __init__(self, downstream_services):
        self._downstream_services = downstream_services

    @coroutine
    def service(self, request):
        if not self._downstream_services:
            raise NoDownstreamService()

        response_futures = [
            ensure_future(s.service(request))
            for s in self._downstream_services
        ]
        for completed_future in as_completed(response_futures):
            try:
                return (yield from completed_future)
            except Exception as e:
                print(e)
                continue
        raise AllDowntstreamServicesFailed()


@coroutine
def test():
    downstream_services = [DelayService(i, random()) for i in range(50)]
    frs = FirstResponseService(downstream_services)
    result = yield from frs.service(Request())
    print(result)


def main():
    loop = get_event_loop()
    loop.run_until_complete(test())
    # loop.close()


if __name__ == '__main__':
    main()
