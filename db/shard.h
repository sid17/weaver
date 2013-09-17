/*
 * ===============================================================
 *    Description:  Graph state corresponding to the partition
 *                  stored on this shard server.
 *
 *        Created:  07/25/2013 12:46:05 PM
 *
 *         Author:  Ayush Dubey, dubey@cs.cornell.edu
 *
 * Copyright (C) 2013, Cornell University, see the LICENSE file
 *                     for licensing agreement
 * ===============================================================
 */

#ifndef __SHARD_SERVER__
#define __SHARD_SERVER__

#include <vector>
#include <unordered_map>
#include <deque>
#include <po6/threads/mutex.h>
#include <po6/net/location.h>

#include "common/weaver_constants.h"
#include "common/vclock.h"
#include "common/message.h"
#include "common/busybee_infra.h"
#include "common/event_order.h"
#include "element/element.h"
#include "element/node.h"
#include "element/edge.h"
#include "state/program_state.h"
#include "threadpool/threadpool.h"
#include "deferred_write.h"

namespace db
{
    // Pending update request
    class graph_request
    {
        public:
            graph_request(enum message::msg_type, std::unique_ptr<message::message>);

        public:
            enum message::msg_type type;
            std::unique_ptr<message::message> msg;
    };

    inline
    graph_request :: graph_request(enum message::msg_type mt, std::unique_ptr<message::message> m)
        : type(mt)
        , msg(std::move(m))
    { }

    // graph partition state and associated data structures
    class shard
    {
        public:
            shard(uint64_t my_id);

            // Mutexes
        private:
            po6::threads::mutex update_mutex // shard update mutex
                , clock_mutex // vector clock/queue timestamp mutex
                , edge_map_mutex;
        public:
            po6::threads::mutex queue_mutex // exclusive access to thread pool queues
                , msg_count_mutex
                , migration_mutex;

            // Consistency
        public:
            void record_completed_transaction(uint64_t vt_id, uint64_t transaction_completed_id);
            element::node* acquire_node(uint64_t node_handle);
            void release_node(element::node *n);

            // Graph state
            uint64_t shard_id;
        private:
            std::unordered_map<uint64_t, element::node*> nodes; // node handle -> ptr to node object
            std::unordered_map<uint64_t, uint64_t> edges; // edge handle -> node handle
            db::thread::pool thread_pool;
        public:
            void add_write_request(uint64_t vt_id, thread::unstarted_thread *thr);
            void add_read_request(uint64_t vt_id, thread::unstarted_thread *thr);
            void create_node(uint64_t node_handle, vc::vclock &vclk, bool migrate);
            uint64_t delete_node(uint64_t node_handle, vc::vclock &vclk);
            uint64_t create_edge(uint64_t edge_handle, uint64_t local_node,
                    uint64_t remote_node, uint64_t remote_loc, vc::vclock &vclk);
            uint64_t create_reverse_edge(uint64_t edge_handle, uint64_t local_node,
                    uint64_t remote_node, uint64_t remote_loc, vc::vclock &vclk);
            uint64_t delete_edge(uint64_t edge_handle, uint64_t node_handle, vc::vclock &vclk);
            uint64_t get_node_count();

            // Permanent deletion
        private:
            //std::deque<perm_del> pending_deletes;

            // Migration
        public:
            bool current_migr, migr_token, migrated;
            uint64_t migr_chance, cur_node_count, prev_migr_node, migr_node, migr_shard;
            std::unordered_map<uint64_t, uint32_t> agg_msg_count;
            std::deque<std::pair<uint64_t, uint32_t>> sorted_nodes;
            std::unordered_map<uint64_t, uint64_t> request_count;
            std::unordered_map<uint64_t, def_write_lst> deferred_writes; // for migrating nodes
            std::unordered_map<uint64_t, std::vector<std::unique_ptr<message::message>>> deferred_reads; // for migrating nodes
            std::vector<uint64_t> nop_count;
            vc::vclock max_clk // to compare against for checking if node is deleted
                , zero_clk; // all zero clock for migration thread in queue
            void update_migrated_nbr_nonlocking(element::node *n, uint64_t edge, uint64_t rnode, uint64_t new_loc);
            void update_migrated_nbr(uint64_t lnode, uint64_t edge, uint64_t rnode, uint64_t new_loc);

