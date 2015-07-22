# distutils: language = c++

# 
# ===============================================================
#    Description:  Python wrapper for a Weaver client.
# 
#        Created:  11/10/2013 01:40:00 AM
# 
#         Author:  Ayush Dubey, dubey@cs.cornell.edu
# 
# Copyright (C) 2013, Cornell University, see the LICENSE file
#                     for licensing agreement
# ===============================================================
# 

from __future__ import print_function
import sys

# begin <stolen from Hyperdex/bindings/client.pyx>
cdef extern from 'stdint.h':

    ctypedef short int int16_t
    ctypedef unsigned short int uint16_t
    ctypedef int int32_t
    ctypedef unsigned int uint32_t
    ctypedef long int int64_t
    ctypedef unsigned long int uint64_t
    ctypedef long unsigned int size_t
    cdef uint64_t UINT64_MAX

# end <stolen from Hyperdex/bindings/client.pyx>

from libcpp.string cimport string
from cython.operator cimport dereference as deref, preincrement as inc

cdef extern from '<utility>' namespace 'std':
    cdef cppclass pair[T1, T2]:
        T1 first
        T2 second

cdef extern from '<memory>' namespace 'std':
    cdef cppclass unique_ptr[T]:
        pass
    cdef cppclass shared_ptr[T]:
        T& operator*()
        pass

cdef extern from '<vector>' namespace 'std':
    cdef cppclass vector[T]:
        cppclass iterator:
            iterator()
            T operator*()
            iterator operator++()
            bint operator==(iterator)
            bint operator!=(iterator)
        vector()
        void push_back(T&)
        T& operator[](int)
        T& at(int)
        iterator begin()
        iterator end()
        size_t size()
        void reserve(size_t)
        void clear()

cdef extern from '<unordered_map>' namespace 'std':
    cdef cppclass unordered_map[T1, T2]:
        cppclass iterator:
            pair[T1, T2] operator*()
            iterator operator++()
            bint operator==(iterator)
            bint operator!=(iterator)
        unordered_map()
        iterator begin()
        iterator end()
        size_t size()
        pair[iterator, bint] emplace(T1, T2)

cdef extern from '<unordered_set>' namespace 'std':
    cdef cppclass unordered_set[T]:
        cppclass iterator:
            T operator*()
            iterator operator++()
            bint operator==(iterator)
            bint operator!=(iterator)
        unordered_set()
        iterator begin()
        iterator end()
        size_t size()

cdef extern from '<deque>' namespace 'std':
    cdef cppclass deque[T]:
        cppclass iterator:
            T operator*()
            iterator operator++()
            bint operator==(iterator)
            bint operator!=(iterator)
        iterator begin()
        iterator end()
        void push_back(T&)
        void clear()

def initialize_member_remotenode(param):
    if param is None:
        return RemoteNode()
    else:
        return param

def initialize_member_dict(param):
    if isinstance(param, dict):
        return param
    else:
        return {}

def initialize_member_list(param):
    if isinstance(param, list):
        return param
    else:
        return []


cdef extern from 'node_prog/node_prog_type.h' namespace 'node_prog':
    cdef enum prog_type:
        DEFAULT
        REACHABILITY
        PATHLESS_REACHABILITY
        N_HOP_REACHABILITY
        TRIANGLE_COUNT
        DIJKSTRA
        CLUSTERING
        TWO_NEIGHBORHOOD
        READ_NODE_PROPS
        READ_EDGES_PROPS

cdef extern from 'common/types.h':
    ctypedef string node_handle_t
    ctypedef string edge_handle_t
    ctypedef string cache_key_t

cdef extern from 'db/remote_node.h' namespace 'db':
    cdef cppclass remote_node:
        remote_node(uint64_t loc, const node_handle_t &i)
        remote_node()
        uint64_t loc
        node_handle_t handle
    cdef remote_node coordinator

cdef extern from 'node_prog/property.h' namespace 'node_prog':
    cdef cppclass property:
        string key
        string value
        property()
        property(const string &k, const string &v)

cdef extern from 'client/datastructures.h' namespace 'cl':
    cdef cppclass edge:
        string handle
        string start_node
        string end_node
        vector[shared_ptr[property]] properties
    cdef cppclass hash_edge:
        pass
    cdef cppclass equals_edge:
        pass

    cdef cppclass node:
        string handle
        vector[shared_ptr[property]] properties
        unordered_map[string, edge] out_edges
        unordered_set[string] aliases

class Edge:
    def __init__(self, handle='', start_node='', end_node='', properties=None):
        self.handle = handle
        self.start_node = start_node
        self.end_node = end_node
        self.properties = initialize_member_dict(properties)

class Node:
    def __init__(self, handle='', properties=None, out_edges=None, aliases=None):
        self.handle = handle
        self.properties = initialize_member_dict(properties)
        self.out_edges = initialize_member_dict(out_edges)
        self.aliases = initialize_member_list(aliases)

cdef extern from 'common/property_predicate.h' namespace 'predicate':
    cdef enum relation:
        EQUALS
        LESS
        GREATER
        LESS_EQUAL
        GREATER_EQUAL
        STARTS_WITH
        ENDS_WITH
        CONTAINS

    cdef cppclass prop_predicate:
        string key
        string value
        relation rel

