
function is_to_be_expanded = spawn_local_scouts_activation_logic( agent_to_expand, workspace  )

    is_to_be_expanded = false;
    
    relevant_workspace_ind = find(strcmp( workspace.labels, agent_to_expand.interest ));
    
    if isempty(relevant_workspace_ind) || agent_to_expand.support.internal > workspace.internal_support( relevant_workspace_ind )
        % if nothing exists, expand
        % if something does exist, but this is better, expand
        is_to_be_expanded = true;
    end
       
end