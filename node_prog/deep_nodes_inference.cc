
#include "common/stl_serialization.h"
#include "node_prog/node_prog_type.h"
#include "node_prog/deep_nodes_inference.h"

using node_prog::search_type;
using node_prog::deep_node_infer_params;
using node_prog::deep_node_infer_state;
using node_prog::cache_response;

uint64_t deep_node_infer_params :: size() const 
{
    uint64_t toRet = message::size(params1)
        + message::size(params2)
        + message::size(sum)
        + message::size(prev_node);
    return toRet;
}

void deep_node_infer_params :: pack(e::packer& packer) const 
{
    message::pack_buffer(packer, params1);
    message::pack_buffer(packer, params2);
    message::pack_buffer(packer, sum);
    message::pack_buffer(packer, prev_node);

}

void deep_node_infer_params :: unpack(e::unpacker& unpacker)
{
    message::unpack_buffer(unpacker, params1);
    message::unpack_buffer(unpacker, params2);
    message::unpack_buffer(unpacker, sum);
    message::unpack_buffer(unpacker, prev_node);
}

deep_node_infer_state :: deep_node_infer_state()
    : visited(false)
    , out_count(0)
    , recorded_sum(0)

{ }


uint64_t
deep_node_infer_state:: size() const
{
    return message::size(visited)
         + message::size(out_count)
         + message::size(prev_node)
         + message::size(recorded_sum);
}

void
deep_node_infer_state :: pack(e::packer &packer) const
{
    message::pack_buffer(packer, visited);
    message::pack_buffer(packer, out_count);
    message::pack_buffer(packer, prev_node);
    message::pack_buffer(packer, recorded_sum);
}

void
deep_node_infer_state :: unpack(e::unpacker &unpacker)
{
    message::unpack_buffer(unpacker, visited);
    message::unpack_buffer(unpacker, out_count);
    message::unpack_buffer(unpacker, prev_node);
    message::unpack_buffer(unpacker, recorded_sum);
}



std::pair<search_type, std::vector<std::pair<db::remote_node, deep_node_infer_params>>>
node_prog :: deep_node_inference_program(
    node &n,
    db::remote_node &rn,
    deep_node_infer_params &params,
    std::function<deep_node_infer_state&()> state_getter,
    std::function<void(std::shared_ptr<node_prog::Cache_Value_Base>,
        std::shared_ptr<std::vector<db::remote_node>>, cache_key_t)>&,
    cache_response<Cache_Value_Base>*)
{   
    std::vector<std::pair<db::remote_node, deep_node_infer_params>> next;
   deep_node_infer_state &state = state_getter();

   // if (state.visited)
   // {
   //  if (state.out_count==0)
   //  {
   //      state.out_count=state.out_count+1;
   //      params.sum=params.sum+100;
   //      next.emplace_back(std::make_pair(rn, params));
   //  }
   //  else
   //  {
   //      params.sum=params.sum+100;
   //      next.emplace_back(std::make_pair(params.prev_node, params));
   //  }
   // }
   // else
   // {
   //  state.visited=true;
   //  params.sum=params.sum+100;
   //  next.emplace_back(std::make_pair(rn, params));
   // }


   if (state.visited)
   {
        state.recorded_sum=state.recorded_sum+params.sum;
        state.out_count=state.out_count-1;
        if  (state.out_count==0)
        {
           state.recorded_sum=state.recorded_sum+1;
           params.sum=state.recorded_sum;
           next.emplace_back(std::make_pair(state.prev_node, params));
        }
    
   }
   else
   {  
        state.prev_node=params.prev_node;
        params.prev_node = rn;
        state.visited=true;
        for (edge &e: n.get_edges()) 
        {
            state.out_count++;  
            next.emplace_back(std::make_pair(e.get_neighbor(), params));                  
        }

        if (state.out_count==0)
        {
            params.sum=1;
            next.emplace_back(std::make_pair(state.prev_node, params));
        }
   }


    

    
        
    return std::make_pair(search_type::DEPTH_FIRST, next);
}
