#define weaver_debug_
#include "common/stl_serialization.h"
#include "node_prog/node_prog_type.h"
#include "node_prog/deep_nodes_inference.h"
#include <math.h>
# include <algorithm>
// #include <iostream>
using node_prog::search_type;
using node_prog::deep_node_infer_params;
using node_prog::deep_node_infer_state;
using node_prog::cache_response;

uint64_t deep_node_infer_params :: size() const 
{
		uint64_t toRet = message::size(network_description)
				+ message::size(network_input)
				+ message::size(rank)
				+ message::size(layerType)
				+ message::size(layerOp)
				+ message::size(activationFn);
		return toRet;
}

void deep_node_infer_params :: pack(e::packer& packer) const 
{
		message::pack_buffer(packer, network_description);
		message::pack_buffer(packer, network_input);
		message::pack_buffer(packer, rank);
		message::pack_buffer(packer, layerType);
		message::pack_buffer(packer, layerOp);
		message::pack_buffer(packer, activationFn);
}

void deep_node_infer_params :: unpack(e::unpacker& unpacker)
{
		message::unpack_buffer(unpacker, network_description);
		message::unpack_buffer(unpacker, network_input);
		message::unpack_buffer(unpacker, rank);
		message::unpack_buffer(unpacker, layerType);
		message::unpack_buffer(unpacker, layerOp);
		message::unpack_buffer(unpacker, activationFn);
}

deep_node_infer_state :: deep_node_infer_state()
		: visited(false)
		, in_count(0)
		

{ }


uint64_t
deep_node_infer_state:: size() const
{
		return message::size(visited)
				 + message::size(in_count)
				 + message::size(recorded_output);
}

void
deep_node_infer_state :: pack(e::packer &packer) const
{
		message::pack_buffer(packer, visited);
		message::pack_buffer(packer, in_count);
		message::pack_buffer(packer, recorded_output);
}

void
deep_node_infer_state :: unpack(e::unpacker &unpacker)
{
		message::unpack_buffer(unpacker, visited);
		message::unpack_buffer(unpacker, in_count);
		message::unpack_buffer(unpacker, recorded_output);
}


double
getEdgePropVal(node_prog::edge &e, std::string propertyName)
{
		node_prog::prop_list plist = e.get_properties();
		for (std::vector<std::shared_ptr<node_prog::property>> pvec: plist) 
		{
			if (pvec.front()->key==propertyName)
			{
				double i_dec = std::stod (pvec.front()->value);
				return i_dec;
			}
		}
}


std::string
getEdgePropValStr(node_prog::edge &e, std::string propertyName)
{
		node_prog::prop_list plist = e.get_properties();
		for (std::vector<std::shared_ptr<node_prog::property>> pvec: plist) 
		{
			if (pvec.front()->key==propertyName)
			{
				return pvec.front()->value;
			}
		}
}




uint32_t
nodeIncount(node_prog::node &n)
{
		uint32_t count=0;
		for (node_prog::edge &e: n.get_edges()) 
			{
					std::string str1="edgeDirection";
					std::string str2="B";
					std::pair<std::string, std::string> p=std::make_pair(str1,str2);
					if (e.has_property(p))
					{
							count=count+1;  
					}      
			}
			return count;
}




double sigmoid(double x)
{
		 double exp_value;
		 double return_value;
		 /*** Exponential calculation ***/
		 exp_value = exp((double) -x);
		 /*** Final sigmoid value ***/
		 return_value = 1 / (1 + exp_value);
		 return return_value;
}

double identityFn(double x)
{
		 return x;
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

		std::cout << n.get_handle()<<std::endl;
		if (n.get_handle()==params.network_description.first)
		{
			// Start node of the network
				state.visited=true;
				std::vector<double> network_input(params.network_input);
				int counter=0;
				for (auto i = network_input.begin(); i != network_input.end(); ++i)
						{
						std::cout << *i << ' ';
						counter=counter+1;
						}
						std::cout << counter<<std::endl;

				params.network_input.clear();
				params.network_input.push_back(0.0);
				for (edge &e: n.get_edges()) 
				{
						uint32_t rank=(int)getEdgePropVal(e,"rank");
						double weight=getEdgePropVal(e,"weight");
						params.network_input.at(0)=weight*network_input.at(rank);
						params.rank=-1;
						params.layerType="init";
						params.layerOp="";
						next.emplace_back(std::make_pair(e.get_neighbor(), params));    
				}
		}
		else if (n.get_handle()==params.network_description.second)
		{
			// last node of the network
			if (!state.visited)
			{
				state.visited=true;
				state.in_count=nodeIncount(n);
				state.recorded_output.assign (state.in_count,0.0);   
			}
			state.recorded_output.at(params.rank)=params.network_input.at(0);
			state.in_count=state.in_count-1;
			if (state.in_count==0)
			{
				params.network_input=state.recorded_output;
				next.emplace_back(std::make_pair(db::coordinator, params));
			}
		}
		else
		{    
			// any general node of the network
			if (!state.visited)
				{
					state.visited=true;
					state.in_count=nodeIncount(n);
					if (params.layerType!="pool") 
						state.recorded_output.assign (1,0.0); 
				}

				if (params.layerType=="pool") 
					state.recorded_output.push_back(params.network_input.at(0));
				else
					state.recorded_output.at(0)=state.recorded_output.at(0)+params.network_input.at(0);
				
				state.in_count=state.in_count-1;
				if (state.in_count==0)
				{
					if (params.layerType=="pool") 
					{
							double maxVal=*(std::max_element(state.recorded_output.begin(), state.recorded_output.end()));
							std::cout << maxVal<<std::endl;
							state.recorded_output.assign (1,0.0); 
							state.recorded_output.at(0)=maxVal;
							params.network_input= state.recorded_output;

					}
					else
					{
						if (params.rank!=-1)
						{
							// first layer nodes , apply identity function to the input
							if (params.activationFn=="sigmoid")
							{
								state.recorded_output.at(0)=sigmoid(state.recorded_output.at(0));
							}
							else if (params.activationFn=="identity")
							{
								state.recorded_output.at(0)=identityFn(state.recorded_output.at(0));
							}
							
						}
					}
					
					for (edge &e: n.get_edges()) 
					{
						std::string str1="edgeDirection";
						std::string str2="F";
						std::pair<std::string, std::string> p=std::make_pair(str1,str2);

						if (e.has_property(p))
						{
							 double weight=getEdgePropVal(e,"weight");
							 params.network_input.at(0)=weight*state.recorded_output.at(0);
							 uint32_t rank=(int)getEdgePropVal(e,"rank");
							 std::string layerType=getEdgePropValStr(e,"layerType");
							 std::string layerOp=getEdgePropValStr(e,"layerOp");
							 params.rank=rank;
							 params.layerType=layerType;
							 params.layerOp=layerOp;
							 next.emplace_back(std::make_pair(e.get_neighbor(), params));
						}         
					}
				}       
		}  
		return std::make_pair(search_type::BREADTH_FIRST, next);
}
