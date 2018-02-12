
function [agent_pool] = evaluate_reviewer( agent_pool, agent_index, p, learned_models ) 
% function [ agents_out ] = evaluate_reviewer( agent_pool, agent_index, p, learned_models )    


    % the reviewer checks to see how compatible a proposed object is with
    % our understanding of the relationships between objects. if the
    % porposal is sufficiently compatible, we send ut off to a builder.
    %
    % currently, there is no evaluation being made here, so the builder is
    % made for sure.
    
    cur_agent = agent_pool(agent_index);
    assert( isequal( cur_agent.type, 'reviewer' ) );
    
    if length(p.external_support_function) == 1
        cur_agent.support.external = p.external_support_function( agent_pool(agent_index).support.sample_densities ); 
    else
        obj_ind = strcmp(agent_pool(agent_index).interest,p.situation_objects);
        cur_agent.support.external = p.external_support_function{obj_ind}( agent_pool(agent_index).support.sample_densities ); 
    end
    
    oi = strcmp( p.situation_objects, cur_agent.interest );
    
    switch class( p.total_support_function )
        case 'function_handle'
            cur_agent.support.total  = p.total_support_function( cur_agent.support.internal, cur_agent.support.external, learned_models, oi );
        case 'cell'
            % assume different functions per object type
            cur_agent.support.total = p.total_support_function{oi}( cur_agent.support.internal, cur_agent.support.external, learned_models, oi );
        otherwise
            error('dunno what to do with this');
    end
    
    agent_pool(agent_index) = cur_agent;

    % consider adding a builder to the pool
    if cur_agent.support.total >= p.thresholds.total_support_provisional || cur_agent.support.total >= p.thresholds.total_support_final
        agent_pool(end+1) = cur_agent;
        agent_pool(end).type = 'builder';
        agent_pool(end).urgency = p.agent_urgency_defaults.builder;
    end
    
end

