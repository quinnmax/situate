
function [agent_pool, d, workspace, object_was_added] = evaluate( agent_pool, agent_index, im, label, d, p, workspace, learned_models )

% [agent_pool, d, workspace, object_was_added] = evaluate( agent_pool, agent_index, im, label, d, p, workspace, learned_models )

    object_was_added = false;

    switch( agent_pool(agent_index).type )
        case 'scout'
            % sampling from d may change it, so we include it as an output
            assert(size(agent_pool,1)==1);
            [agent_pool, d] = situate.agent.evaluate_scout( agent_pool, agent_index, p, d, im, label, learned_models );
        case 'reviewer'
            % reviewers do not modify the distributions
            [agent_pool] = situate.agent.evaluate_reviewer( agent_pool, agent_index, p, learned_models );
        case 'builder'
            % builders modify d by changing the prior on scout interests,
            % and by focusing attention on box sizes and shapes similar to
            % those that have been found to be reasonable so far.
            [workspace,agent_pool,object_was_added] = situate.agent.evaluate_builder( agent_pool, agent_index, workspace );
        otherwise
            error('situate:main_loop:agent_evaluate:agentTypeUnknown','agent does not have a known type field'); 
    end
   
    
    
    % implementing the direct scout -> reviewer -> builder pipeline
    %
    % Situate started with different agent types. one for applying the classifier, one for
    % evaluating with respect to the situation model, and one for deciding if it makes it into the
    % workspace. as it stands, there was not real benefit to this structure, so the below just
    % forces them to evaluate in sequence, rather than relying on stochastic evaluation
    %
    % With a direct scout -> reviewer -> builder pipeline, every scout gets a reviewer, and if some
    % thresholds are met, we go right to running the builder.
    %
    % The main difference here is that we should never end up with anything but scouts in the agent
    % pool as you exit this function.
   
    if p.use_direct_scout_to_workspace_pipe ...
    && strcmp(agent_pool(agent_index).type, 'scout' )

        % we'd like to just go ahead and make a reviewer for every scout, and eval it right away.
        % if it leads to a builder, we'll review that right away as well.

        % if we didn't generate a reviewer as a result of evaluating this agent,
        % then add one and see what total support would have been.
        if ~isequal(agent_pool(end).type, 'reviewer')
            agent_pool(end+1) = agent_pool(agent_index);
            agent_pool(end).type = 'reviewer';
            agent_pool(end).urgency = p.agent_urgency_defaults.reviewer;
        end
        
        assert( isequal( agent_pool(end).type, 'reviewer' ) );
        [agent_pool] = situate.agent.evaluate_reviewer( agent_pool, length(agent_pool), p, learned_models );
        % this gets us external and total support values.
        % it might also add a builder to the end of the agent pool.
        agent_pool(agent_index).support.external = agent_pool(end).support.external;
        agent_pool(agent_index).support.total    = agent_pool(end).support.total;
        
        % if we generated a builder as a result of evaluating the reviewer,
        % then evaluate it now
        if isequal(agent_pool(end).type,'builder') && agent_pool(agent_index).support.internal >= p.thresholds.internal_support
            % the reviewer did spawn a builder, so evaluate it
            assert(isequal(agent_pool(end).type,'builder'));
            [workspace, agent_pool, object_was_added] = situate.agent.evaluate_builder( agent_pool, length(agent_pool), workspace );
            % feed the total support back to the scout, since this bonkers
            % process is in effect and the addition to the workspace needs
            % to be justified with a final score. alternatively, we could
            % just turn scouts into reviewers and builders, rather than
            % adding them to the pool...
            agent_pool([end-1 end]) = [];
        elseif isequal(agent_pool(end).type,'builder')
            % the reviewer spawned a builder, but it really shouldn't have, so remove it and the
            % reviewer
            %
            % note: we only get here if we're 
            %   a) using direct scout to workspace pipe
            %   b) the scout was under threshold to spawn a reviewer
            %   c) we spawned one anyway to get it's external and total support
            %   d) the total support ended up being high enough to spawn a builder
            %
            % what it tells us is: the internal support is low, but the external is very high and,
            % as far as total support is concerned, it should go in the workspace...
            %
            % we should talk about this possiblility coming up.
            % I'm going to go ahead and not build the proposal, as it was low internal support and
            % this makes it functionally different from the fully agent-based approach
            agent_pool([end-1 end]) = [];
        elseif isequal(agent_pool(end).type,'reviewer')
            % the reviewer failed to spawn a builder, 
            % so just remove the reviewer and carry on
            agent_pool(end) = [];
        end
       
    end
    
    assert(size(agent_pool,1)==1);
    
end