            // node programs
            std::shared_ptr<node_prog::Packable_Deletable> 
                fetch_prog_req_state(node_prog::prog_type t, uint64_t request_id, uint64_t local_node_handle);
            void insert_prog_req_state(node_prog::prog_type t, uint64_t request_id, uint64_t local_node_handle,
                    std::shared_ptr<node_prog::Packable_Deletable> toAdd);
            void add_done_request(std::vector<std::pair<uint64_t, node_prog::prog_type>> &completed_requests, uint64_t del_id);
            bool check_done_request(uint64_t req_id);

            // Messaging infrastructure
        public:
            std::shared_ptr<po6::net::location> myloc;
            busybee_mta *bb; // Busybee instance used for sending and receiving messages
            busybee_returncode send(uint64_t loc, std::auto_ptr<e::buffer> buf);
    };

    inline
    shard :: shard(uint64_t my_id)
        : shard_id(my_id)
        , thread_pool(NUM_THREADS - 1)
        , current_migr(false)
        , migr_token(false)
        , migrated(false)
        , migr_chance(0)
        , cur_node_count(0)
        , nop_count(NUM_VTS, 0)
        , max_clk(MAX_UINT64, MAX_UINT64)
        , zero_clk(0, 0)
    {
        thread::pool::S = this;
        initialize_busybee(bb, shard_id, myloc);
        order::kronos_cl = chronos_client_create(KRONOS_IPADDR, KRONOS_PORT, KRONOS_NUM_VTS);
        assert(NUM_VTS == KRONOS_NUM_VTS);
    }

    // Consistency methods

    inline void
    shard :: record_completed_transaction(uint64_t vt_id, uint64_t transaction_completed_id)
    {
        //DEBUG << " going to record tx" << std::endl;
        thread_pool.record_completed_transaction(vt_id, transaction_completed_id);
        //DEBUG << "done record tx" << std::endl;
    }

    // find the node corresponding to given handle
    // lock and return the node
    // return NULL if node does not exist (possibly permanently deleted)
    inline element::node*
    shard :: acquire_node(uint64_t node_handle)
    {
        element::node *n = NULL;
        update_mutex.lock();
        if (nodes.find(node_handle) != nodes.end()) {
            n = nodes.at(node_handle);
            n->waiters++;
            while (n->in_use) {
                n->cv.wait();
            }
            n->waiters--;
            n->in_use = true;
        }
        update_mutex.unlock();

        return n;
    }

    // unlock the previously acquired node, and wake any waiting threads
    inline void
    shard :: release_node(element::node *n)
    {
        update_mutex.lock();
        n->in_use = false;
        if (n->waiters > 0) {
            n->cv.signal();
            update_mutex.unlock();
        } else if (n->permanently_deleted) {
            // TODO permanent deletion code check
            uint64_t node_handle = n->get_handle();
            nodes.erase(node_handle);
            cur_node_count--;
            update_mutex.unlock();
            msg_count_mutex.lock();
            agg_msg_count.erase(node_handle);
            msg_count_mutex.unlock();
            //permanent_node_delete(n);
        } else {
            update_mutex.unlock();
        }
    }


    // Graph state update methods

    inline void
    shard :: add_write_request(uint64_t vt_id, thread::unstarted_thread *thr)
    {
        thread_pool.add_write_request(vt_id, thr);
    }

    inline void
    shard :: add_read_request(uint64_t vt_id, thread::unstarted_thread *thr)
    {
        thread_pool.add_read_request(vt_id, thr);
    }

