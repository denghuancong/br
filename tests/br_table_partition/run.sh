#!/bin/sh
#
# Copyright 2019 PingCAP, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu
DB="$TEST_NAME"
TABLE="usertable"
TABLE_COUNT=16
PATH="tests/$TEST_NAME:bin:$PATH"

echo "load data..."
DB=$DB TABLE=$TABLE TABLE_COUNT=$TABLE_COUNT prepare.sh

for i in $(seq $TABLE_COUNT); do
    row_count_ori[${i}]=$(run_sql "SELECT COUNT(*) FROM $DB.$TABLE${i};" | awk '/COUNT/{print $2}')
done

# backup full
echo "backup start..."
run_br --pd $PD_ADDR backup full -s "local://$TEST_DIR/$DB" --ratelimit 5 --concurrency 4

for i in $(seq $DB_COUNT); do
    run_sql "DROP DATABASE $DB${i};"
done

# restore full
echo "restore start..."
run_br restore full -s "local://$TEST_DIR/$DB" --pd $PD_ADDR

for i in $(seq $DB_COUNT); do
    row_count_new[${i}]=$(run_sql "SELECT COUNT(*) FROM $DB.$TABLE${i};" | awk '/COUNT/{print $2}')
done

fail=false
for i in $(seq $DB_COUNT); do
    if [ "${row_count_ori[i]}" != "${row_count_new[i]}" ];then
        fail=true
        echo "TEST: [$TEST_NAME] fail on database $DB${i}"
    fi
    echo "database $DB${i} [original] row count: ${row_count_ori[i]}, [after br] row count: ${row_count_new[i]}"
done

if $fail; then
    echo "TEST: [$TEST_NAME] failed!"
    exit 1
else
    echo "TEST: [$TEST_NAME] successed!"
fi

run_sql "DROP DATABASE $DB;"
