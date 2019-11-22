function [ workspace, records, all_workspaces ] = run_monte( im_fname, running_params, learned_models  )
% [ workspace_best, records_best, all_workspaces ] = run_monte( im_fname, running_params, learned_models)
 
        im = imread( im_fname );
        if mean(im(:)) < 1, im = 255 * im; end
        label = situate.labl_load( im_fname, running_params ); % may return empty array if label file wasn't found
        im_size = [size(im,1), size(im,2)];
        
        situation_objects = learned_models.situation_model.situation_objects;
        num_objs = numel(situation_objects);
        
        iterations_per_attention_period = 20;
        iterations_before_deprioritize = 3 * iterations_per_attention_period; % if n iters are evaluated with no updated to workspace, sandbag
          
        running_params_per_agent = running_params;
        running_params_per_agent.use_monte = false;
        
        temp_params = running_params_per_agent;
        temp_params.agent_pool_initialization_function = @situate.agent.pool_initialize_default;
        [ ~, ~, ~, state_prototype ] = situate.run( im_fname, temp_params, learned_models, [], 1 );
        state_prototype.agent_pool = [];
        empty_workspace = situate.workspace_initialize(running_params_per_agent, im_size );
        state_prototype.workspace = empty_workspace;
           
        % initialize the agent pool using the method specified in the running parameters
        min_boxes_per_obj_type = 0;
        [primed_agent_pool, cur_iter_count] = running_params.agent_pool_initialization_function( running_params, im, im_fname, learned_models, min_boxes_per_obj_type );
        inds_remove = cellfun(@isempty,{primed_agent_pool.interest});
        primed_agent_pool(inds_remove) = [];
        
        % get the internal support for each of these initial agents
        for ai = 1:numel(primed_agent_pool)
            [~, ~,updated_agent ] = situate.agent.evaluate_scout( primed_agent_pool, ai, running_params, [], im, label, learned_models );
            primed_agent_pool(ai) = updated_agent;
        end
        cur_iter_count = cur_iter_count + numel(primed_agent_pool);
        
        % visualize initial object pool
        visualize = false;
        if visualize
            figure('Name','returned objects w internal support')
            for oi = 1:num_objs 
                subplot(1,num_objs,oi); 
                imshow(im); hold on; 
            end
            for ai = 1:numel(primed_agent_pool)
                cur_box_r0rfc0cf = primed_agent_pool(ai).box.r0rfc0cf;
                subplot( 1, num_objs, find(strcmp( primed_agent_pool(ai).interest, situation_objects )) );
                draw_box( cur_box_r0rfc0cf, 'r0rfc0cf','linewidth',2);
                text( cur_box_r0rfc0cf(3)+2, cur_box_r0rfc0cf(1)+2, 2, num2str( primed_agent_pool(ai).support.internal ),'color',[1 1 1]);
                text( cur_box_r0rfc0cf(3), cur_box_r0rfc0cf(1), 1, num2str( primed_agent_pool(ai).support.internal ) );
            end
        end

        % prime workspaces and agent pools
        %   put each found object into its own context, then fill the agent pool with each
        %   instance of other objects
        state_pool = repmat(state_prototype,1,numel(primed_agent_pool));
        for si = 1:numel(primed_agent_pool)
            
            state_pool(si).agent_pool = primed_agent_pool(si);
            
            % eval to see if it goes into the workspace (it should if we set the threshold reasonably)
            [ ~, ~, ~, state_pool(si) ] = situate.run( im_fname, running_params_per_agent, learned_models, state_pool(si), 1 );
            %cur_iter_count = cur_iter_count + 1;
            
            % now the cur state pool should have a workspace
            % fill its agent pool with primed agents from the other object types
            other_obj_init_rows = ~strcmp({primed_agent_pool.interest},primed_agent_pool(si).interest );
            state_pool(si).agent_pool = primed_agent_pool( other_obj_init_rows );
            if isempty( state_pool(si).agent_pool), state_pool(si).agent_pool = situate.agent.initialize(); end
        end

        % remove states with empty workspaces
        empty_workspace_inds = arrayfun( @(x) isempty(x.labels), [state_pool.workspace]);
        if ~all(empty_workspace_inds) && ~isempty(state_pool)
            state_pool(empty_workspace_inds) = [];
        else
            state_pool(2:end) = [];
        end
        
        % initialize the sampling table
        state_support = arrayfun( @(x) x.situation_support, [state_pool.workspace] );
        sampling_table = state_support;
        state_iterations_since_update = zeros(size(state_support));
        state_total_iterations = zeros(size(state_support));
        
        
        
        debug = false;
        
        % if no detections to start, just return
        if isempty(sampling_table)
            workspace = empty_workspace;
            records = situate.records_initialize(running_params_per_agent,[]);
            records.workspace_final = workspace;
            all_workspaces = workspace;
            return;
        end
        
        % now monte it up
        keep_going = true;
        while keep_going 
            keep_going = cur_iter_count < running_params.num_iterations;
            
            si = sample_1d( sampling_table, 1 );
            [ ~, ~, ~, state_out ] = situate.run( im_fname, running_params_per_agent, learned_models, state_pool(si), iterations_per_attention_period );
        
            cur_iter_count = cur_iter_count + iterations_per_attention_period;
            state_total_iterations(si) = state_total_iterations(si)               + iterations_per_attention_period;
            state_iterations_since_update(si) = state_iterations_since_update(si) + iterations_per_attention_period;
            
            % update based on results
            if numel(state_out.workspace.labels) ~= numel(state_pool(si).workspace.labels)
                
                % a new object was added
                
                % check for collision
                dup_threshold = .5;
                [~, dup_inds] = duplicate_workspace_inds( [state_out.workspace, state_pool.workspace], situation_objects, dup_threshold );
                
                if isempty(dup_inds)
                    
                    % branch
                    state_pool     = [state_out, state_pool];
                    state_support  = [state_out.workspace.situation_support, state_support];
                    sampling_table = [state_out.workspace.situation_support, sampling_table];
                    state_total_iterations = [0 state_total_iterations];
                    state_iterations_since_update = [0 state_iterations_since_update];
                    
                    % current state is productive, refresh its lifetime
                    state_iterations_since_update(si) = 0;
                   
                else
                    
                    % it's a duplicate of a known state
                    state_iterations_since_update(si) = state_iterations_since_update(si) + iterations_per_attention_period;
                    
                end
                
            else % no object added
                
                state_iterations_since_update(si) = state_iterations_since_update(si) + iterations_per_attention_period;
                
                if ~isequal( state_out.workspace.boxes_r0rfc0cf, state_pool(si).workspace.boxes_r0rfc0cf)
                    
                    % then an existing object was updated
                    % could refresh, could just keep going
                    % state_pool(si).iterations_since_last_update = 0;
                    
                end
                   
                % update the state support and sampling probability
                state_pool(si)     = state_out;
                state_support(si)  = state_out.workspace.situation_support;
                sampling_table(si) = state_out.workspace.situation_support;
                
            end
            
            % check lifespan of states
            sampling_table( [state_iterations_since_update] >= iterations_before_deprioritize ) = 0;
            % display([sampling_table;state_total_iterations;state_iterations_since_update]);
            
            % pool management
            empty_workspace_inds = arrayfun( @(x) isempty( x.labels ), [state_pool.workspace] );

            % short circuit for all empty workspaces
            %   if everything was empty, the initial search found no related objects, then we really
            %   don't have any reason to believe that search the image more will reveal a foothold
            %   for us to understand this image
            if all(empty_workspace_inds)
                records = state_pool(1).records;
                workspace = state_pool(1).workspace;
                all_workspaces = [state_pool.workspace];
                return;
            end

            % remove empty workspaces
            state_pool(empty_workspace_inds)           = [];
            sampling_table(empty_workspace_inds)       = [];
            state_support(empty_workspace_inds)        = [];
            state_total_iterations(empty_workspace_inds) = [];

            % de-dup workspaces
            %   if all boxes have IOU with corresponding obj over threshold, it's a dup
            %   the versions with lower situation support are returned
            dup_threshold = .5; 
            [~, dup_inds] = duplicate_workspace_inds( [state_pool.workspace], situation_objects, dup_threshold );
            if ~isempty(dup_inds)
                state_pool(dup_inds)     = [];
                state_support(dup_inds)  = [];
                sampling_table(dup_inds) = [];
            end

            % if everyone is in cold storage, wake them all up? or just short circuit?
            if all( sampling_table == 0 )
                % give them attention back
                % sampling_table = state_support;
                
                % short circuit
                keep_going = false;
            end

        end
        
        winning_ind = argmax(state_support);
        workspace = state_pool(winning_ind).workspace;
        workspace.total_iterations = cur_iter_count;
        records = state_pool(argmax(state_support)).records;
        all_workspaces = [state_pool.workspace];
        
