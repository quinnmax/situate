function agent_pool = pool_update( agent_pool, agent_index, p, workspace, current_agent_snapshot, im, learned_models )

    % generate new agents based on the current agent's findings
        new_agents = [];
        if length(p.adjustment_model.activation_logic) == 1 
            % there's only one activation logic function for all object types
            if p.adjustment_model.activation_logic(current_agent_snapshot,workspace,p)
                new_agents = p.adjustment_model.apply( learned_models.adjustment_model, current_agent_snapshot, agent_pool, im );
                agent_pool(agent_index).had_offspring = true;
            end
        elseif length(p.adjustment_model.activation_logic) == length(p.situation_objects)
            % there are activation logic functions for each object type
            % so apply the function in the  object's slot
            if p.adjustment_model.activation_logic{ strcmp( current_agent_snapshot.interest, p.situation_objects ) }( current_agent_snapshot, workspace, p )
                new_agents = p.adjustment_model.apply( learned_models.adjustment_model, current_agent_snapshot, agent_pool, im );
                agent_pool(agent_index).had_offspring = true;
            end
        else
            error('don''t know how to use this adjustment model activation function');
        end
        
        if ~isempty(new_agents)
            agent_pool(end+1:end+length(new_agents)) = new_agents;
        end
        
    % decide what to do with the evaluated agent (default is remove)
        if agent_pool(agent_index).support.internal >= p.thresholds.internal_support_retain
            % keep the agent in the pool
        else
            agent_pool(agent_index) = [];
        end
      
    % make user defined adjustments to the pool
        agent_pool = p.agent_pool_adjustment_function(agent_pool);
        
end