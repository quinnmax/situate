


function [ workspace, records, situate_visualizer_return_status ] = situate_sketch( im_fname, p, learned_models )

% [ workspace, run_data, visualizer_status_string ] = situate_sketch( im_fname, p, learned_stuff );


    
    %% initialization
        
    % load an image, label
        im = imresize_px(double( imread(im_fname))/255, p.image_redim_px);
        fname_lb = [im_fname(1:end-4) '.labl'];
        label_temp1 = situate_image_data(fname_lb);
        label_temp2 = situate_image_data_rescale( label_temp1, size(im,1), size(im,2) );
        label = situate_image_data_label_adjust( label_temp2, p );
        
    % workspace
        % this contains things that were found by a scout, accepted by a
        % reviewer, and built by a builder. they influence conditional
        % location and size distributions and are the returned solution for
        % an investigation of a situation.
        %
        % it also contains a little bit of image information that can be
        % passed around.
        workspace = workspace_initialize();
        
    % initialize distributions for object type, box size, box shape, object location
        for di = 1:length(p.situation_objects)
            d(di) = situate_distribution_struct_initialize( p.situation_objects{di}, p, im, learned_models ); 
        end
        
    % initialize the agent pool
        agent_pool = repmat( agent_initialize(), 1, p.num_scouts );
        for ai = 1:length(agent_pool)
            agent_pool(ai) = agent_initialize(d,p);
        end
        
    % initialize record keeping 
        records = []; % store information about the run. includes workspace entry event history, scout record, and whatever else you'd like to pass back out
        records.agent_record = repmat( agent_initialize(), p.num_iterations, 1 );
        records.agent_record_flat = cell(p.num_iterations,7); % iteration, agent_type, interest, internal_support, total_support, ground truth iou, box_r0rfc0cf
        %records.dist_struct               = [];
        records.population_count          = [];
        records.population_count.scout    = 0;
        records.population_count.reviewer = 0;
        records.population_count.builder  = 0;
        records.population_count = repmat(records.population_count,p.num_iterations+1,1);
        for agent_type = {'scout','reviewer','builder'}
            records.population_count(1).(agent_type{:}) = sum( strcmp( agent_type{:}, {agent_pool.type} ) );
        end
        
    % initialize the visualization
    global situate_visualizer_run_status;
    situate_visualizer_run_status = 'unstarted'; % this does need to be here. it is looked at from within the visualizer
    if p.show_visualization_on_iteration || p.show_visualization_on_workspace_change || p.show_visualization_on_end
        [~,visualization_description] = fileparts(im_fname);
        [h, situate_visualizer_run_status] = situate_visualize( [], im, p, d, workspace, [], records.population_count, records.agent_record, visualization_description );
        % see if an exit command came from the GUI
        if ~ishandle(h), situate_visualizer_run_status = 'stop'; end
        if any( strcmp( situate_visualizer_run_status, {'next_image','restart','stop'} ) )
            situate_visualizer_return_status = situate_visualizer_run_status;
            return;
        end
    end
    
    
    
    %% the iteration loop
    
    for iteration = 1:p.num_iterations
            
        % select and evaluate an agent
        %   take snapshot of the agent
        %   see if workspace changed
            workspace_snapshot  = workspace;
            agent_index                  = sample_1d( [agent_pool.urgency], 1 );
            [agent_pool,d,workspace]     = agent_evaluate( agent_pool, agent_index, im, label, d, p, workspace );
            current_agent_snapshot = agent_pool(agent_index);
            
        % take note of changes to the workspace
            workspace_changed = false;
            if ~isequal(workspace,workspace_snapshot)
                workspace_changed = true;
            end
            
        % update records
            % update record of scouting behavior
            records.workspace_record(iteration) = workspace_snapshot;
            records.agent_record(iteration)     = current_agent_snapshot;
            records.agent_record_flat(iteration,:) = { ...
                iteration, ...
                current_agent_snapshot.type, ...
                current_agent_snapshot.interest, ...
                current_agent_snapshot.support.internal, ...
                current_agent_snapshot.support.total, ...
                current_agent_snapshot.support.GROUND_TRUTH, ...
                current_agent_snapshot.box.r0rfc0cf };
            %records.dist_struct(end+1).iteration = iteration;
            %records.dist_struct(end+1).snapshot  = d;
            for agent_type = {'scout','reviewer','builder'}
                records.population_count(iteration).(agent_type{:}) = sum( strcmp( agent_type{:}, {agent_pool.type} ) );
            end
            % dumb hack
            if isequal(current_agent_snapshot.type,'scout') && workspace_changed
                % then we must have added an object using the direct 
                % scout->workspace option, which means the current agent 
                % doesn't actually have the total support. So, we'll pull 
                % it from the end of the workspace instead. 
                records.agent_record_flat{iteration,4} = workspace.total_support(end);
                records.agent_record(iteration).support.total = workspace.total_support(end);
            end
            
        % update visualization
            if (p.show_visualization_on_iteration           && mod(iteration,p.show_visualization_on_iteration_mod)==0) ...
            || (p.show_visualization_on_workspace_change    && workspace_changed)
                [~,fname_no_path] = fileparts(im_fname); 
                visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]};
                [h, situate_visualizer_run_status] = situate_visualize( h, im, p, d, workspace, current_agent_snapshot, records.population_count, records.agent_record, visualization_description );
                % see if an exit command came from the GUI
                if ~ishandle(h), situate_visualizer_run_status = 'stop'; end
                if any( strcmp( situate_visualizer_run_status, {'next_image','restart','stop'} ) )
                    situate_visualizer_return_status = situate_visualizer_run_status;
                    return; 
                end 
            end
            
        % see if we're done with iterations due to a sufficient detection
            if workspace_changed && situate_situation_found( workspace, p )
                break; 
            end
            
        % consider spawning nearby scouts on provisional check-in
            if p.spawn_nearby_scouts_on_provisional_checkin ...
            && workspace_changed ...
            && current_agent_snapshot.support.total < p.thresholds.total_support_final % ie, was a provisional check-in
                agent_pool = spawn_local_scouts( current_agent_snapshot, agent_pool, d );
            end
            
        % update the agent pool
            
            % remove the evaluated agent from the pool
            agent_pool(agent_index)  = [];
        
            % clean up the agent pool
            if workspace_changed
                
                if p.agent_pool_cleanup.agents_interested_in_found_objects
                    % clear out agents that are looking for objects that have reached final checkin
                    for i = 1:length(workspace.labels)
                        if workspace.total_support >= p.thresholds.total_support_final
                            interest_to_clear = workspace.labels{i};
                            inds_to_clear = false(length(agent_pool),1);
                            for j = 1:length(agent_pool)
                                if isequal(agent_pool(j).interest,interest_to_clear)
                                    inds_to_clear(j) = true;
                                end
                            end
                            agent_pool(inds_to_clear) = [];
                        end
                    end
                end
                
                if p.agent_pool_cleanup.agents_with_stale_history
                    % if workspace object was added, we want to make sure that we
                    % keep agents looking for the same interest so our local scouts
                    % don't get killed off. However, if we found something that is
                    % of a different type, we might want to refresh everything else
                    % so it's being sampled from a fresh distribution, and we don't
                    % use too many stale agents
                    inds_to_clear = false(length(agent_pool),1);
                    for j = 1:length(agent_pool)
                        if ~isequal(current_agent_snapshot.interest, agent_pool(j).interest )
                            inds_to_clear(j) = true;
                        end
                    end

                    agent_pool(inds_to_clear) = [];
                end
                
            end
            
            % if the pool is under size, top off with default scouts
            while isempty(agent_pool) || sum( strcmp( 'scout', {agent_pool.type} ) ) < p.num_scouts
                agent_pool(end+1) = agent_initialize(d,p);
            end
            records.population_count(iteration).scout = sum( strcmp( 'scout', {agent_pool.type} ) );
           
       
        % edit: hack adjusts interest priority values.
        %
        % There's a problem where three objects are checked in
        % provisionally, and we're not actually looking for any of them
        % anymore, so we try to normalize a distribution of all zeros.
        %
        % The solution is to just return the tentatively checked-in objects
        % to their original priority and continue on.
            if sum( [d.interest_priority] ) == 0, 
            for wi = 1:size(workspace.boxes,1)
            if workspace.total_support(wi) < p.thresholds.total_support_final, 
            d( strcmp( workspace.labels{wi}, {d.interest} ) ).interest_priority = p.object_type_priority_before_example_is_found; 
            end
            end
            end
            
    end % of main iteration loop
    
    
    
    %% final recording of results and visualizer updating
    
        % update records
        for agent_type = {'scout','reviewer','builder'}
            records.population_count(iteration).(agent_type{:}) = sum( strcmp( agent_type{:}, {agent_pool.type} ) );
        end
        records.agent_pool = agent_pool;
        records.workspace_final = workspace;
        empty_inds = cellfun( @isempty, records.agent_record_flat (:,1) );
        records.agent_record_flat(empty_inds,:) = [];
    
        % update visualization
        if p.show_visualization_on_end
            if ~exist('h','var'), h = []; end
            [~,fname_no_path] = fileparts(im_fname); 
            visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]};
            [h, situate_visualizer_run_status] = situate_visualize( h, im, p, d, workspace, [], records.population_count, records.agent_record, visualization_description );
            % interpret closing the window as 'no thank you'
            if ~ishandle(h), 
                situate_visualizer_run_status = 'stop'; 
            end
            situate_visualizer_return_status = situate_visualizer_run_status;
        else
            % we made it through the iteration loop, 
            % if the user doesn't specify some other behavior in the final display,
            % we'll assume that we should continue on to the next image
            situate_visualizer_return_status = 'next_image';
        end
    
        
    
