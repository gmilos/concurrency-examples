from asyncio import get_event_loop
from unittest import TestCase

import async_await_syntax
import decorator_generator_syntax


EPSILON_SECS = 0.1


def do_test_excecution_time(test, coro):
    loop = get_event_loop()
    start_time = loop.time()
    loop.run_until_complete(coro())
    elapsed_time_secs = abs(loop.time() - start_time)
    test.assertAlmostEqual(elapsed_time_secs, 0.5, delta=0.5 + EPSILON_SECS)


class AsyncAwaitSyntaxTest(TestCase):
    def test_execution_time(self):
        do_test_excecution_time(self, async_await_syntax.test)


class DecoratorGeneratorSyntaxTest(TestCase):
    def test_execution_time(self):
        do_test_excecution_time(self, decorator_generator_syntax.test)
