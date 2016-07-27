function [completion_iteration, final_workspace_snippet] = situate_workspace_entry_event_log_to_completion_time( workspace_entry_event_log_in, p, iteration_limit )

% [completion_iteration, final_workspace_snippet] = situate_workspace_entry_event_log_to_completion_time( workspace_entry_event_log, p, iteration_limit );
    
    if ~exist('iteration_limit') || isempty(iteration_limit)
        iteration_limit = inf;
    end

    % get the workspace entry events
    workspace_entry_event_log = workspace_entry_event_log_in;
    
    % clear out everything past our iteration limit [default is inf]
    over_iteration_limit_inds = gt([workspace_entry_event_log{:,1}], iteration_limit );
    workspace_entry_event_log( over_iteration_limit_inds, : ) = [];
    
    % remove everything but the last entry for each object type
    unique_labels = unique( workspace_entry_event_log(:,2) );
    last_detection_inds = false( size(workspace_entry_event_log, 1 ), 1 );
    for cur_label_ind = 1:length(unique_labels)
        cur_label = unique_labels{cur_label_ind};
        ind_keep = find(strcmp(cur_label, workspace_entry_event_log(:,2) ), 1, 'last');
        last_detection_inds(ind_keep) = true;
    end
    workspace_entry_event_log( ~last_detection_inds, : ) = [];
    
    % see if the detection was completed, report time
    over_threshold_inds = [workspace_entry_event_log{:,4}] >= p.thresholds.total_support_final;
    found_objects = workspace_entry_event_log( over_threshold_inds, 2 );
    if isequal( length(p.situation_objects) , length(intersect( found_objects, p.situation_objects )) )
        completion_iteration = max( [workspace_entry_event_log{:,1}] );
    else
        completion_iteration = inf;
    end
    
    % give a little snippet of the resulting workspace
    final_workspace_snippet = zeros(1,length(p.situation_objects));
    for oi = 1:length(p.situation_objects)
        cur_label = p.situation_objects{oi};
        workspace_index = find(strcmp( workspace_entry_event_log(:,2), cur_label ));
        if isempty(workspace_index)
            final_workspace_snippet(oi) = 0;
        else
            final_workspace_snippet(oi) = workspace_entry_event_log{ workspace_index, 4 };
        end
    end
    
end
    
    
    
    
    
        
        
        
        
        
        
        