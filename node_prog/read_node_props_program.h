/*
 * ===============================================================
 *    Description:  Node program to read properties of a single node
 *
 *        Created:  Friday 17 January 2014 11:00:03  EDT
 *
 *         Author:  Ayush Dubey, Greg Hill
 *                  dubey@cs.cornell.edu, gdh39@cornell.edu
 *
 * Copyright (C) 2013, Cornell University, see the LICENSE file
 *                     for licensing agreement
 * ================================================================
 */

#ifndef __READ_NODE_PROPS_PROG__
#define __READ_NODE_PROPS_PROG__

#include <vector>
#include <string>

#include "common/message.h"
#include "db/element/node.h"
#include "db/element/remote_node.h"
#include "common/vclock.h"
#include "common/event_order.h"

namespace node_prog
{
    class read_node_props_params : public virtual Node_Parameters_Base 
    {
        public:
            std::vector<std::string> keys; // empty vector means fetch all props
            uint64_t vt_id;
            std::vector<common::property> node_props;

        public:
            virtual bool search_cache() {
                return false; // would never need to cache
            }

            virtual uint64_t cache_key() {
                return 0;
            }

            virtual uint64_t size() const 
            {
                uint64_t toRet = message::size(keys)
                    + message::size(node_props);
                return toRet;
            }

            virtual void pack(e::buffer::packer& packer) const 
            {
                message::pack_buffer(packer, keys);
                message::pack_buffer(packer, vt_id);
                message::pack_buffer(packer, node_props);
            }

            virtual void unpack(e::unpacker& unpacker)
            {
                message::unpack_buffer(unpacker, keys);
                message::unpack_buffer(unpacker, vt_id);
                message::unpack_buffer(unpacker, node_props);
            }
    };

    struct read_node_props_state : public virtual Node_State_Base
    {
        virtual ~read_node_props_state() { }

        virtual uint64_t size() const
        {
            return 0;
        }

        virtual void pack(e::buffer::packer& packer) const 
        {
            UNUSED(packer);
        }

        virtual void unpack(e::unpacker& unpacker)
        {
            UNUSED(unpacker);
        }
    };

    struct read_node_props_cache_value : public virtual Cache_Value_Base 
    {
        virtual ~read_node_props_cache_value() { }

        virtual uint64_t size() const 
        {
            return 0;
        }

        virtual void pack(e::buffer::packer& packer) const 
        {
            UNUSED(packer);
        }

        virtual void unpack(e::unpacker& unpacker)
        {
            UNUSED(unpacker);
        }
    };

    std::vector<std::pair<db::element::remote_node, read_node_props_params>> 
    read_node_props_node_program(uint64_t,
            db::element::node &n,
            db::element::remote_node &,
            read_node_props_params &params,
            std::function<read_node_props_state&()>,
            std::shared_ptr<vc::vclock> &req_vclock,
            std::function<void(std::shared_ptr<node_prog::Cache_Value_Base>,
                std::shared_ptr<std::vector<db::element::remote_node>>, uint64_t)>&,
            std::unique_ptr<db::caching::cache_response>)
    {
        db::element::remote_node coord(params.vt_id, 1337);
        std::vector<std::pair<db::element::remote_node, read_node_props_params>> next;
        next.emplace_back(std::make_pair(coord, std::move(params)));

        for (const common::property &prop : *n.get_props())
        {
            bool key_match = params.keys.empty() || (std::find(params.keys.begin(), params.keys.end(), prop.key) != params.keys.end());
            if (key_match && order::clock_creat_before_del_after(*req_vclock, prop.get_creat_time(), prop.get_del_time()))
            {
                next[0].second.node_props.emplace_back(prop);
            }
        }

        return next;
    }
}

#endif