function [ workspace, records, all_workspaces ] = run_monte( im_fname, running_params, learned_models  )
% [ workspace_best, records_best, all_workspaces ] = run_monte( im_fname, running_params, learned_models)
 
        im = imread( im_fname );
        if mean(im(:)) < 1, im = 255 * im; end
        label = situate.labl_load( im_fname, running_params ); % may return empty array if label file wasn't found
        im_size = [size(im,1), size(im,2)];
        
        situation_objects = learned_models.situation_model.situation_objects;
        num_objs = numel(situation_objects);
        
        cur_iter_count = 0;
        iterations_per_attention_period = 10;
        iterations_before_deprioritize = 20; % if n iters are evaluated with no updated to workspace, sandbag
          
        running_params_per_agent = running_params;
        running_params_per_agent.use_monte = false;
        
        [ ~, ~, ~, state_prototype ] = situate.run( im_fname, running_params_per_agent, learned_models, [], 1 );
        empty_workspace = situate.workspace_initialize(running_params_per_agent, im_size );
        state_prototype.workspace = empty_workspace;
            
        use_rcnn_like_priming = true;
        if use_rcnn_like_priming
            % initial search
            box_area_ratios = [1/4 1/16];
            box_aspect_ratios = [3/2 2/3];
            box_overlap_ratio = .25;
            show_viz = false;
            show_progress = false;
            use_non_max_suppression = true;
            num_box_adjust_iterations = 2;
            [boxes_r0rfc0cf_return, class_assignments_return, confidences_return, cnn_features_return, total_cnn_calls] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, box_overlap_ratio,  learned_models.classifier_model, learned_models.adjustment_model, use_non_max_suppression, num_box_adjust_iterations, show_viz, show_progress );
            
            % keep a small supset
            rows_keep = false(1,numel(confidences_return));
            max_init_objs_per_type = 3;
            init_score_cutoff = .25;
            for oi = 1:num_objs
                cur_obj_scores = sort(confidences_return(class_assignments_return == oi),'descend');
                if sum(cur_obj_scores>init_score_cutoff) > max_init_objs_per_type
                    score_cutoff = cur_obj_scores(max_init_objs_per_type);
                elseif sum(cur_obj_scores>init_score_cutoff) == 0
                    score_cutoff = cur_obj_scores(1);
                    % keep one of each object type, even if it's under score
                else
                    score_cutoff = init_score_cutoff;
                end
                rows_keep( class_assignments_return == oi & confidences_return >= score_cutoff ) = true;
            end
            rows_remove = setsub(1:size(boxes_r0rfc0cf_return,1),find(rows_keep));
            boxes_r0rfc0cf_return(rows_remove,:) = [];
            class_assignments_return(rows_remove) = [];
            cur_iter_count = cur_iter_count + total_cnn_calls;
            confidences_return(rows_remove) = [];

            % see what came out
            visualize = false;
            if visualize
                figure
                for oi = 1:num_objs
                    subplot(1,num_objs,oi);
                    imshow(im); hold on;
                    cur_rows = find(class_assignments_return==oi);
                    for bi = 1:numel(cur_rows)
                        ci = cur_rows(bi);
                        draw_box( boxes_r0rfc0cf_return(ci,:),'r0rfc0cf','linewidth',2 );
                        text( boxes_r0rfc0cf_return(ci,3), boxes_r0rfc0cf_return(ci,1), num2str( confidences_return(ci) ) );
                    end
                end
            end
            
            % put each found object into its own context, then fill the agent pool with each
            % instance of other objects
            state_pool = repmat(state_prototype,1,size(boxes_r0rfc0cf_return,1));
            for si = 1:size(boxes_r0rfc0cf_return,1)
                state_pool(si).agent_pool(1).box.r0rfc0cf = boxes_r0rfc0cf_return(si,:);
                % first agent pool entry into the first state is a bounding box from the initial search
                state_pool(si).agent_pool(1).interest = [];
                % clear the rest of the agent pool so we know the current addition is evaluated
                state_pool(si).agent_pool(2:end) = [];
                % eval to see if it goes into the workspace (it should if we set the threshold
                % reasonably)
                [ ~, ~, ~, state_pool(si) ] = situate.run( im_fname, running_params_per_agent, learned_models, state_pool(si), 1 );
                % now the cur state pool should have a workspace (maybe not)
                other_obj_init_rows = find(class_assignments_return ~= class_assignments_return(si))';
                % now fill the pool up with the other detected objects
                state_pool(si).agent_pool = repmat(state_prototype.agent_pool(1),1,numel(other_obj_init_rows));
                for bi = 1:numel(other_obj_init_rows)
                    state_pool(si).agent_pool(bi).box.r0rfc0cf = boxes_r0rfc0cf_return( other_obj_init_rows(bi),: );
                end
            end
                   
        else
            state_pool = repmat(state_prototype,1,4);
        end
        
        temp = [state_pool.workspace];
        state_support = [temp.situation_support];
        sampling_table = state_support;
        
        
        
        
        
        
        
        
        % now monte it up
        while cur_iter_count < running_params.num_iterations
            
            si = sample_1d( sampling_table, 1 );
            [ ~, ~, ~, state_out ] = situate.run( im_fname, running_params_per_agent, learned_models, state_pool(si), iterations_per_attention_period );
            cur_iter_count = cur_iter_count + iterations_per_attention_period;
            
            if numel(state_out.workspace.labels) ~= numel(state_pool(si).workspace.labels)
                % if a new object was added, branch and put the node on ice
                state_pool(end+1)     = state_out;
                state_support(end+1)  = state_out.workspace.situation_support;
                sampling_table(end+1) = state_out.workspace.situation_support; 
                sampling_table(si)    = 0;
            else
                % just update the state support and sampling probability
                state_pool(si)     = state_out;
                state_support(si)  = state_out.workspace.situation_support;
                sampling_table(si) = state_out.workspace.situation_support;
                
                % if it's gone too long without an update, put the node on ice
                if state_out.iterations_since_last_update >= iterations_before_deprioritize
                    sampling_table(si) = 0; 
                    state_pool(si).iterations_since_last_update = 0;
                end
                
            end
          
            
            % pool management
            empty_workspace_inds = arrayfun( @(x) isempty( x.labels ), [state_pool.workspace] );

            % short circuit
            if all(empty_workspace_inds)
                records = state_pool(1).records;
                workspace = state_pool(1).workspace;
                all_workspaces = [state_pool.workspace];
                return;
            end

            % remove empties
            workspaces_remove = find( empty_workspace_inds );
            %workspaces_remove = workspaces_remove(2:end);
            state_pool(workspaces_remove) = [];
            sampling_table(workspaces_remove) = [];
            state_support(workspaces_remove) = [];

            % de-dup workspaces
            dup_threshold = .5;
            [~, dup_inds] = duplicate_workspace_inds( [state_pool.workspace], situation_objects, dup_threshold );
            if ~isempty(dup_inds)
                state_pool(dup_inds)     = [];
                state_support(dup_inds)  = [];
                sampling_table(dup_inds) = [];
            end

            % if everyone is in cold storage, wake them all up
            if all( sampling_table == 0 )
                % give them attention back
                sampling_table = state_support;
            end

        end
        
        visualize = false;
        if visualize
            figure;
            for si = 1:numel(state_pool)
                subplot_lazy(numel(state_pool),si);
                situate.workspace_draw(im,running_params,state_pool(si).workspace);
            end
        end
        
        workspace = state_pool(argmax(state_support)).workspace;
        records = state_pool(argmax(state_support)).records;
        all_workspaces = [state_pool.workspace];
        
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
        
        
        
        
        