end



%% initialization functions

function workspace = workspace_initialize()

    workspace.boxes_r0rfc0cf   = [];
    workspace.labels           = {};
    workspace.labels_raw       = {};
    workspace.internal_support = [];
    workspace.total_support    = [];
    workspace.GT_IOU           = [];
    
end

function agent = agent_initialize(d,p)

    agent.type                 = 'scout';
    agent.interest             = [];
    agent.urgency              = [];
    agent.box.r0rfc0cf         = [];
    agent.box.xywh             = [];
    agent.box.xcycwh           = [];
    agent.box.aspect_ratio     = [];
    agent.box.area_ratio       = [];
    agent.support.internal     = 0;
    agent.support.external     = 0;
    agent.support.total        = 0;
    agent.support.GROUND_TRUTH = [];
    agent.support.external_support_vect = [];
    agent.eval_function        = []; % not really using it right now :/
    
    agent.GT_label_raw = [];
    
    if exist('d','var')
        agent.interest = d( sample_1d( [d.interest_priority] ) ).interest;
    end
    
    if exist('p','var')
        agent.urgency  = p.agent_urgency_defaults.scout;
    end
        
end



%% eval agent (general, just routing)

function [agent_pool, d, workspace] = agent_evaluate( agent_pool, agent_index, im, label, d, p, workspace )

    agent_pool_initial_length = length(agent_pool);
    
    switch( agent_pool(agent_index).type )
        
        case 'scout'
            % scouts modify d by inhibition on return
            [agent_pool, d] = agent_evaluate_scout( agent_pool, agent_index, p, workspace, d, im, label );
        case 'reviewer'
            % reviewers do not modify the distributions
            [agent_pool] = agent_evaluate_reviewer( agent_pool, agent_index, p, workspace, d );
        case 'builder'
            % builders modify d by changing the prior on scout interests,
            % and by focusing attention on box sizes and shapes similar to
            % those that have been found to be reasonable so far.
            [workspace,d,agent_pool] = agent_evaluate_builder( agent_pool, agent_index, workspace, d, p  );
        otherwise
            error('situate_sketch:agent_evaluate:agentTypeUnknown','agent does not have a known type field');
            
    end
    
    % implementing the direct scout -> reviewer -> builder pipeline
    if p.use_direct_scout_to_workspace_pipe ...
    && strcmp(agent_pool(agent_index).type, 'scout' ) ...
    && agent_pool(agent_index).support.internal >= p.thresholds.internal_support
        % We now know that a scout added a reviewer to the end of the agent
        % pool. We'll evaluate that and the associated builder, and then
        % delete both of them, keeping the iteration counter from ticking
        % up any further. The scout will be killed in the iteration loop
        % per usual.
        [agent_pool] = agent_evaluate_reviewer( agent_pool, length(agent_pool), p, workspace, d );
        agent_pool(agent_index).support.total = agent_pool(end).support.total;
        if isequal(agent_pool(end).type,'reviewer')
            % the reviewer failed to spawn a builder, so just fizzle
            agent_pool(end) = [];
        else
            % the reviewer did spawn a builder, so evaluate it
            assert(isequal(agent_pool(end).type,'builder'));
            [workspace, d] = agent_evaluate_builder( agent_pool, length(agent_pool), workspace, d, p );
            % feed the total support back to the scout, since this bonkers
            % process is in effect and the addition to the workspace needs
            % to be justified with a final score. alternatively, we could
            % just turn scouts into reviewers and builders, rather than
            % adding them to the pool...
            agent_pool([end-1 end]) = [];
        end
    end
    
