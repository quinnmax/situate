function [hard_stop, soft_stop, message] = stopping_condition_finish_up_pool( workspace, agent_pool, p )

    % if the condition is met, then evaluate whatever is still in the pool, but don't add anything
    % to it

    hard_stop = false;
    message = '';

    soft_stop = false;
    
    if isequal( sort(workspace.labels), sort(p.situation_objects) ) ...
    && all( workspace.total_support >= p.thresholds.total_support_final )
        soft_stop = true;
    end
    
    no_interesting_agents = all(cellfun(@isempty,{agent_pool.interest}));
    
    if soft_stop && no_interesting_agents
        hard_stop = true;
        message = 'situation found and pool is empty';
    end
       
end