def enum(**enums):
    return type('Enum', (), enums)

Relation = enum(EQUALS=1, LESS=2, GREATER=3, LESS_EQUAL=4, GREATER_EQUAL=5, STARTS_WITH=6, ENDS_WITH=7, CONTAINS=8)

class PropPredicate:
    def __init__(self, key, value, rel):
        self.key = key
        self.value = value
        self.rel = rel

class RemoteNode:
    def __init__(self, handle='', loc=0):
        self.handle = handle
        self.loc = loc

cdef extern from 'node_prog/reach_program.h' namespace 'node_prog':
    cdef cppclass reach_params:
        reach_params()
        bint _search_cache
        cache_key_t _cache_key
        bint returning
        remote_node prev_node
        node_handle_t dest
        vector[pair[string, string]] edge_props
        uint32_t hops
        bint reachable
        vector[remote_node] path

class ReachParams:
    def __init__(self, returning=False, prev_node=None, dest='', hops=0, reachable=False, caching=False, edge_props=None, path=None):
        self._search_cache = caching
        self._cache_key = dest
        self.returning = returning
        self.prev_node = initialize_member_remotenode(prev_node)
        self.dest = dest
        self.hops = hops
        self.reachable = reachable
        self.edge_props = initialize_member_list(edge_props)
        self.path = initialize_member_list(path)

cdef extern from 'node_prog/pathless_reach_program.h' namespace 'node_prog':
    cdef cppclass pathless_reach_params:
        pathless_reach_params()
        bint returning
        remote_node prev_node
        node_handle_t dest
        vector[pair[string, string]] edge_props
        bint reachable

class PathlessReachParams:
    def __init__(self, returning=False, prev_node=None, dest='', reachable=False, edge_props=None):
        self.returning = returning
        self.prev_node = initialize_member_remotenode(prev_node)
        self.dest = dest
        self.reachable = reachable
        self.edge_props = initialize_member_list(edge_props)

cdef extern from 'node_prog/clustering_program.h' namespace 'node_prog':
    cdef cppclass clustering_params:
        bint _search_cache
        cache_key_t _cache_key
        bint is_center
        remote_node center
        bint outgoing
        vector[node_handle_t] neighbors
        double clustering_coeff

class ClusteringParams:
    def __init__(self, is_center=True, outgoing=True, caching=False, clustering_coeff=0.0):
        self._search_cache = caching
        self.is_center = is_center
        self.outgoing = outgoing
        self.clustering_coeff = clustering_coeff

cdef extern from 'node_prog/two_neighborhood_program.h' namespace 'node_prog':
    cdef cppclass two_neighborhood_params:
        bint _search_cache
        bint cache_update
        string prop_key
        uint32_t on_hop
        bint outgoing
        remote_node prev_node
        vector[pair[node_handle_t, string]] responses

class TwoNeighborhoodParams:
    def __init__(self, caching=False, cache_update=False, prop_key='', on_hop=0, outgoing=True, prev_node=None, responses=None):
        self._search_cache = caching;
        self.cache_update = cache_update;
        self.prop_key = prop_key
        self.on_hop = on_hop
        self.outgoing = outgoing
        self.prev_node = initialize_member_remotenode(prev_node)
        self.responses = initialize_member_list(responses)

cdef extern from 'node_prog/read_node_props_program.h' namespace 'node_prog':
    cdef cppclass read_node_props_params:
        vector[string] keys
        vector[pair[string, string]] node_props

class ReadNodePropsParams:
    def __init__(self, keys=None, node_props=None):
        self.keys = initialize_member_list(keys)
        self.node_props = initialize_member_list(node_props)

cdef extern from 'node_prog/read_n_edges_program.h' namespace 'node_prog':
    cdef cppclass read_n_edges_params:
        uint64_t num_edges
        vector[pair[string, string]] edges_props
        vector[edge_handle_t] return_edges

class ReadNEdgesParams:
    def __init__(self, num_edges=UINT64_MAX, edges_props=None, return_edges=None):
        self.num_edges = num_edges
        self.edges_props = initialize_member_list(edges_props)
        self.return_edges = initialize_member_list(return_edges)

cdef extern from 'node_prog/edge_count_program.h' namespace 'node_prog':
    cdef cppclass edge_count_params:
        vector[pair[string, string]] edges_props
        uint64_t edge_count

class EdgeCountParams:
    def __init__(self, edges_props=None, edge_count=0):
        initialize_member_list(edges_props, self.edges_props)
        self.edge_count = edge_count

cdef extern from 'node_prog/edge_get_program.h' namespace 'node_prog':
    cdef cppclass edge_get_params:
        vector[node_handle_t] nbrs
        vector[edge_handle_t] request_edges
        vector[edge] response_edges
        vector[pair[string, string]] properties


cdef extern from 'node_prog/deep_nodes_inference.h' namespace 'node_prog':
    cdef cppclass deep_node_infer_params:
        pair[string, string] network_description
        vector[double] network_input
        uint32_t rank
        string activationFn


