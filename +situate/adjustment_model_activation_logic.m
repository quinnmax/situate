
function is_to_be_expanded = adjustment_model_activation_logic( agent_to_expand, workspace, expand_min, expand_max  )

    is_to_be_expanded = false;
    
    relevant_workspace_ind = find(strcmp( workspace.labels, agent_to_expand.interest ));
    
    if isempty(relevant_workspace_ind) ...
    && agent_to_expand.support.internal >= expand_min
    
        % nothing known so far, and looks pretty good, then expand
        is_to_be_expanded = true;
    
    end
    
    if ~isempty(relevant_workspace_ind) ...
    && agent_to_expand.support.internal >= workspace.internal_support( relevant_workspace_ind ) ...
    && agent_to_expand.support.total <= expand_max
        
        % something already in the workspace, but this is better
        is_to_be_expanded = true;

    end
       
end