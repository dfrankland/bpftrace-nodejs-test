#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bpftrace nodejs pnpm jq

NODE_PATH="$(which node)"

PARENT_TO_CHILD_PID_MAP_TMP_FILE="$(mktemp)"

sudo -v

sudo bpftrace \
  -e "
  #ifndef BPFTRACE_HAVE_BTF
  #include <linux/sched.h>
  #endif
  
  tracepoint:syscalls:sys_enter_exec*
  {
    \$task = (struct task_struct *)curtask;
    printf(\"%d %d\n\", \$task->real_parent->pid, pid);
  }
  " \
  -o "$PARENT_TO_CHILD_PID_MAP_TMP_FILE" &

PARENT_TO_CHILD_PID_MAP_BPFTRACE_PID="$!"

TMP_FILE="$(mktemp)"

sudo bpftrace \
  -e "
  uprobe:$NODE_PATH:Builtins_MathRandom
  {
    @math_random_count_by_pid[pid] = count();
  }
  " \
  -o "$TMP_FILE" &

MATH_RANDOM_COUNT_BY_PID_BPFTRACE_PID="$!"

# Wait for probes to be attached
sleep 1

node --experimental-strip-types --test &

NODE_TEST_PID="$!"

wait "$NODE_TEST_PID"

if [ $? -ne 0 ]; then
  RESULT="failed"
else
  RESULT="passed"
fi

kill -SIGINT "$PARENT_TO_CHILD_PID_MAP_BPFTRACE_PID"
kill -SIGINT "$MATH_RANDOM_COUNT_BY_PID_BPFTRACE_PID"
wait "$PARENT_TO_CHILD_PID_MAP_BPFTRACE_PID"
wait "$MATH_RANDOM_COUNT_BY_PID_BPFTRACE_PID"

NODE_TEST_CHILDREN_PIDS=$(cat "$PARENT_TO_CHILD_PID_MAP_TMP_FILE" | grep "$NODE_TEST_PID" | awk '{print $2}')

TOTAL_RANDOM_COUNT=0
for NODE_TEST_CHILD_PID in $NODE_TEST_CHILDREN_PIDS; do
  if [ "$NODE_TEST_CHILD_PID" != "$NODE_TEST_PID" ]; then
    NODE_TEST_CHILD_PID_RANDOM_COUNT=$(cat "$TMP_FILE" | grep "$NODE_TEST_CHILD_PID" | awk '{print $2}')
    TOTAL_RANDOM_COUNT=$((TOTAL_RANDOM_COUNT + NODE_TEST_CHILD_PID_RANDOM_COUNT))
  fi
done

PROMPT="Is a test flaky if it $RESULT and had $TOTAL_RANDOM_COUNT \`Math.random()\` calls?"

echo "Asking AI: $PROMPT"

if [ -z "$OPENAI_API_KEY" ]; then
  echo "OPENAI_API_KEY is not set"
  exit 1
fi

pnpm --package=@openai/codex dlx codex --quiet "$PROMPT Only respond with yes or no and give your reasoning." | jq -r 'select(.status == "completed") | .content[] | select(.type == "output_text") | .text'

rm "$TMP_FILE"
rm "$PARENT_TO_CHILD_PID_MAP_TMP_FILE"