    inline void
    shard :: create_node(uint64_t node_handle, vc::vclock &vclk, bool migrate)
    {
        element::node *new_node = new element::node(node_handle, vclk, &update_mutex);
        update_mutex.lock();
        if (!nodes.emplace(node_handle, new_node).second) {
            DEBUG << "node already exists in node map!" << std::endl;
        }
        cur_node_count++;
        update_mutex.unlock();
        if (migrate) {
            // TODO
            migration_mutex.lock();
            migr_node = node_handle;
            migration_mutex.unlock();
        } else {
            new_node->state = element::node::mode::STABLE;
            new_node->prev_locs.reserve(NUM_SHARDS);
            for (uint64_t i = 0; i < NUM_SHARDS; i++) {
                new_node->prev_locs.emplace_back(0);
            }
            new_node->prev_locs.at(shard_id-SHARD_ID_INCR) = 1;
        }
        release_node(new_node);
    }

    inline uint64_t
    shard :: delete_node(uint64_t node_handle, vc::vclock &tdel)
    {
        uint64_t ret;
        element::node *n = acquire_node(node_handle);
        if (n == NULL) {
            // node is being migrated
            migration_mutex.lock();
            if (deferred_writes.find(node_handle) == deferred_writes.end()) {
                deferred_writes.emplace(node_handle, def_write_lst());
            }
            deferred_writes.at(node_handle).emplace_back(deferred_write(message::NODE_DELETE_REQ, tdel, node_handle));
            migration_mutex.unlock();
        } else {
            ret = ++n->update_count;
            n->update_del_time(tdel);
            n->updated = true;
            ret = 0;
            release_node(n);
        }
        // TODO permanent deletion
        return ret;
    }

    inline uint64_t
    shard :: create_edge(uint64_t edge_handle, uint64_t local_node,
            uint64_t remote_node, uint64_t remote_loc, vc::vclock &vclk)
    {
        uint64_t ret;
        element::node *n = acquire_node(local_node);
        if (n == NULL) {
            // node is being migrated
            migration_mutex.lock();
            if (deferred_writes.find(local_node) == deferred_writes.end()) {
                deferred_writes.emplace(local_node, def_write_lst());
            }
            deferred_writes.at(local_node).emplace_back(deferred_write(message::EDGE_CREATE_REQ, vclk,
                    edge_handle, local_node, remote_node, remote_loc));
            migration_mutex.unlock();
        } else {
            ret = ++n->update_count;
            element::edge *new_edge = new element::edge(edge_handle, vclk,
                    remote_loc, remote_node);
            n->add_edge(new_edge, true);
            n->updated = true;
            release_node(n);
            //edge_map_mutex.lock();
            //edges.emplace(edge_handle, local_node);
            //edge_map_mutex.unlock();
            message::message msg;
            message::prepare_message(msg, message::REVERSE_EDGE_CREATE,
                vclk, edge_handle, remote_node, local_node, shard_id);
            send(remote_loc, msg.buf);
            ret = 0;
        }
        return ret;
    }

    inline uint64_t
    shard :: create_reverse_edge(uint64_t edge_handle, uint64_t local_node,
            uint64_t remote_node, uint64_t remote_loc, vc::vclock &vclk)
    {
        uint64_t ret;
        element::node *n = acquire_node(local_node);
        if (n == NULL) {
            // node is being migrated
            migration_mutex.lock();
            if (deferred_writes.find(local_node) == deferred_writes.end()) {
                deferred_writes.emplace(local_node, def_write_lst());
            }
            deferred_writes.at(local_node).emplace_back(deferred_write(message::REVERSE_EDGE_CREATE, vclk,
                    edge_handle, local_node, remote_node, remote_loc));
            migration_mutex.unlock();
        } else {
            ret = ++n->update_count;
            element::edge *new_edge = new element::edge(edge_handle, vclk,
                    remote_loc, remote_node);
            n->add_edge(new_edge, false);
            n->updated = true;
            ret = 0;
            release_node(n);
        }
        //if (ret == 0) {
        //    edge_map_mutex.lock();
        //    edges.emplace(edge_handle, local_node);
        //    edge_map_mutex.unlock();
        //}
        return ret;
    }

