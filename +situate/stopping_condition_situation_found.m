function [hard_stop, soft_stop, message] = stopping_condition_situation_found( workspace, ~, p )

    hard_stop = false;
    soft_stop = false;
    message = '';

    if isequal( sort(workspace.labels), sort(p.situation_objects) ) ...
    && all( workspace.total_support >= p.thresholds.total_support_final )
        hard_stop = true;
        message = 'situation found';
    end
       
end