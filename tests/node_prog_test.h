/*
 * ===============================================================
 *    Description:  Basic graph db node program.
 *
 *        Created:  01/23/2013 01:20:10 PM
 *
 *         Author:  Greg Hill, gdh39@cornell.edu
 *
 * Copyright (C) 2013, Cornell University, see the LICENSE file
 *                     for licensing agreement
 * ===============================================================
 */

#include "client/client.h"
#include <vector>
#include "node_prog/node_prog_type.h"
#include "node_prog/dijkstra_program.h"

void
node_prog_test()
{
    client c(CLIENT_PORT);
    auto edge_props = std::make_shared<std::vector<common::property>>();
    uint32_t weight_label = 0xACC;
    int i;

    size_t nodes[6];
    size_t edges[8];
    std::cout << "adding first node " << std::endl;
    for (i = 0; i < 6; i++) {
        nodes[i] = c.create_node();
        std::cout << "added node " << i<< std::endl;
    }

    std::cout << "adding first edge " << std::endl;
    edges[0] = c.create_edge(nodes[0], nodes[1]);
    std::cout << "adding first prop " << std::endl;
    c.add_edge_prop(nodes[0], edges[0], weight_label, 6);

    edges[1] = c.create_edge(nodes[0], nodes[2]);
    c.add_edge_prop(nodes[0], edges[1], weight_label, 5);

    edges[2] = c.create_edge(nodes[1], nodes[3]);
    c.add_edge_prop(nodes[1], edges[2], weight_label, 6);

    edges[3] = c.create_edge(nodes[1], nodes[4]);
    c.add_edge_prop(nodes[1], edges[3], weight_label, 7);

    edges[4] = c.create_edge(nodes[2], nodes[4]);
    c.add_edge_prop(nodes[2], edges[4], weight_label, 6);

    edges[5] = c.create_edge(nodes[3], nodes[2]);
    c.add_edge_prop(nodes[3], edges[5], weight_label, 6);

    edges[6] = c.create_edge(nodes[3], nodes[5]);
    c.add_edge_prop(nodes[3], edges[6], weight_label, 8);

    edges[7] = c.create_edge(nodes[4], nodes[5]);
    c.add_edge_prop(nodes[4], edges[7], weight_label, 6);

    std::cout << " starting path requests " << std::endl;

    std::cout << "nodes[0] = " << nodes[0] <<std::endl;
    std::cout << "nodes[1] = " << nodes[1] <<std::endl;
    std::cout << "nodes[2] = " << nodes[2] <<std::endl;
    std::cout << "nodes[3] = " << nodes[3] <<std::endl;
    std::cout << "nodes[4] = " << nodes[4] <<std::endl;
    std::cout << "nodes[5] = " << nodes[5] <<std::endl;

    std::vector<std::pair<uint64_t, node_prog::dijkstra_params>> initial_args;
    initial_args.emplace_back(std::make_pair(nodes[0], node_prog::dijkstra_params()));
    initial_args[0].second.dest_handle = nodes[5];
    initial_args[0].second.edge_weight_name = 41;
    node_prog::dijkstra_params* res = c.run_node_program(node_prog::DIJKSTRA, initial_args);
    assert(res->edge_weight_name == 42);
    delete res;
    /*
    auto retpair = c.shortest_path_request(nodes[0], nodes[5], weight_label, edge_props);
    std::cout <<retpair.first <<std::endl;
    //assert(retpair.first == 17);
    std::cout << "path is" << std::endl;
    for (auto label : retpair.second){
        std::cout << label.first << " cost: " << label.second << std::endl;
    }
    std::cout << "path end" << std::endl;
    //std::cout <<retpair.second <<std::endl;
    //assert(retpair.second == 17);
    std::cout << "Shortest path good" << std::endl;
    */

    /*
    auto retpair = c.widest_path_request(nodes[0], nodes[5], weight_label, edge_props);
    //assert(retpair.first == 6);
    std::cout <<retpair.first <<std::endl;
    std::cout << "path is" << std::endl;
    for (auto label : retpair.second){
        std::cout << label.first << " cost: " << label.second << std::endl;
    }
    std::cout << "path end" << std::endl;
    //assert(retpair.second == 6);
    std::cout << "Widest path good" << std::endl;
    */
}