    inline uint64_t
    shard :: delete_edge(uint64_t edge_handle, uint64_t node_handle, vc::vclock &tdel)
    {
        uint64_t ret;
        //edge_map_mutex.lock();
        //node_handle = (edges.find(edge_handle) == edges.end()) ? 0 : edges.at(edge_handle);
        //edge_map_mutex.unlock();
        element::node *n = acquire_node(node_handle);
        if (n == NULL) {
            // node is being migrated XXX don't know node handle!
            migration_mutex.lock();
            if (deferred_writes.find(node_handle) == deferred_writes.end()) {
                deferred_writes.emplace(node_handle, def_write_lst());
            }
            deferred_writes.at(node_handle).emplace_back(deferred_write(message::EDGE_DELETE_REQ, tdel, node_handle));
            migration_mutex.unlock();
        } else {
            ret = ++n->update_count;
            element::edge *e = n->out_edges.at(edge_handle);
            e->update_del_time(tdel);
            n->updated = true;
            n->dependent_del++;
            ret = 0;
            release_node(n);
        }
        // TODO permanent deletion
        return ret;
    }

    // migration methods

    inline void
    shard :: update_migrated_nbr_nonlocking(element::node *n, uint64_t edge_handle, uint64_t remote_node, uint64_t new_loc)
    {
        bool found = false;
        if (n->out_edges.find(edge_handle) != n->out_edges.end()) {
            element::edge *e = n->out_edges.at(edge_handle);
            assert(e->nbr.handle == remote_node);
            n->msg_count[e->nbr.loc-1] = 0;
            e->msg_count = 0;
            e->nbr.loc = new_loc;
            found = true;
        }
        if (n->in_edges.find(edge_handle) != n->in_edges.end()) {
            element::edge *e = n->in_edges.at(edge_handle);
            assert(e->nbr.handle == remote_node);
            n->msg_count[e->nbr.loc-1] = 0;
            e->msg_count = 0;
            e->nbr.loc = new_loc;
            found = true;
        }
        if (!found) {
            DEBUG << "Neighbor not found for migrated node " << remote_node << std::endl;
        }
    }

    inline void
    shard :: update_migrated_nbr(uint64_t local_node, uint64_t edge_handle, uint64_t remote_node, uint64_t new_loc)
    {
        element::node *n = acquire_node(local_node);
        update_migrated_nbr_nonlocking(n, edge_handle, remote_node, new_loc);
        release_node(n);
    }

    // node program
    state::program_state node_prog_req_state; 

    inline std::shared_ptr<node_prog::Packable_Deletable>
    shard :: fetch_prog_req_state(node_prog::prog_type t, uint64_t request_id, uint64_t local_node_handle)
    {
        DEBUG << "trying to fetch node program state" << std::endl;
        return node_prog_req_state.get_state(t, request_id, local_node_handle);
    }

    inline void
    shard :: insert_prog_req_state(node_prog::prog_type t, uint64_t request_id, uint64_t local_node_handle,
        std::shared_ptr<node_prog::Packable_Deletable> toAdd)
    {
        node_prog_req_state.put_state(t, request_id, local_node_handle, toAdd);
    }

    inline void
    shard :: add_done_request(std::vector<std::pair<uint64_t, node_prog::prog_type>> &completed_requests, uint64_t del_id)
    {
        DEBUG << "starting done req at shard " << shard_id << std::endl;
        node_prog_req_state.done_requests(completed_requests, del_id);
        DEBUG << "ending done req at shard " << shard_id << std::endl;
    }

    inline bool
    shard :: check_done_request(uint64_t req_id)
    {
        return node_prog_req_state.check_done_request(req_id);
    }

    // messaging methods

    inline busybee_returncode
    shard :: send(uint64_t loc, std::auto_ptr<e::buffer> msg)
    {
        busybee_returncode ret;
        if ((ret = bb->send(loc, msg)) != BUSYBEE_SUCCESS) {
            std::cerr << "msg send error: " << ret << std::endl;
        }
        return ret;
    }

