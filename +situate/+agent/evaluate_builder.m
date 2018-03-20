
function [workspace,agent_pool,object_was_added] = evaluate_builder( agent_pool, agent_index, workspace ) 
 
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
    
    add_cur_agent_to_workspace = false;
    object_was_added = false;
    
    workspace_entries_to_remove = false(1,length(workspace.labels));
    
    spatial_collision_threshold = .5;
    if ~isempty( workspace.labels )
        type_collisions = strcmp( workspace.labels, agent_pool(agent_index).interest);
        spatial_collisions = intersection_over_union( cur_agent.box.r0rfc0cf,  workspace.boxes_r0rfc0cf, 'r0rfc0cf','r0rfc0cf' ) > spatial_collision_threshold;
    else
        type_collisions    = [];
        spatial_collisions = [];
    end
    
    is_more_supported_than_spatial_collision = all(cur_agent.support.total >= workspace.total_support(spatial_collisions)); % any of your spatial collisions can shadow you
    is_more_supported_than_type_collision    = all(cur_agent.support.total >= workspace.total_support(type_collisions)); 
    
    % if proposal has no type collision, no spatial collision: add it
    if ~any(type_collisions) && ~any(spatial_collisions)
        add_cur_agent_to_workspace = true;
    
    % if proposal has no type collision, more support than spatial collision: add it, remove spatial collision
    elseif ~any(type_collisions) && is_more_supported_than_spatial_collision
        add_cur_agent_to_workspace = true;
        workspace_entries_to_remove = spatial_collisions & cur_agent.support.total >= workspace.total_support;
    
    % if proposal is more supported than type collision, no spatial collision: add it, remove type collision
    elseif any(type_collisions) && is_more_supported_than_type_collision && ~any(spatial_collisions)
        add_cur_agent_to_workspace = true;
        workspace_entries_to_remove = type_collisions & cur_agent.support.total >= workspace.total_support;
    
    % if proposal is more supported than type collision, more supported than spatial collision: add it, remove spatial and type collisions
    elseif any(type_collisions)    && is_more_supported_than_type_collision ...
        && any(spatial_collisions) && is_more_supported_than_spatial_collision
        add_cur_agent_to_workspace = true;
        workspace_entries_to_remove = (type_collisions & cur_agent.support.total >= workspace.total_support) ...
                                 | (spatial_collisions & cur_agent.support.total >= workspace.total_support);
    
    else
        % if proposal is more supported than type collision, less supported than spatial collision: do not add it (this is the weird one)
        % if proposal has no type collision, less support than spatial collision: do not add it
        % if proposal is less supported than type collision: do not add it
            % just do nothing
    end
    
    
    
    % remove entries flagged above
    workspace.boxes_r0rfc0cf(workspace_entries_to_remove,:) = [];
    workspace.internal_support(workspace_entries_to_remove) = [];
    workspace.external_support(workspace_entries_to_remove) = [];
    workspace.total_support(workspace_entries_to_remove)    = [];
    workspace.labels(workspace_entries_to_remove)           = [];
    workspace.labels_raw(workspace_entries_to_remove)       = [];
    workspace.GT_IOU(workspace_entries_to_remove)           = [];
    
    % add proposal to workspace
    if add_cur_agent_to_workspace
        workspace.boxes_r0rfc0cf(end+1,:)   = cur_agent.box.r0rfc0cf;
        workspace.internal_support(end+1)   = cur_agent.support.internal;
        workspace.external_support(end+1)   = cur_agent.support.external;
        workspace.total_support(end+1)      = cur_agent.support.total;
        workspace.labels{end+1}             = cur_agent.interest;
        workspace.labels_raw{end+1}         = cur_agent.GT_label_raw;
        workspace.GT_IOU(end+1)             = cur_agent.support.GROUND_TRUTH;
        object_was_added = true;
    end
    
    
    
    % double check that the above logic didn't let anything through
    ious = intersection_over_union( workspace.boxes_r0rfc0cf, workspace.boxes_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
    ious( logical( eye( size( ious ) ) ) ) = 0;
    if any( ious(:) > spatial_collision_threshold )
        error('high iou');
    end
    
  
end