class EdgeGetParams:
    def __init__(self, nbrs=None, request_edges=None, response_edges=None):
        self.nbrs = initialize_member_list(nbrs)
        self.request_edges = initialize_member_list(request_edges)
        self.response_edges = initialize_member_list(response_edges)

cdef extern from 'node_prog/node_get_program.h' namespace 'node_prog':
    cdef cppclass node_get_params:
        bint props
        bint edges
        bint aliases
        node node

cdef extern from 'node_prog/traverse_with_props.h' namespace 'node_prog':
    cdef cppclass traverse_props_params:
        traverse_props_params()
        remote_node prev_node
        deque[vector[string]] node_aliases
        deque[vector[pair[string, string]]] node_props
        deque[vector[pair[string, string]]] edge_props
        bint collect_nodes
        bint collect_edges
        unordered_set[node_handle_t] return_nodes
        unordered_set[edge_handle_t] return_edges

class TraversePropsParams:
    def __init__(self, node_aliases=None, node_props=None, edge_props=None, return_nodes=None, return_edges=None, collect_n=False, collect_e=False):
        self.node_aliases = initialize_member_list(node_aliases)
        self.node_props = initialize_member_list(node_props)
        self.edge_props = initialize_member_list(edge_props)
        self.return_nodes = initialize_member_list(return_nodes)
        self.return_edges = initialize_member_list(return_edges)
        self.collect_nodes = collect_n
        self.collect_edges = collect_e

cdef extern from 'node_prog/discover_paths.h' namespace 'node_prog':
    cdef cppclass discover_paths_params:
        discover_paths_params()
        node_handle_t dest
        uint32_t path_len
        vector[prop_predicate] node_preds
        vector[prop_predicate] edge_preds
        unordered_map[string, vector[edge]] paths
        remote_node prev_node
        node_handle_t src

cdef extern from 'node_prog/get_btc_block.h' namespace 'node_prog':
    cdef cppclass get_btc_block_params:
        get_btc_block_params()
        node_handle_t block
        node node
        vector[pair[vector[edge], vector[edge]]] txs

cdef extern from 'client/weaver/weaver_returncode.h':
    cdef enum weaver_client_returncode:
        WEAVER_CLIENT_SUCCESS
        WEAVER_CLIENT_INITERROR
        WEAVER_CLIENT_ABORT
        WEAVER_CLIENT_ACTIVETX
        WEAVER_CLIENT_NOACTIVETX
        WEAVER_CLIENT_NOAUXINDEX
        WEAVER_CLIENT_NOTFOUND
        WEAVER_CLIENT_LOGICALERROR
        WEAVER_CLIENT_DISRUPTED
        WEAVER_CLIENT_INTERNALMSGERROR
    const char* weaver_client_returncode_to_string(weaver_client_returncode code)

cdef extern from 'client/client.h' namespace 'cl':
    cdef cppclass client:
        client(const char *coordinator, uint16_t port, const char *config_file) except +
        void initialize_logging()

        weaver_client_returncode begin_tx()
        weaver_client_returncode create_node(string &handle, const vector[string] &aliases)
        weaver_client_returncode create_edge(string &handle, const string &node1, const string &node1_alias, const string &node2, const string &node2_alias)
        weaver_client_returncode delete_node(const string &node, const string &alias)
        weaver_client_returncode delete_edge(const string &edge, const string &node, const string &node_alias)
        weaver_client_returncode set_node_property(const string &node, const string &alias, string key, string value)
        weaver_client_returncode set_edge_property(const string &node, const string &alias, const string &edge, string key, string value)
        weaver_client_returncode add_alias(const string &alias, const string &node)
        weaver_client_returncode end_tx() nogil
        weaver_client_returncode abort_tx()
        weaver_client_returncode run_reach_program(vector[pair[string, reach_params]] &initial_args, reach_params&) nogil
        weaver_client_returncode run_pathless_reach_program(vector[pair[string, pathless_reach_params]] &initial_args, pathless_reach_params&) nogil
        weaver_client_returncode run_clustering_program(vector[pair[string, clustering_params]] &initial_args, clustering_params&) nogil
        weaver_client_returncode run_two_neighborhood_program(vector[pair[string, two_neighborhood_params]] &initial_args, two_neighborhood_params&) nogil
        weaver_client_returncode read_node_props_program(vector[pair[string, read_node_props_params]] &initial_args, read_node_props_params&) nogil
        weaver_client_returncode read_n_edges_program(vector[pair[string, read_n_edges_params]] &initial_args, read_n_edges_params&) nogil
        weaver_client_returncode edge_count_program(vector[pair[string, edge_count_params]] &initial_args, edge_count_params&) nogil
        weaver_client_returncode edge_get_program(vector[pair[string, edge_get_params]] &initial_args, edge_get_params&) nogil


        weaver_client_returncode deepNodesInference(vector[pair[string, deep_node_infer_params]] &initial_args, deep_node_infer_params&) nogil


        weaver_client_returncode node_get_program(vector[pair[string, node_get_params]] &initial_args, node_get_params&) nogil
        weaver_client_returncode traverse_props_program(vector[pair[string, traverse_props_params]] &initial_args, traverse_props_params&) nogil
        weaver_client_returncode discover_paths_program(vector[pair[string, discover_paths_params]] &initial_args, discover_paths_params&) nogil
        weaver_client_returncode get_btc_block_program(vector[pair[string, get_btc_block_params]] &initial_args, get_btc_block_params&) nogil
        weaver_client_returncode start_migration()
        weaver_client_returncode single_stream_migration()
        weaver_client_returncode exit_weaver()
        weaver_client_returncode get_node_count(vector[uint64_t]&)
        bint aux_index()

