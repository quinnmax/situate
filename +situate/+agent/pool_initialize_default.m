function [agent_pool,total_cnn_calls] = pool_initialize_default( p, varargin )
    
    total_cnn_calls = 0;
    agent_pool = repmat( situate.agent.initialize(), 1, p.num_scouts );
    for ai = 1:length(agent_pool)
        agent_pool(ai) = situate.agent.initialize(p);
    end
   
end
