#! /bin/bash
#
# start_weaver_support.sh
# Copyright (C) 2014 Ayush Dubey <dubey@cs.cornell.edu>
#

# get config file location
if [ $# -eq 1 ]
then
    config_file_args="-f $1"
else
    config_file_args=""
fi

# get config params
hyperdex_coord_ipaddr=$(weaver-parse-config -c hyperdex_coord_ipaddr $config_file_args)
hyperdex_coord_port=$(weaver-parse-config -c hyperdex_coord_port $config_file_args)
hyperdex_daemons_ipaddr=($(weaver-parse-config -c hyperdex_daemons_ipaddr $config_file_args))
hyperdex_daemons_port=($(weaver-parse-config -c hyperdex_daemons_port $config_file_args))
server_manager_ipaddr=$(weaver-parse-config -c server_manager_ipaddr $config_file_args)
server_manager_port=$(weaver-parse-config -c server_manager_port $config_file_args)
kronos_ipaddr=$(weaver-parse-config -c kronos_ipaddr $config_file_args)
kronos_port=$(weaver-parse-config -c kronos_port $config_file_args)

# hyperdex
mkdir -p hyperdex_start/coord
cd hyperdex_start

echo "Starting HyperDex coordinator at location $hyperdex_coord_ipaddr : $hyperdex_coord_port"
cd coord
rm -f *.log *.sst *.old CURRENT  LOCK  LOG  MANIFEST* replicant-daemon-*
hyperdex coordinator -l $hyperdex_coord_ipaddr -p $hyperdex_coord_port > /dev/null 2>&1
sleep 2

cd ..
num_daemons=${#hyperdex_daemons_ipaddr[*]}
for i in $(seq 1 $num_daemons);
do
    idx=$(($i-1))
    echo "Starting HyperDex daemon $i at location ${hyperdex_daemons_ipaddr[$idx]} : ${hyperdex_daemons_port[$idx]}"
    mkdir -p daemon$idx
    cd daemon$idx
    rm -f *.log *.sst CURRENT  LOCK  LOG  MANIFEST-000002 hyperdex-daemon-*
    hyperdex daemon --listen=${hyperdex_daemons_ipaddr[$idx]} --listen-port=${hyperdex_daemons_port[$idx]} \
                    --coordinator=$hyperdex_coord_ipaddr --coordinator-port=$hyperdex_coord_port \
                    > /dev/null 2>&1
    cd ..
done

sleep 1

echo 'Adding HyperDex spaces'

hyperdex add-space -h $hyperdex_coord_ipaddr -p $hyperdex_coord_port << EOF
space weaver_loc_mapping
key node
attributes
    int shard
subspace shard
create 8 partitions
tolerate 2 failures
EOF

hyperdex add-space -h $hyperdex_coord_ipaddr -p $hyperdex_coord_port << EOF
space weaver_client_mapping
key str_handle
attributes
    int handle
create 8 partitions
tolerate 2 failures
EOF

hyperdex add-space -h $hyperdex_coord_ipaddr -p $hyperdex_coord_port << EOF
space weaver_graph_data
key node
attributes
    string creat_time,
    string del_time,
    string properties,
    map(int, string) out_edges,
    set(int) in_nbrs,
    string tx_queue,
    int migr_status
tolerate 2 failures
EOF

hyperdex add-space -h $hyperdex_coord_ipaddr -p $hyperdex_coord_port << EOF
space weaver_shard_data
key shard
attributes
    map(int, int) qts,
    int migr_token
tolerate 2 failures
EOF

hyperdex add-space -h $hyperdex_coord_ipaddr -p $hyperdex_coord_port << EOF
space weaver_vt_tx_set_data
key vt
attributes
    set(int) tx_id_set
tolerate 2 failures
EOF

hyperdex add-space -h $hyperdex_coord_ipaddr -p $hyperdex_coord_port << EOF
space weaver_vt_tx_map_data
key tx_id
attributes
    string tx_data,
    int status
tolerate 2 failures
EOF


# server manager
cd ..
mkdir -p server_manager_start/daemon1
mkdir -p server_manager_start/client

echo "Starting server manager at location $server_manager_ipaddr : $server_manager_port"
cd server_manager_start
cd daemon1
rm -f *.log *.sst *.old CURRENT  LOCK  LOG  MANIFEST* replicant-daemon-*
replicant daemon --daemon --listen $server_manager_ipaddr --listen-port $server_manager_port > /dev/null 2>&1
sleep 1

cd ../client
replicant new-object -h $server_manager_ipaddr -p $server_manager_port weaver /usr/local/lib/libweaverservermanager.so


# kronos
cd ../..
mkdir -p kronos_start/daemon1
mkdir -p kronos_start/client

echo "Starting Kronos at location $kronos_ipaddr : $kronos_port"
cd kronos_start
cd daemon1
rm -f *.log *.sst *.old CURRENT  LOCK  LOG  MANIFEST* replicant-daemon-*
replicant daemon --daemon --listen $kronos_ipaddr --listen-port $kronos_port > /dev/null 2>&1
sleep 1

cd ../client
replicant new-object -h $kronos_ipaddr -p $kronos_port chronosd /usr/local/lib/libchronosd.so

cd ../../

echo 'Done startup.'