end



%% eval scout

function [agent_pool,d] = agent_evaluate_scout( agent_pool, agent_index, p, workspace, d, im, label )     

    cur_agent = agent_pool(agent_index);
    assert( isequal( cur_agent.type, 'scout' ) );
    
    % pick a box for our scout (if it doesn't already have one)
    
        if isempty(cur_agent.box.r0rfc0cf)

            % then we need to pick out a box for our scout

            di = find(strcmp({d.interest},cur_agent.interest)); 
            [d(di), sampled_box_r0rfc0cf, box_density] = situate_sample_box( d(di), p );

            r0 = round(sampled_box_r0rfc0cf(1));
            rf = round(sampled_box_r0rfc0cf(2));
            c0 = round(sampled_box_r0rfc0cf(3));
            cf = round(sampled_box_r0rfc0cf(4));

            r0 = max( r0, 1);
            rf = min( rf, d(di).image_size(1) );
            c0 = max( c0, 1);
            cf = min( cf, d(di).image_size(2) );

            w = cf-c0+1;
            h = rf-r0+1;

            x = c0;
            y = r0;

            xc = round(x + w/2);
            yc = round(y + h/2);

            cur_agent.box.r0rfc0cf = [ r0 rf c0 cf ];
            cur_agent.box.xywh     = [  x  y  w  h ];
            cur_agent.box.xcycwh   = [ xc yc  w  h ];
            cur_agent.box.aspect_ratio = w/h;
            cur_agent.box.area_ratio   = (w*h) / (size(im,1)*size(im,2));
            
            % for calculating external support
            % regress internal support, box density, location density to IOU
            cur_agent.support.external_support_vect = box_density;

        end
        
    % figure out GROUND_TRUTH support. this is the oracle response. getting
    % it for tracking, or if we're using IOU-oracle as our eval method
    
        try
            relevant_label_ind = find(strcmp(cur_agent.interest,label.labels_adjusted),1,'first');
            ground_truth_box_xywh = label.boxes_xywh(relevant_label_ind,:);
            cur_agent.support.GROUND_TRUTH = intersection_over_union_xywh( cur_agent.box.xywh, ground_truth_box_xywh );
            cur_agent.GT_label_raw = label.labels_raw{relevant_label_ind};
        catch
           warning('couldn''t find the relevent objects in the label file, so GROUND_TRUTH_IOU won''t work');
        end

    % figure out the internal support
    
        switch p.classification_method
            case 'HOG-SVM'
                model_ind = find(strcmp(cur_agent.interest,p.situation_objects),1);
                model = d(model_ind).learned_stuff.hog_svm_models.models{ model_ind };
                internal_support_score_function_raw = @(b_xywh) hog_svm.hog_svm_apply( model, im, b_xywh );
            case 'IOU-oracle'
                relevant_label_ind = find(strcmp(cur_agent.interest,label.labels_adjusted),1,'first');
                if isempty(relevant_label_ind), error('couldn''t find the relevent object in the label file, so IOU oracle won''t work'); end
                ground_truth_box_xywh = label.boxes_xywh(relevant_label_ind,:);
                internal_support_score_function_raw = @(b_xywh) intersection_over_union_xywh( b_xywh, ground_truth_box_xywh );
            case 'CNN-SVM'
                model_ind = find(strcmp(cur_agent.interest, p.situation_objects), 1 );
                internal_support_score_function_raw = @(b_xywh) cnn.score_subimage( im, b_xywh, model_ind, d, p );
            otherwise
                error('unrecognized p.classification_method');
        end
        internal_support_score_function = @(b_xywh) floor(internal_support_score_function_raw(b_xywh) * 100)/100; % rounding to nearest .01 for consistency between display and internal behavior
        cur_agent.support.internal = internal_support_score_function( cur_agent.box.xywh );
        
    % see if we can improve the initial box with some tweaking
        
        if p.use_box_adjust ...
        && cur_agent.support.internal >= p.thresholds.internal_support
    
            cur_box_adjust_model        = d(di).learned_stuff.box_adjust_models;
            num_adjustment_iterations   = 9;
            [updated_box_xywh, box_adjust_iterations] = box_adjust.apply_box_adjust_models_mq( cur_box_adjust_model, cur_agent.interest, im, cur_agent.box.xywh, num_adjustment_iterations );
            
            % get updated internal support score
            new_internal_support = internal_support_score_function(updated_box_xywh);
            
            % if updated internal support score is better, 
            % update the box and support
            if new_internal_support > cur_agent.support.internal
                x  = updated_box_xywh(1);
                y  = updated_box_xywh(2);
                w  = updated_box_xywh(3);
                h  = updated_box_xywh(4);
                r0 = y;
                rf = r0 + h - 1;
                c0 = x;
                cf = c0 + w - 1;
                xc = round(x + w/2);
                yc = round(y + h/2);
                cur_agent.box.xywh     = [x y w h];
                cur_agent.box.xcycwh   = [xc yc w h];
                cur_agent.box.r0rfc0cf = [r0 rf c0 cf];
                cur_agent.support.internal = new_internal_support;
            else
                % do nothing with the new box and score
            end
            
        end
        
    % upate the agent pool based on what we found
    % ie, spawn a reviewer
        agent_pool(agent_index) = cur_agent;
        
        % consider adding a reviewer to the pool
        if cur_agent.support.internal >= p.thresholds.internal_support
            agent_pool(end+1) = cur_agent;
            agent_pool(end).type = 'reviewer';
            agent_pool(end).urgency = p.agent_urgency_defaults.reviewer;
        end
       
end



%% eval reviewer


function [agent_pool] = agent_evaluate_reviewer( agent_pool, agent_index, p, workspace, d )
    
    % the reviewer checks to see how compatible a proposed object is with
    % our understanding of the relationships between objects. if the
    % porposal is sufficiently compatible, we send ut off to a builder.
    %
    % currently, there is no evaluation being made here, so the builder is
    % made for sure.
    
    cur_agent = agent_pool(agent_index);
    assert( isequal( cur_agent.type, 'reviewer' ) );
    
    if isfield(p, 'external_support_weight') && p.external_support_weight > 0
        obj = find(strcmp(p.situation_objects, cur_agent.interest), 1);
        x = d(obj).location_data(cur_agent.box.xcycwh(2), cur_agent.box.xcycwh(1));
        m = mean(mean(d(obj).location_data));
        cur_agent.support.external = .5 ^ (m / x);
    else
        cur_agent.support.external = 0;
        p.external_support_weight = 0;
    end
    
    cur_agent.support.total = cur_agent.support.internal * (1-p.external_support_weight) ...
                              + cur_agent.support.external * p.external_support_weight;
    agent_pool(agent_index) = cur_agent;

    % consider adding a builder to the pool
    if cur_agent.support.total >= p.thresholds.total_support_provisional
        agent_pool(end+1) = cur_agent;
        agent_pool(end).type = 'builder';
        agent_pool(end).urgency = p.agent_urgency_defaults.builder;
    end
    
end



%% eval builder

function [workspace,d,agent_pool] = agent_evaluate_builder( agent_pool, agent_index, workspace, d, p )
 
    % the builder checks to see if a proposed object, which has passed both
    % scout and reviewer processes, is actually an improvement over what
    % has already been checked in to the workspace.
    %
    % if there is no object of the proposed type, it is checked in
    % automatically. if there is an existing object of the proposed type,
    % the two are reconciled.
    %
    % if something is checked in, the distributions that are used to generate 
    % scouts are modified to reflect the new information.

    cur_agent = agent_pool(agent_index);
    assert( isequal( cur_agent.type, 'builder' ) );
    
    
    object_was_added = false;
    
    matching_workspace_object_index = find(strcmp( workspace.labels, agent_pool(agent_index).interest) );

    switch length(matching_workspace_object_index)
        
        case 0, % no matching objects yet, so add it
  
            workspace.boxes_r0rfc0cf(end+1,:)   = cur_agent.box.r0rfc0cf;
            workspace.internal_support(end+1)   = cur_agent.support.internal;
            workspace.total_support(end+1)      = cur_agent.support.total;
            workspace.labels{end+1}             = cur_agent.interest;
            
            workspace.labels_raw{end+1}         = cur_agent.GT_label_raw;
            workspace.GT_IOU(end+1)             = cur_agent.support.GROUND_TRUTH;
            
            object_was_added = true;
            
        otherwise
            
            if cur_agent.support.total >= workspace.total_support(matching_workspace_object_index)
                
                % remove the old entry, add the current agent
                workspace.boxes_r0rfc0cf(matching_workspace_object_index,:) = [];
                workspace.internal_support(matching_workspace_object_index) = [];
                workspace.total_support(matching_workspace_object_index)    = [];
                workspace.labels(matching_workspace_object_index)           = [];
                workspace.labels_raw(matching_workspace_object_index)       = [];
                workspace.GT_IOU(matching_workspace_object_index)           = [];
                
                workspace.boxes_r0rfc0cf(end+1,:) = cur_agent.box.r0rfc0cf;
                workspace.internal_support(end+1) = cur_agent.support.internal;
                workspace.total_support(end+1)    = cur_agent.support.total;
                workspace.labels{end+1}           = cur_agent.interest;
                workspace.labels_raw{end+1}       = cur_agent.GT_label_raw;
                workspace.GT_IOU(end+1)           = cur_agent.support.GROUND_TRUTH;
                
                object_was_added = true;
                
            else
                
                % it wasn't an improvement, so do nothing
                
            end
            
    end
     
    if object_was_added 
        
        % something was added, update the distribution structures
       
        for di = 1:length(d)
            d(di) = situate_distribution_struct_update( d(di), p, workspace );
        end
        
    end
    
end


%% spawn local scouts
function agent_pool = spawn_local_scouts( agent_to_expand, agent_pool, d )

    % this is meant to take an agent and spawn a set of scouts that are
    % focusesed on the same object, but nearby boxes. those boxes are:
    %   shifted slightly {up, down, left, right}
    %   slightly {taller and thinner, shorter and wider}
    %   slightly {larger, smaller}

    new_agent_template = agent_to_expand;
    new_agent_template.type = 'scout';
    new_agent_template.urgency = 5;
    new_agent_template.support.internal     = [];
    new_agent_template.support.external     = [];
    new_agent_template.support.total        = [];
    new_agent_template.support.GROUND_TRUTH = [];
    new_agent_template.GT_label_raw = [];
    
    box_w  = new_agent_template.box.xywh(3);
    box_h  = new_agent_template.box.xywh(4);
    step_w = .15 * box_w;
    step_h = .15 * box_h;
    
    % agent up
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) - step_h;
        rf = new_agent.box.r0rfc0cf(2) - step_h;
        c0 = new_agent.box.r0rfc0cf(3);
        cf = new_agent.box.r0rfc0cf(4);
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
        
    % agent down
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) + step_h;
        rf = new_agent.box.r0rfc0cf(2) + step_h;
        c0 = new_agent.box.r0rfc0cf(3);
        cf = new_agent.box.r0rfc0cf(4);
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
        
    % agent left
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1);
        rf = new_agent.box.r0rfc0cf(2);
        c0 = new_agent.box.r0rfc0cf(3) - step_w;
        cf = new_agent.box.r0rfc0cf(4) - step_h;
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
        
    % agent right
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1);
        rf = new_agent.box.r0rfc0cf(2);
        c0 = new_agent.box.r0rfc0cf(3) + step_w;
        cf = new_agent.box.r0rfc0cf(4) + step_h;
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
        
    % agent bigger
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) - step_h/2;
        rf = new_agent.box.r0rfc0cf(2) + step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) - step_w/2;
        cf = new_agent.box.r0rfc0cf(4) + step_w/2;
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
        
    % agent smaller
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) + step_h/2;
        rf = new_agent.box.r0rfc0cf(2) - step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) + step_w/2;
        cf = new_agent.box.r0rfc0cf(4) - step_w/2;
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
        
    % agent taller and narrower
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) - step_h/2;
        rf = new_agent.box.r0rfc0cf(2) + step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) + step_w/2;
        cf = new_agent.box.r0rfc0cf(4) - step_w/2;
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
        
    % agent shorter and wider
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) + step_h/2;
        rf = new_agent.box.r0rfc0cf(2) - step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) - step_w/2;
        cf = new_agent.box.r0rfc0cf(4) + step_w/2;
        x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
        new_agent.box.r0rfc0cf = [r0 rf c0 cf];
        new_agent.box.xywh     = [ x  y  w  h];
        new_agent.box.xcycwh   = [xc yc  w  h];
        new_agent.box.aspect_ratio = w/h;
        new_agent.box.area_ratio   = (w*h) / d(1).image_size_px;
        agent_pool(end+1) = new_agent;
    
end






