
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
            // take intersection of all specified predicates
            std::vector<std::string> params1;
            std::vector<std::string> params2;
            

            // response params
            uint32_t sum;
            db::remote_node prev_node;

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
        uint32_t out_count; // number of requests propagated
        db::remote_node prev_node; // previous node
        uint32_t recorded_sum;

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