%         
%         sit_sup_1 = arrayfun( @(x) support_functions_situation.geometric_mean_padded( padarray_to(.8*[x.workspace.internal_support] + .2*[x.workspace.external_support],[1,3])), state_pool);
%         sit_sup_2 = arrayfun( @(x) support_functions_situation.geometric_mean_padded( padarray_to(.5*[x.workspace.internal_support] + .5*[x.workspace.external_support],[1,3])), state_pool);
%         sit_sup_gt = arrayfun(@(x) support_functions_situation.geometric_mean_padded(padarray_to(x.workspace.GT_IOU,[1 3])), state_pool);
%         
        if debug
            figure('Name','final workspaces');
            temp = [state_pool.workspace];
            ordering = sortorder(-[temp.situation_support])
            for si = 1:numel(state_pool)
                subplot_lazy(numel(state_pool),si);
                sj = ordering(si);
                situate.workspace_draw(im,running_params,state_pool(sj).workspace);
                if winning_ind == sj
                    title('winner');
                end
                xlabel({ [ 'iters: ' num2str(state_pool(sj).workspace.total_iterations) ],...
                         [ 'sit sup: ' num2str(state_pool(sj).workspace.situation_support) ] });
            end
        end
        
end



function [min_iou_overlap_grid, dup_inds] = duplicate_workspace_inds( workspaces, situation_objects, dup_threshold )

    dup_inds = [];

    % check for and remove redundant workspaces
    min_iou_overlap_grid = nan( numel(workspaces), numel(workspaces) );
    for si = 1:numel(workspaces)
    for sj = 1:si
        
        if si ~= sj && ~isempty(workspaces(si).labels) && isequal( sort(workspaces(si).labels), sort(workspaces(sj).labels) )
            
            % labels are the same. same number, same entries
            num_objs = numel(workspaces(si).labels);
            cur_pair_ious = nan(1,num_objs);
     
            for oi = 1:num_objs
                cur_obj_label_i = workspaces(si).labels{oi};
                oj = strcmp( cur_obj_label_i, workspaces(sj).labels ); 
                bi = workspaces(si).boxes_r0rfc0cf(oi,:);
                bj = workspaces(sj).boxes_r0rfc0cf(oj,:);
                cur_pair_ious(oi) = intersection_over_union( bi, bj, 'r0rfc0cf', 'r0rfc0cf' );
            end
            
            min_iou_overlap_grid(si,sj) = min(cur_pair_ious);
            
        end
        
    end
    end
    
    [di,dj] = find( min_iou_overlap_grid > dup_threshold );
    if ~isempty(di)
        temp_inds = [di;dj];
        % of the inds with dupes, just remove a single one with the lowest situation support score
        ind_remove = temp_inds( argmin( [workspaces([temp_inds]).situation_support] ) );
        
        % with that guy gone, recheck
        dummy_workspaces = workspaces;
        dummy_workspaces( ind_remove ).labels = [];
        [~, dup_inds] = duplicate_workspace_inds( dummy_workspaces, situation_objects, dup_threshold );
        
        dup_inds = [dup_inds ind_remove];
    end
     
end
        
        
        
        
        