    inline thread::unstarted_thread*
    get_read_thr(std::vector<thread::pqueue_t> &read_queues, std::vector<uint64_t> &last_ids)
    {
        thread::unstarted_thread * thr = NULL;
        //DEBUG << "checking read queues" << std::endl;
        for (uint64_t vt_id = 0; vt_id < NUM_VTS; vt_id++) {
            thread::pqueue_t &pq = read_queues.at(vt_id);
            if (!pq.empty()) {
                DEBUG << "read queue " << vt_id << " not empty. has top id " << pq.top()->priority 
                    << " and needs less than " << last_ids[vt_id] << " to pop" << std::endl;
            }
            if (!pq.empty() && pq.top()->priority < last_ids[vt_id]) {
                DEBUG << "read queue " << vt_id << " has node prog that can be run" << std::endl;
                thr = read_queues.at(vt_id).top();
                read_queues.at(vt_id).pop();
                return thr;
            }
        }
        return thr;
    }

    inline thread::unstarted_thread*
    get_write_thr(thread::pool *tpool)
    {
        thread::unstarted_thread *thr = NULL;
        std::vector<vc::vclock> timestamps;
        timestamps.reserve(NUM_VTS);
        std::vector<thread::pqueue_t> &write_queues = tpool->write_queues;
        // get next jobs from each queue
        //DEBUG << "going to collect jobs from write queues" << std::endl;
        for (uint64_t vt_id = 0; vt_id < NUM_VTS; vt_id++) {
            thread::pqueue_t &pq = write_queues.at(vt_id);
            // wait for queue to receive at least one job
            if (pq.empty()) { // can't write if one of the pq's is empty
                //DEBUG << "waiting for queue to fill" << std::endl;
                return NULL;
            } else {
                thr = pq.top();
                // check for correct ordering of queue timestamp (which is priority for thread)
                //DEBUG << "waiting for qts to increment" << std::endl;
                if (!tpool->check_qts(vt_id, thr->priority)) {
                    return NULL;
                }
            }
        }
        // all write queues are good to go, compare timestamps
        for (uint64_t vt_id = 0; vt_id < NUM_VTS; vt_id++) {
            timestamps.emplace_back(write_queues.at(vt_id).top()->vclock);
        }
        //DEBUG << "going to compare vt" << std::endl;
        uint64_t exec_vt_id = (NUM_VTS == 1) ? 0 : order::compare_vts(timestamps);
        thr = write_queues.at(exec_vt_id).top();
        write_queues.at(exec_vt_id).pop();
        //DEBUG << "going to return\n";
        return thr;
    }

    inline thread::unstarted_thread*
    get_read_or_write(thread::pool *tpool)
    {
        thread::unstarted_thread *thr = get_read_thr(tpool->read_queues, tpool->last_ids);
        if (thr == NULL) {
            thr = get_write_thr(tpool);
        }
        return thr;
    }

    // work loop for threads in thread pool
    // check all queues are ready to go
    // if yes, execute the earliest job, else sleep and wait for incoming jobs
    // "earliest" is decided by comparison functions using vector clocks and Kronos
    void
    thread :: worker_thread_loop(thread::pool *tpool)
    {
        thread::unstarted_thread *thr = NULL;
        po6::threads::cond &c = tpool->queue_cond;
        while (true) {
            //DEBUG << "worker thread loop begin" << std::endl;
            // TODO better queue locking needed
            tpool->thread_loop_mutex.lock(); // only one thread accesses queues
            // TODO add job method should be non-blocking on this mutex
            tpool->queue_mutex.lock(); // prevent more jobs from being added
            while((thr = get_read_or_write(tpool)) == NULL) {
                c.wait();
            }
            tpool->queue_mutex.unlock();
            tpool->thread_loop_mutex.unlock();
            (*thr->func)(thr->arg);
            // queue timestamp is incremented by the thread, upon finishing
            // because the decision to increment or not is based on thread-specific knowledge
            // moreover, when to increment can also be decided by thread only
            // this could potentially decrease throughput, because other ops in the
            // threadpool are blocked, waiting for this thread to increment qts
            delete thr;
        }
    }
}

#endif
