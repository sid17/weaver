#! /bin/bash
#
# empty_graph.sh
# Copyright (C) 2014 Ayush Dubey <dubey@cs.cornell.edu>
#
# See the LICENSE file for licensing agreement
#

"$WEAVER_SRCDIR"/tests/sh/setup.sh
python "$WEAVER_SRCDIR"/tests/python/correctness/empty_graph_sanity_checks.py "$WEAVER_SRCDIR"/conf/weaver.yaml
status=$?
"$WEAVER_SRCDIR"/tests/sh/clean.sh

exit $status