class WeaverError(Exception):
    def __init__(self, status, message=None):
        self._status = status
        self._symbol = weaver_client_returncode_to_string(self._status)
        self._message = message

    def status(self):
        return self._status

    def symbol(self):
        return self._symbol

    def message(self):
        return self._message

    def __str__(self):
        error_str = 'WeaverError: ' + self._symbol
        if self._message:
            error_str += ' (%s)' % self._message
        return error_str

    def __repr__(self):
        return str(self)

cdef class Client:
    cdef client *thisptr
    cdef string traverse_start_node
    cdef object traverse_node_aliases
    cdef object traverse_node_props
    cdef object traverse_edge_props
    def __cinit__(self, coordinator, port, config_file=''):
        self.thisptr = new client(coordinator, port, config_file)
        self.traverse_start_node = ''
        self.traverse_node_aliases = []
        self.traverse_node_props = []
        self.traverse_edge_props = []

    def __dealloc__(self):
        del self.thisptr

    def initialize_logging(self):
        self.thisptr.initialize_logging()

    def begin_tx(self):
        code = self.thisptr.begin_tx()
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'tx error')

    def create_node(self, handle='', **kwargs):
        cdef string cc_handle
        aliases = []
        if handle != '':
            cc_handle = handle
        if 'aliases' in kwargs:
            aliases = kwargs['aliases']
        code = self.thisptr.create_node(cc_handle, aliases)
        if code == WEAVER_CLIENT_SUCCESS:
            return str(cc_handle)
        else:
            raise WeaverError(code, 'tx error')

    def create_edge(self, node1=None, node2=None, handle=None, **kwargs):
        handle1 = ''
        handle2 = ''
        alias1 = ''
        alias2 = ''
        cdef string cc_handle
        if node1 is None:
            if 'node1_alias' not in kwargs:
                raise WeaverError(WEAVER_CLIENT_LOGICALERROR, 'provide either node handle or node alias')
            else:
                alias1 = kwargs['node1_alias']
        else:
            handle1 = node1
        if node2 is None:
            if 'node2_alias' not in kwargs:
                raise WeaverError(WEAVER_CLIENT_LOGICALERROR, 'provide either node handle or node alias')
            else:
                alias2 = kwargs['node2_alias']
        else:
            handle2 = node2
        if handle is not None:
            cc_handle = handle
        code = self.thisptr.create_edge(cc_handle, handle1, alias1, handle2, alias2)
        if code == WEAVER_CLIENT_SUCCESS:
            return str(cc_handle)
        else:
            raise WeaverError(code, 'tx error')

    def delete_node(self, handle='', **kwargs):
        alias = ''
        if handle is None:
            if 'alias' not in kwargs:
                raise WeaverError(WEAVER_CLIENT_LOGICALERROR, 'provide either node handle or node alias')
            else:
                alias = kwargs['alias']
        code = self.thisptr.delete_node(handle, alias)
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'tx error')

    def delete_edge(self, edge, node='', **kwargs):
        alias = ''
        if node == '' and 'node_alias' in kwargs:
            alias = kwargs['node_alias']
        code = self.thisptr.delete_edge(edge, node, alias)
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'tx error')

    def set_node_property(self, key, value, node='', **kwargs):
        alias = ''
        if node == '':
            if 'node_alias' not in kwargs:
                raise WeaverError(WEAVER_CLIENT_LOGICALERROR, 'provide either node handle or node alias')
            else:
                alias = kwargs['node_alias']
        code = self.thisptr.set_node_property(node, alias, str(key), str(value))
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'tx error')

    def set_node_properties(self, properties, node='', **kwargs):
        alias = ''
        if node == '':
            if 'node_alias' not in kwargs:
                raise WeaverError(WEAVER_CLIENT_LOGICALERROR, 'provide either node handle or node alias')
            else:
                alias = kwargs['node_alias']
        if not isinstance(properties, dict):
            raise WeaverError(WEAVER_CLIENT_LOGICALERROR, 'properties should be a dictionary')
        else:
            for k in properties:
                if isinstance(properties[k], list):
                    for v in properties[k]:
                        self.set_node_property(str(k), str(v), node, node_alias=alias)
                else:
                    self.set_node_property(str(k), str(properties[k]), node, node_alias=alias)

    def set_edge_property(self, edge, key, value, node='', **kwargs):
        alias = ''
        if node == '' and 'node_alias' in kwargs:
            alias = kwargs['node_alias']
        code = self.thisptr.set_edge_property(node, alias, edge, str(key), str(value))
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'tx error')

    def set_edge_properties(self, edge, properties, node='', **kwargs):
        alias = ''
        if 'node_alias' in kwargs:
            alias = kwargs['node_alias']
        if not isinstance(properties, dict):
            raise WeaverError(WEAVER_CLIENT_LOGICALERROR, 'properties should be a dictionary')
        else:
            for k in properties:
                if isinstance(properties[k], list):
                    for v in properties[k]:
                        self.set_edge_property(edge, str(k), str(v), node, node_alias=alias)
                else:
                    self.set_edge_property(edge, str(k), str(properties[k]), node, node_alias=alias)

    def add_alias(self, alias, node):
        code = self.thisptr.add_alias(alias, node)
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'add_alias transaction error')

    def end_tx(self):
        with nogil:
            code = self.thisptr.end_tx()
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'transaction commit error')

    def abort_tx(self):
        code = self.thisptr.abort_tx()
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'transaction abort error')

    def run_reach_program(self, init_args):
        cdef vector[pair[string, reach_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, reach_params] arg_pair
        for rp in init_args:
            arg_pair.first = rp[0]
            arg_pair.second._search_cache = rp[1]._search_cache
            arg_pair.second._cache_key = rp[1].dest
            arg_pair.second.returning = rp[1].returning
            arg_pair.second.dest = rp[1].dest
            arg_pair.second.reachable = rp[1].reachable
            arg_pair.second.prev_node = coordinator
            arg_pair.second.edge_props.clear()
            arg_pair.second.edge_props.reserve(len(rp[1].edge_props))
            for p in rp[1].edge_props:
                arg_pair.second.edge_props.push_back(p)
            c_args.push_back(arg_pair)

        cdef reach_params c_rp
        with nogil:
            code = self.thisptr.run_reach_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        foundpath = []
        for rn in c_rp.path:
            foundpath.append(rn.handle)
        response = ReachParams(path=foundpath, hops=c_rp.hops, reachable=c_rp.reachable)
        return response

    # warning! set prev_node loc to vt_id if somewhere in params
    def run_pathless_reach_program(self, init_args):
        cdef vector[pair[string, pathless_reach_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, pathless_reach_params] arg_pair
        for rp in init_args:
            arg_pair.first = rp[0]
            arg_pair.second.returning = rp[1].returning
            arg_pair.second.dest = rp[1].dest
            arg_pair.second.reachable = rp[1].reachable
            arg_pair.second.prev_node = coordinator
            arg_pair.second.edge_props.clear()
            arg_pair.second.edge_props.reserve(len(rp[1].edge_props))
            for p in rp[1].edge_props:
                arg_pair.second.edge_props.push_back(p)
            c_args.push_back(arg_pair)

        cdef pathless_reach_params c_rp
        with nogil:
            code = self.thisptr.run_pathless_reach_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = PathlessReachParams(reachable=c_rp.reachable)
        return response

    def run_clustering_program(self, init_args):
        cdef vector[pair[string, clustering_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, clustering_params] arg_pair
        for cp in init_args:
            arg_pair.first = cp[0]
            arg_pair.second._search_cache = cp[1]._search_cache 
            arg_pair.second._cache_key = cp[0] # cache key is center node handle
            arg_pair.second.is_center = cp[1].is_center
            arg_pair.second.outgoing = cp[1].outgoing
            c_args.push_back(arg_pair)

        cdef clustering_params c_rp
        with nogil:
            code = self.thisptr.run_clustering_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = ClusteringParams(clustering_coeff=c_rp.clustering_coeff)
        return response

    def run_two_neighborhood_program(self, init_args):
        cdef vector[pair[string, two_neighborhood_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, two_neighborhood_params] arg_pair
        for rp in init_args:
            arg_pair.first = rp[0]
            arg_pair.second._search_cache = rp[1]._search_cache
            arg_pair.second.cache_update = rp[1].cache_update
            arg_pair.second.prop_key = rp[1].prop_key
            arg_pair.second.on_hop = rp[1].on_hop
            arg_pair.second.outgoing = rp[1].outgoing
            arg_pair.second.prev_node = coordinator
            c_args.push_back(arg_pair)

        cdef two_neighborhood_params c_rp
        with nogil:
            code = self.thisptr.run_two_neighborhood_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = TwoNeighborhoodParams(responses = c_rp.responses)
        return response

    def read_node_props(self, init_args):
        cdef vector[pair[string, read_node_props_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, read_node_props_params] arg_pair
        for rp in init_args:
            arg_pair.first = rp[0]
            arg_pair.second.keys = rp[1].keys
            c_args.push_back(arg_pair)

        cdef read_node_props_params c_rp
        with nogil:
            code = self.thisptr.read_node_props_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = ReadNodePropsParams(node_props=c_rp.node_props)
        return response

    def read_n_edges(self, init_args):
        cdef vector[pair[string, read_n_edges_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, read_n_edges_params] arg_pair
        for rp in init_args:
            arg_pair.first = rp[0]
            arg_pair.second.num_edges = rp[1].num_edges
            arg_pair.second.edges_props.clear()
            arg_pair.second.edges_props.reserve(len(rp[1].edges_props))
            for p in rp[1].edges_props:
                arg_pair.second.edges_props.push_back(p)
            c_args.push_back(arg_pair)

        cdef read_n_edges_params c_rp
        with nogil:
            code = self.thisptr.read_n_edges_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = ReadNEdgesParams(return_edges=c_rp.return_edges)
        return response

    def edge_count(self, init_args):
        cdef vector[pair[string, edge_count_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, edge_count_params] arg_pair
        for rp in init_args:
            arg_pair.first = rp[0]
            arg_pair.second.edges_props.clear()
            arg_pair.second.edges_props.reserve(len(rp[1].edges_props))
            for p in rp[1].edges_props:
                arg_pair.second.edges_props.push_back(p)
            c_args.push_back(arg_pair)

        cdef edge_count_params c_rp
        with nogil:
            code = self.thisptr.edge_count_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = EdgeCountParams(edge_count=c_rp.edge_count)
        return response

    cdef __convert_vector_props_to_dict(self, vector[shared_ptr[property]] pvec, pdict):
        cdef vector[shared_ptr[property]].iterator prop_iter = pvec.begin()
        while prop_iter != pvec.end():
            key = str(deref(deref(prop_iter)).key)
            value = str(deref(deref(prop_iter)).value)
            if key in pdict:
                pdict[key].append(value)
            else:
                pdict[key] = [value]
            inc(prop_iter)

    cdef __convert_edge_to_client_edge(self, edge c_edge, py_edge):
        py_edge.handle = str(c_edge.handle)
        py_edge.start_node = str(c_edge.start_node)
        py_edge.end_node = str(c_edge.end_node)
        self.__convert_vector_props_to_dict(c_edge.properties, py_edge.properties)

    def get_edges(self, nbrs=None, edges=None, properties=None, node=''):
        if node == '':
            if edges is None:
                raise WeaverError('provide one of node handle, node alias, or edge handle')
            elif not isinstance(edges, list):
                raise WeaverError('edges should be list')
            else:
                node = edges[0]
        cdef pair[string, edge_get_params] arg_pair
        arg_pair.first = node
        if nbrs is not None:
            arg_pair.second.nbrs.reserve(len(nbrs))
            for nbr in nbrs:
                arg_pair.second.nbrs.push_back(nbr)
        if edges is not None:
            arg_pair.second.request_edges.reserve(len(edges))
            for e in edges:
                arg_pair.second.request_edges.push_back(e)
        cdef pair[string, string] prop
        if properties is not None:
            arg_pair.second.properties.reserve(len(properties))
            for p in self.__convert_props_dict_to_list(properties):
                prop.first = p[0]
                prop.second = p[1]
                arg_pair.second.properties.push_back(p)
        cdef vector[pair[string, edge_get_params]] c_args
        c_args.push_back(arg_pair)

        cdef edge_get_params c_rp
        with nogil:
            code = self.thisptr.edge_get_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = []
        cdef vector[edge].iterator resp_iter = c_rp.response_edges.begin()
        while resp_iter != c_rp.response_edges.end():
            response.append(Edge())
            self.__convert_edge_to_client_edge(deref(resp_iter), response[-1])
            inc(resp_iter)
        return response

    def neuralNetInfer(self,input=[],start_node="start_node",end_node="end_node",activationFn="sigmoid"):
        if start_node == '':
            raise WeaverError('node alias is required to begin execution')
            
        cdef vector[double] inputVec=input
       
        cdef pair[string, deep_node_infer_params] arg_pair
        arg_pair.first = start_node
        arg_pair.second.network_description.first=start_node
        arg_pair.second.network_description.second=end_node
        arg_pair.second.network_input=inputVec
        arg_pair.second.activationFn=activationFn

        

       

        cdef vector[pair[string, deep_node_infer_params]] c_args
        c_args.push_back(arg_pair)

        cdef deep_node_infer_params c_rp
        with nogil:
            code = self.thisptr.deepNodesInference(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        return c_rp.network_input


    def get_edge(self, edge, node=''):
        if node == '':
            node = edge
        response = self.get_edges(nbrs=None, edges=[edge], properties=None, node=node)
        if len(response) == 1:
            return response[0]
        else:
            raise WeaverError('edge not found or some other error')

    cdef __convert_node_to_client_node(self, node c_node, py_node):
        py_node.handle = str(c_node.handle)
        self.__convert_vector_props_to_dict(c_node.properties, py_node.properties)
        cdef unordered_map[string, edge].iterator edge_iter = c_node.out_edges.begin()
        while edge_iter != c_node.out_edges.end():
            new_edge = Edge()
            self.__convert_edge_to_client_edge(deref(edge_iter).second, new_edge)
            py_node.out_edges[str(deref(edge_iter).first)] = new_edge
            inc(edge_iter)
        cdef unordered_set[string].iterator alias_iter = c_node.aliases.begin()
        while alias_iter != c_node.aliases.end():
            py_node.aliases.append(str(deref(alias_iter)))
            inc(alias_iter)

    def get_node(self, node, get_props=True, get_edges=True, get_aliases=True):
        cdef pair[string, node_get_params] arg_pair
        arg_pair.second.props = get_props
        arg_pair.second.edges = get_edges
        arg_pair.second.aliases = get_aliases
        arg_pair.first = node
        cdef vector[pair[string, node_get_params]] c_args
        c_args.push_back(arg_pair)

        cdef node_get_params c_rp
        with nogil:
            code = self.thisptr.node_get_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        new_node = Node()
        self.__convert_node_to_client_node(c_rp.node, new_node)
        return new_node

    def get_node_properties(self, node):
        return self.get_node(node, get_edges=False, get_aliases=False).properties

    def get_node_edges(self, node):
        return self.get_node(node, get_props=False, get_aliases=False).out_edges

    def get_node_aliases(self, node):
        return self.get_node(node, get_props=False, get_edges=False).aliases

    def traverse_props(self, init_args):
        cdef vector[pair[string, traverse_props_params]] c_args
        c_args.reserve(len(init_args))
        cdef pair[string, traverse_props_params] arg_pair
        cdef vector[pair[string, string]] props
        cdef vector[string] aliases
        for rp in init_args:
            arg_pair.first = rp[0]
            arg_pair.second.prev_node = coordinator
            arg_pair.second.collect_nodes = rp[1].collect_nodes
            arg_pair.second.collect_edges = rp[1].collect_edges
            arg_pair.second.node_aliases.clear()
            arg_pair.second.node_props.clear()
            arg_pair.second.edge_props.clear()
            for p_vec in rp[1].node_aliases:
                aliases.clear()
                aliases.reserve(len(p_vec))
                for p in p_vec:
                    aliases.push_back(p)
                arg_pair.second.node_aliases.push_back(aliases)
            for p_vec in rp[1].node_props:
                props.clear()
                props.reserve(len(p_vec))
                for p in p_vec:
                    props.push_back(p)
                arg_pair.second.node_props.push_back(props)
            for p_vec in rp[1].edge_props:
                props.clear()
                props.reserve(len(p_vec))
                for p in p_vec:
                    props.push_back(p)
                arg_pair.second.edge_props.push_back(props)
            c_args.push_back(arg_pair)

        cdef traverse_props_params c_rp
        with nogil:
            code = self.thisptr.traverse_props_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        response = TraversePropsParams()
        for n in c_rp.return_nodes:
            response.return_nodes.append(n)
        for e in c_rp.return_edges:
            response.return_edges.append(e)
        return response

    cdef __convert_pred_to_c_pred(self, pred, prop_predicate &pred_c):
        pred_c.key = pred.key
        pred_c.value = pred.value
        if pred.rel == Relation.EQUALS:
            pred_c.rel = EQUALS
        elif pred.rel == Relation.LESS:
            pred_c.rel = LESS
        elif pred.rel == Relation.GREATER:
            pred_c.rel = GREATER
        elif pred.rel == Relation.LESS_EQUAL:
            pred_c.rel = LESS_EQUAL
        elif pred.rel == Relation.GREATER_EQUAL:
            pred_c.rel = GREATER_EQUAL
        elif pred.rel == Relation.STARTS_WITH:
            pred_c.rel = STARTS_WITH
        elif pred.rel == Relation.ENDS_WITH:
            pred_c.rel = ENDS_WITH
        elif pred.rel == Relation.CONTAINS:
            pred_c.rel = CONTAINS

    def discover_paths(self, start_node, end_node, path_len=None, node_preds=None, edge_preds=None):
        cdef vector[pair[string, discover_paths_params]] c_args
        cdef pair[string, discover_paths_params] arg_pair
        arg_pair.first = start_node
        arg_pair.second.prev_node = coordinator
        arg_pair.second.dest = end_node
        arg_pair.second.src = start_node
        if path_len is not None:
            arg_pair.second.path_len = path_len
        cdef prop_predicate pred_c
        if node_preds is not None:
            arg_pair.second.node_preds.reserve(len(node_preds))
            for pred in node_preds:
                self.__convert_pred_to_c_pred(pred, pred_c)
                arg_pair.second.node_preds.push_back(pred_c)
        if edge_preds is not None:
            arg_pair.second.edge_preds.reserve(len(edge_preds))
            for pred in edge_preds:
                self.__convert_pred_to_c_pred(pred, pred_c)
                arg_pair.second.edge_preds.push_back(pred_c)
        c_args.push_back(arg_pair)

        cdef discover_paths_params c_rp
        with nogil:
            code = self.thisptr.discover_paths_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        ret_paths = {}
        cdef unordered_map[string, vector[edge]].iterator path_iter = c_rp.paths.begin()
        cdef vector[edge].iterator edge_iter
        while path_iter != c_rp.paths.end():
            cur_node = str(deref(path_iter).first)
            cur_edges = []
            edge_iter = deref(path_iter).second.begin()
            while edge_iter != deref(path_iter).second.end():
                cur_edges.append(Edge())
                self.__convert_edge_to_client_edge(deref(edge_iter), cur_edges[-1])
                inc(edge_iter)
            ret_paths[cur_node] = cur_edges
            inc(path_iter)
        return ret_paths

    def get_btc_block(self, block):
        cdef vector[pair[string, get_btc_block_params]] c_args
        cdef pair[string, get_btc_block_params] arg_pair
        arg_pair.first = block
        arg_pair.second.block = block
        c_args.push_back(arg_pair)

        cdef get_btc_block_params c_rp
        with nogil:
            code = self.thisptr.get_btc_block_program(c_args, c_rp)

        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code, 'node prog error')

        new_node = Node()
        self.__convert_node_to_client_node(c_rp.node , new_node)
        txs = []
        cdef vector[edge].iterator edge_iter
        cdef vector[pair[vector[edge], vector[edge]]].iterator tx_iter = c_rp.txs.begin()
        while tx_iter != c_rp.txs.end():
            in_txs = []
            out_txs = []

            edge_iter = deref(tx_iter).first.begin()
            while edge_iter != deref(tx_iter).first.end():
                in_txs.append(Edge())
                self.__convert_edge_to_client_edge(deref(edge_iter), in_txs[-1])
                inc(edge_iter)

            edge_iter = deref(tx_iter).second.begin()
            while edge_iter != deref(tx_iter).second.end():
                out_txs.append(Edge())
                self.__convert_edge_to_client_edge(deref(edge_iter), out_txs[-1])
                inc(edge_iter)

            txs.append((in_txs, out_txs))
            inc(tx_iter)
        return (new_node, txs)

    def __enumerate_paths_recursive(self, paths, src, dst, path_len, visited):
        ret_paths = []
        if path_len > 0:
            if src not in paths:
                return []
            for e in paths[src]:
                if e.end_node == dst or paths[e.end_node] == []:
                    ret_paths.append([e])
                elif e.end_node not in visited:
                    cur_visited = visited.copy()
                    cur_visited.add(e.end_node)
                    child_paths = self.__enumerate_paths_recursive(paths, e.end_node, dst, path_len-1, cur_visited)
                    if child_paths:
                        for p in child_paths:
                            ret_paths.append([e] + p)
        return ret_paths

    def enumerate_paths(self, paths, src, dst, path_len):
        return self.__enumerate_paths_recursive(paths, src, dst, path_len, set())

    def enumerate_path_vertices(self, paths):
        return [[(e.start_node, e.end_node) for e in p] for p in paths]

    def traverse(self, start_node, node_props=None, node_aliases=None):
        self.traverse_start_node = start_node
        self.traverse_node_aliases = []
        self.traverse_node_props = []
        self.traverse_edge_props = []
        if node_aliases is None:
            self.traverse_node_aliases.append([])
        else:
            self.traverse_node_aliases.append(node_aliases)
        if node_props is None:
            self.traverse_node_props.append({})
        else:
            self.traverse_node_props.append(node_props)
        return self

    def out_edge(self, edge_props=None):
        if edge_props is None:
            self.traverse_edge_props.append({})
        else:
            self.traverse_edge_props.append(edge_props)
        return self

    def node(self, node_props=None, node_aliases=None):
        if node_aliases is None:
            self.traverse_node_aliases.append([])
        else:
            self.traverse_node_aliases.append(node_aliases)
        if node_props is None:
            self.traverse_node_props.append({})
        else:
            self.traverse_node_props.append(node_props)
        return self

    def __convert_props_dict_to_list(self, dprops):
        lprops = []
        if dprops and isinstance(dprops, dict):
            for k in dprops:
                if isinstance(dprops[k], list):
                    for v in dprops[k]:
                        lprops.append((k,v))
                else:
                    lprops.append((k, dprops[k]))
        return lprops

    def __convert_props_dictlist_to_listlist(self, dprops):
        lprops = []
        for d in dprops:
            lprops.append(self.__convert_props_dict_to_list(d))
        return lprops

    def execute(self, collect_nodes=False, collect_edges=False):
        num_node_aliases = len(self.traverse_node_aliases)
        num_node_props = len(self.traverse_node_props)
        num_edge_props = len(self.traverse_edge_props)
        if ((num_node_aliases != num_node_props) or not ((num_node_props == (num_edge_props+1)) or (num_node_props == num_edge_props))):
            raise WeaverError(WEAVER_CLIENT_LOGICALERROR)

        params = TraversePropsParams(self.traverse_node_aliases, \
                                     self.__convert_props_dictlist_to_listlist(self.traverse_node_props), \
                                     self.__convert_props_dictlist_to_listlist(self.traverse_edge_props), \
                                     collect_n=collect_nodes, \
                                     collect_e=collect_edges)
        response = self.traverse_props([(self.traverse_start_node, params)])
        return response.return_nodes + response.return_edges

    def collect(self):
        return self.execute(collect_nodes=True, collect_edges=True)

    def collect_nodes(self):
        return self.execute(collect_nodes=True)

    def collect_edges(self):
        return self.execute(collect_edges=True)

    def start_migration(self):
        code = self.thisptr.start_migration()
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code)
    def single_stream_migration(self):
        code = self.thisptr.single_stream_migration()
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code)
    def exit_weaver(self):
        code = self.thisptr.exit_weaver()
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code)
    def get_node_count(self):
        cdef vector[uint64_t] node_count
        code = self.thisptr.get_node_count(node_count)
        if code != WEAVER_CLIENT_SUCCESS:
            raise WeaverError(code)
        count = []
        cdef vector[uint64_t].iterator iter = node_count.begin()
        while iter != node_count.end():
            count.append(deref(iter))
            inc(iter)
        return count
    def aux_index(self):
        return self.thisptr.aux_index()
