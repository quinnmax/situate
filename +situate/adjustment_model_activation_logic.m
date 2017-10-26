
function is_to_be_expanded = adjustment_model_activation_logic( agent_to_expand, workspace, expand_min, expand_max  )

    is_to_be_expanded = false;
    
    if isfield( agent_to_expand, 'had_offspring') && agent_to_expand.had_offspring
    % it already was expanded, and it's deterministic, so don't bother
        return;
    end
    
            
    
    relevant_workspace_ind = find(strcmp( workspace.labels, agent_to_expand.interest ));
    
    if agent_to_expand.support.internal >= expand_min ...
    && agent_to_expand.support.internal <= expand_max
        if isempty(relevant_workspace_ind)
            % nothing known so far, and looks pretty good, then expand
            is_to_be_expanded = true;
        elseif agent_to_expand.support.internal >= workspace.internal_support( relevant_workspace_ind ) ...
            % something already in the workspace, but this is better
            % (including equality in case agent_to_expand was actually just added to the workspace)
            is_to_be_expanded = true;
        end
    end
       
end