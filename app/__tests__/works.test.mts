import assert from 'node:assert';
import { afterEach, beforeEach, describe, it, mock } from 'node:test';
import { pid } from 'node:process';

describe(`app ${pid}`, () => {
  let log: typeof console.log;
  let mockLog: ReturnType<typeof mock.fn<typeof console.log>>;

  beforeEach(() => {
    ({ log } = global.console);
    mockLog = mock.fn();
    global.console.log = mockLog;
  });

  afterEach(() => {
    global.console.log = log;
  });

  it('waves 3 times', async () => {
    await import('../index.mts');
    assert.deepStrictEqual(
      mockLog.mock.calls.map((call) => call.arguments),
      [['👋👋👋Hello, World!']]
    );
  });
});
