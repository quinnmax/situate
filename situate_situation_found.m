
function is_complete = situate_situation_found( workspace, parameters_struct )
    
    % [is_complete, progress] = situate_situation_found( workspace, parameters_struct );
    %   workspace;
    %       the current workspace, with objects that have been checked in
    %       provisionally or firmly
    %   parameters_struct:
    %       the parameters structure, which includes the conditions for
    %       successful detection, including thresholds, and objects of
    %       interest lists (and could include some graph requirements and
    %       stuff if we're so inclined)

    is_complete = false;

    committed_objects = workspace.labels( workspace.total_support >= parameters_struct.total_support_threshold_2 );

    [workspace_counts, workspace_labels] = counts( committed_objects );
    [situation_counts, situation_labels] = counts( parameters_struct.situation_objects );

    % counts will respond with things in sorted order, so the counts will
    % have to match in order as well. isequal requires order to be correct
    % as well, so all seems okay
    if isequal(workspace_labels, situation_labels) && isequal(workspace_counts, situation_counts)
        is_complete = true;
    end

end

    
    






