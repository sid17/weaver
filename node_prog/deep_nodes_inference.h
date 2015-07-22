
#ifndef weaver_node_prog_deep_node_infer_h_
#define weaver_node_prog_deep_node_infer_h_

#include <vector>
#include <string>

#include "db/remote_node.h"
#include "node_prog/base_classes.h"
#include "node_prog/node.h"
#include "node_prog/cache_response.h"

namespace node_prog
{
    class deep_node_infer_params : public Node_Parameters_Base 
    {
        public:
            // request params
            std::pair <std::string,std::string> network_description;
            // network description stores the handle names for the starting
            // and the ending nodes for the network
            std::vector<double> network_input;
            // contains the input to the network, it is a vector for the start node
            //  and single value for all other nodes of the network

            // std::vector<double> network_output;
            // contains the output to the network, it is a vector for the last node 
            //  and single value for all other nodes of the network

            int rank;
            // rank will be useful for the last node of the network

            std::string layerType;
            std::string layerOp;
            
            std::string activationFn;

            // would never need to cache
            bool search_cache() { return false; }
            cache_key_t cache_key() { return cache_key_t(); }
            uint64_t size() const;
            void pack(e::packer& packer) const;
            void unpack(e::unpacker& unpacker);
    };

       struct deep_node_infer_state: public virtual Node_State_Base
    {
        bool visited;
        uint32_t in_count; // number of requests propagated
        std::vector<double> recorded_output;

        // stacks the values for the last nodes 
        // single value for all other nodes of the network


        deep_node_infer_state();
        ~deep_node_infer_state() { }
        uint64_t size() const; 
        void pack(e::packer& packer) const ;
        void unpack(e::unpacker& unpacker);
    };

    std::pair<search_type, std::vector<std::pair<db::remote_node, deep_node_infer_params>>>
    deep_node_inference_program(
    node &n,
    db::remote_node &rn,
    deep_node_infer_params &params,
    std::function<deep_node_infer_state&()> state_getter,
    std::function<void(std::shared_ptr<node_prog::Cache_Value_Base>,
        std::shared_ptr<std::vector<db::remote_node>>, cache_key_t)>&,
    cache_response<Cache_Value_Base>*);
}

#endif
