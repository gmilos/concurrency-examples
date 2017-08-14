import asyncio
import time
import unittest

import async_await_syntax
import decorator_generator_syntax


EPSILON_SECS = 0.1

def do_test_excecution_time(test, coro):
    loop = asyncio.get_event_loop()
    start_time = loop.time()
    result = loop.run_until_complete(coro())
    elapsed_time_secs = abs(loop.time() - start_time)
    test.assertTrue(elapsed_time_secs <= 1 + EPSILON_SECS)
    

class AsyncAwaitSyntaxTest(unittest.TestCase):
    def test_execution_time(self):
        do_test_excecution_time(self, async_await_syntax.test)


class DecoratorGeneratorSyntaxTest(unittest.TestCase):
    def test_execution_time(self):
        do_test_excecution_time(self, decorator_generator_syntax.test)
