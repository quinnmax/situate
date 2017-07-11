function [result, message] = stopping_condition_finish_up_pool( workspace, agent_pool, p )

    result = false;
    message = '';

    situation_found = false;
    
    if isequal( sort(workspace.labels), sort(p.situation_objects) ) ...
    && all( workspace.total_support >= p.thresholds.total_support_final )
        situation_found = true;
    end
    
    no_interesting_agents = all(cellfun(@isempty,{agent_pool.interest}));
    
    if situation_found && no_interesting_agents
        result = true;
        message = 'situation found and pool is empty';
    end
       
end