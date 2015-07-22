// deep_node_infer_state &state = state_getter();
    // std::vector<std::pair<db::remote_node, deep_node_infer_params>> next;

   // if (state.visited)
   // {
   //  // state.accumulatedSum=state.accumulatedSum+params.sum;
   //  // state.out_count=state.out_count-1;
   //  // if  (state.out_count==0)
   //  // {
   //  //    state.accumulatedSum=state.accumulatedSum+1;
   //  //    params.sum=state.accumulatedSum;
   //  //    next.emplace_back(std::make_pair(state.prev_node, params));

   //  // }
   //  params.sum=100;
   // }
   // else
   // {  
   //      // state.prev_node=params.prev_node;
   //      // params.prev_node = rn;
   //      // state.visited=true;
   //      // for (edge &e: n.get_edges()) 
   //      // {
   //      //     state.out_count++;  
   //      //     next.emplace_back(std::make_pair(e.get_neighbor(), params));                  
   //      // }

   //      // if (state.out_count==0)
   //      // {
   //      //     params.sum=1;
   //      //     next.emplace_back(std::make_pair(state.prev_node, params));
   //      // }
   //  params.sum=200;
   // }
   params.sum=200;
   // next.emplace_back(std::make_pair(params.prev_node, params));
    

    // params.response_str.emplace_back(state.accumulatedSum);
    // return std::make_pair(search_type::DEPTH_FIRST, next);







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
// ################################

   // if (state.visited)
   // {
   //      state.recorded_sum=state.recorded_sum+params.sum;
   //      state.out_count=state.out_count-1;
   //      if  (state.out_count==0)
   //      {
   //         state.recorded_sum=state.recorded_sum+1;
   //         params.sum=state.recorded_sum;
   //         next.emplace_back(std::make_pair(state.prev_node, params));
   //      }
    
   // }
   // else
   // {  
   //      state.prev_node=params.prev_node;
   //      params.prev_node = rn;
   //      state.visited=true;
   //      for (edge &e: n.get_edges()) 
   //      {
   //          std::string str1="edgeDirection";
   //          std::string str2="F";
   //          std::pair<std::string, std::string> p=std::make_pair(str1,str2);
   //          if (e.has_property(p))
   //          {
   //              state.out_count++;  
   //              next.emplace_back(std::make_pair(e.get_neighbor(), params));  
   //          }      
   //          // std::cout<<e.get_properties();

   //      }

   //      if (state.out_count==0)
   //      {
   //          params.sum=1;
   //          next.emplace_back(std::make_pair(state.prev_node, params));
   //      }
   // }
        for (edge &e: n.get_edges()) 
        {
            params.sum=params.sum+getEdgePropVal(e,"edgeDirection");
        }
        std::cout << "Hello world";
        next.emplace_back(std::make_pair(params.prev_node, params)); 