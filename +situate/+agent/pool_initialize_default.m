function agent_pool = pool_initialize_default( p, ~, ~ )
    
    agent_pool = repmat( situate.agent.initialize(), 1, p.num_scouts );
    for ai = 1:length(agent_pool)
        agent_pool(ai) = situate.agent.initialize(p);
    end
   
end
