function agent_pool = pool_initialize_default( p, ~, ~ )
    
    agent_pool = repmat( agent.initialize(), 1, p.num_scouts );
    for ai = 1:length(agent_pool)
        agent_pool(ai) = agent.initialize(p);
    end
   
end
