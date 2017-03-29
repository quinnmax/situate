function [result, message] = stopping_condition_situation_found( workspace, p )

    result = false;
    message = '';

    if isequal( sort(workspace.labels), sort(p.situation_objects) ) ...
    && all( workspace.total_support >= p.thresholds.total_support_final )
        result = true;
        message = 'situation found';
    end
       
end