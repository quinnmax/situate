
function [workspace,agent_pool,object_was_added] = agent_evaluate_builder( agent_pool, agent_index, workspace ) 
 
    % The builder checks to see if a proposed object, which has passed both
    % scout and reviewer processes, is actually an improvement over what
    % has already been checked in to the workspace.
    %
    % If there is no object of the proposed type, it is checked in
    % automatically. if there is an existing object of the proposed type,
    % the two are reconciled.
    %
    % If something is checked in, the distributions that are used to generate 
    % scouts are modified to reflect the new information.
    %
    %
    % todo: consider bouncing a removed entry back to the agent pool, rather than just forgetting
    % it. that way it's still in consideration if there are other changes to what's in the workspace
    % that make it more appealing again

    cur_agent = agent_pool(agent_index);
    assert( isequal( cur_agent.type, 'builder' ) );
    
    object_was_added = false;
    
    matching_workspace_object_index = find(strcmp( workspace.labels, agent_pool(agent_index).interest) );
    
    if isempty( matching_workspace_object_index )
    
        % no matches yet, so add this object to the workspace
        
        workspace.boxes_r0rfc0cf(end+1,:)   = cur_agent.box.r0rfc0cf;
        workspace.internal_support(end+1)   = cur_agent.support.internal;
        workspace.external_support(end+1)   = cur_agent.support.external;
        workspace.total_support(end+1)      = cur_agent.support.total;
        workspace.labels{end+1}             = cur_agent.interest;

        workspace.labels_raw{end+1}         = cur_agent.GT_label_raw;
        workspace.GT_IOU(end+1)             = cur_agent.support.GROUND_TRUTH;

        object_was_added = true;
            
    else
        
        % see if the new detection is better than the old one
            
        if cur_agent.support.total >= workspace.total_support(matching_workspace_object_index)

            % remove the old entry, add the current agent
            workspace.boxes_r0rfc0cf(matching_workspace_object_index,:) = [];
            workspace.internal_support(matching_workspace_object_index) = [];
            workspace.external_support(matching_workspace_object_index) = [];
            workspace.total_support(matching_workspace_object_index)    = [];
            workspace.labels(matching_workspace_object_index)           = [];
            workspace.labels_raw(matching_workspace_object_index)       = [];
            workspace.GT_IOU(matching_workspace_object_index)           = [];

            workspace.boxes_r0rfc0cf(end+1,:) = cur_agent.box.r0rfc0cf;
            workspace.internal_support(end+1) = cur_agent.support.internal;
            workspace.external_support(end+1) = cur_agent.support.external;
            workspace.total_support(end+1)    = cur_agent.support.total;
            workspace.labels{end+1}           = cur_agent.interest;
            workspace.labels_raw{end+1}       = cur_agent.GT_label_raw;
            workspace.GT_IOU(end+1)           = cur_agent.support.GROUND_TRUTH;

            object_was_added = true;

        else

            % nothing changes, so just bail
            return;

        end
            
    end
     
end
