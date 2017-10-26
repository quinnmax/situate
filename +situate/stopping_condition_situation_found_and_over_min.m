function [stopping_condition_met, message] = stopping_condition_situation_found_and_over_min( workspace, ~, p )

    stopping_condition_met = false;
    situation_found = false;
    message = '';

    if isequal( sort(workspace.labels), sort(p.situation_objects) ) ...
    && all( workspace.total_support >= p.thresholds.total_support_final )
        situation_found = true;
    end
    
    min_iterations_ratio = .25;
    done_some_work = workspace.iteration > ( min_iterations_ratio * p.num_iterations );
    
    if situation_found && done_some_work
        stopping_condition_met = true;
        message = ['situation found and over ' num2str(min_iterations_ratio) ' * total iterations'];
    end
    
end