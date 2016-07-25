


function [ workspace, d, p, run_data, situate_visualizer_run_status ] = situate_sketch( im_fname, p, learned_stuff )

% [ workspace, d, p, run_data, visualizer_status_string ] = situate_sketch( im_fname, p, learned_stuff );


    
    %% initialization
    % if inputs are not provided, it'll just run with some default values
    % on a default image.
    
        run_data = []; % store information about the run. includes workspace entry event history, scout record, and whatever else you'd like to pass back out
    
    % load an image, label
        % im = imresize_px(double( imread(im_fname))/255, p.salience_model.redim );
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
        workspace_entry_events = cell(p.num_iterations,4);
        
    % initialize distributions for object type, box size, box shape, object location
        
        for di = 1:length(p.situation_objects)
            d(di) = situate_distribution_struct_initialize( p.situation_objects{di}, p, im, learned_stuff ); 
        end
        
    % initialize the agent pool
        agent_pool = repmat( agent_initialize(), 1, p.num_scouts );
        for ai = 1:length(agent_pool)
            agent_pool(ai) = agent_initialize(d,p);
        end
        
    % initialize scout record
        run_data.scout_record = repmat( agent_initialize(), p.num_iterations, 1 );
        
    % initialize population counts for tracking purposes
        population_count          = [];
        population_count.scout    = 0;
        population_count.reviewer = 0;
        population_count.builder  = 0;
        population_count = repmat(population_count,p.num_iterations+1,1);
        
    if p.show_visualization_on_iteration || p.show_visualization_on_workspace_change || p.show_visualization_on_end
        % initialize the visualization
        global situate_visualizer_run_status;
        situate_visualizer_run_status = 'unstarted';
        [~,visualization_description] = fileparts(im_fname);
        [h, situate_visualizer_run_status] = situate_visualize( [], im, p, d, workspace, [], population_count, run_data.scout_record, visualization_description );
        % see if an exit command came from the GUI
        if ~ishandle(h), situate_visualizer_run_status = 'stop'; end
        if any( strcmp( situate_visualizer_run_status, {'next_image','restart','stop'} ) )
            return;
        end
    end
    
    %% the iteration loop
    
    for iteration = 1:p.num_iterations
        
        % get updated population counts for the begining of the iteration
            for agent_type = {'scout','reviewer','builder'}
                population_count(iteration).(agent_type{:}) = sum( strcmp( agent_type{:}, {agent_pool.type} ) );
            end
            
        % select and evaluate an agent
            workspace_total_support_pre  = sum(workspace.total_support);
            agent_index                  = sample_1d( [agent_pool.urgency], 1 );
            [agent_pool,d,workspace]     = agent_evaluate( agent_pool, agent_index, im, label, d, p, workspace );
            workspace_total_support_post = sum(workspace.total_support);
            
            evaluated_agent_snapshot = agent_pool(agent_index);
            
        % update visualization and records
        
            % take note of changes to the workspace
            workspace_object_was_added = false;
            if workspace_total_support_post > workspace_total_support_pre
                workspace_object_was_added = true;
                cur_workspace_entry_index = find( strcmp( evaluated_agent_snapshot.interest, workspace.labels ) );
                cur_internal_support  = workspace.internal_support(cur_workspace_entry_index);
                cur_total_support = workspace.total_support(cur_workspace_entry_index);
                workspace_entry_events (iteration,:) = { iteration, evaluated_agent_snapshot.interest, cur_internal_support, cur_total_support };
            end
        
            % update record of scouting behavior
            run_data.scout_record(iteration) = evaluated_agent_snapshot;
            
            % update the visualization
            if p.show_visualization_on_iteration
                if mod(iteration,p.show_visualization_on_iteration_mod)==0
                    [~,fname_no_path] = fileparts(im_fname); 
                    visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]};
                    [h, situate_visualizer_run_status] = situate_visualize( h, im, p, d, workspace, evaluated_agent_snapshot, population_count, run_data.scout_record, visualization_description );
                    % see if an exit command came from the GUI
                    if ~ishandle(h), situate_visualizer_run_status = 'stop'; end
                    if any( strcmp( situate_visualizer_run_status, {'next_image','restart','stop'} ) )
                        return; 
                    end 
                end
            elseif p.show_visualization_on_workspace_change && workspace_object_was_added
                [~,fname_no_path] = fileparts(im_fname); 
                visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]};
                [h, situate_visualizer_run_status] = situate_visualize( h, im, p, d, workspace, evaluated_agent_snapshot, population_count, run_data.scout_record, visualization_description );
                % see if an exit command came from the GUI
                if ~ishandle(h), situate_visualizer_run_status = 'stop'; end
                if any( strcmp( situate_visualizer_run_status, {'next_image','restart','stop'} ) )
                    return; 
                end 
            else
                % progress
            end
           
        % remove the evaluated agent from the pool
            agent_pool(agent_index)  = [];
            
        % see if we're done with iterations due to a sufficient detection
            if workspace_object_was_added && situate_situation_found( workspace, p )
                break; 
            end
            
        % see if we should refresh the whole agent pool
            if p.refresh_agent_pool_after_workspace_change && workspace_object_was_added
                agent_pool = repmat( agent_initialize(), 0, 1 );
            end
            
        % edit: hack adjust to interest priority values.
        %
        % this should only happen if things are tentatively checked into
        % the workspace (for conditioning), aren't being looked for (which
        % is an option), but are still under the .5 IOU needed to consider
        % the detection positive
        %
        % the solution is to just return the tentatively checked-in objects
        % to their original priority and continue on.
            if sum( [d.interest_priority] ) == 0
                for wi = 1:size(workspace.boxes,1)
                    if workspace.total_support(wi) < p.total_support_threshold_2
                        dist_to_adjust = strcmp( workspace.labels{wi}, {d.interest} );
                        d( dist_to_adjust ).interest_priority = p.object_type_priority_before_example_is_found;
                    end
                end
            end
            
        % if the pool is under size, top off with scouts of default priority
            while isempty(agent_pool) || sum( strcmp( 'scout', {agent_pool.type} ) ) < p.num_scouts
                agent_pool(end+1) = agent_initialize(d,p);
            end
            population_count(iteration).scout = sum( strcmp( 'scout', {agent_pool.type} ) );
        
    end
    
    
    
    %% reporting and drawing final visualization
    
    if ~isempty(agent_pool)

        % count number of each agent type, one last time before exiting
        for agent_type = {'scout','reviewer','builder'}
            population_count(iteration).(agent_type{:}) = sum( strcmp( agent_type{:}, {agent_pool.type} ) );
        end

    end
    
    empty_workspace_entry_events_inds = cellfun( @isempty, workspace_entry_events (:,1) );
    workspace_entry_events (empty_workspace_entry_events_inds,:) = [];
    
    run_data.population_count = population_count;
    run_data.agent_pool = agent_pool;
    run_data.workspace_entry_events = workspace_entry_events;
      
    if p.show_visualization_on_end
        if ~exist('h','var'), h = []; end
        [~,fname_no_path] = fileparts(im_fname); 
        visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]};
        [h, situate_visualizer_run_status] = situate_visualize( h, im, p, d, workspace, [], population_count, run_data.scout_record, visualization_description );
        % interpret closing the window as 'no thank you'
        if ~ishandle(h), situate_visualizer_run_status = 'stop'; end
        if strcmp( situate_visualizer_run_status, {'next_image','restart','stop'})
            return; 
        end
    else
        % we made it through the iteration loop, 
        % if the user doesn't specify some other behavior in the final display,
        % we'll assume that we should continue on to the next image
        situate_visualizer_run_status = 'next_image';
    end
    
    
    
end



%% initialization functions

function workspace = workspace_initialize()

    workspace.boxes_r0rfc0cf   = [];
    workspace.labels           = {};
    workspace.labels_raw       = {};
    workspace.internal_support = [];
    workspace.total_support    = [];
    
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
    agent.support.internal     = [];
    agent.support.external     = [];
    agent.support.total        = [];
    agent.support.GROUND_TRUTH = [];
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
    object_was_added = false;

    switch( agent_pool(agent_index).type )
        
        case 'scout'
            % scouts modify d by inhibition on return
            [agent_pool, d] = agent_evaluate_scout( agent_pool, agent_index, im, label, d, p, workspace );
        case 'reviewer'
            % reviewers do not modify the distributions
            [agent_pool] = agent_evaluate_reviewer( agent_pool, agent_index, p, workspace );
        case 'builder'
            % builders modify d by changing the prior on scout interests,
            % and by focusing attention on box sizes and shapes similar to
            % those that have been found to be reasonable so far.
            [workspace,d] = agent_evaluate_builder( agent_pool, agent_index, workspace, d, p  );
        otherwise
            error('situate_sketch:agent_evaluate:agentTypeUnknown','agent does not have a known type field');
            
    end
    
    if p.use_direct_scout_to_workspace_pipe ...
    && strcmp(agent_pool(agent_index).type, 'scout' ) ...
    && length(agent_pool) > agent_pool_initial_length
        % We now know that a scout added a reviewer to the end of the agent
        % pool. We'll evaluate that and the associated builder, and then
        % delete both of them, keeping the iteration counter from ticking
        % up any further. The scout will be killed in the iteration loop
        % per usual.
        [agent_pool]   = agent_evaluate_reviewer( agent_pool, length(agent_pool), p, workspace );
        if isequal(agent_pool(end).type,'reviewer')
            agent_pool(end) = [];
        else
            assert(isequal(agent_pool(end).type,'builder'));
            [workspace, d] = agent_evaluate_builder(  agent_pool, length(agent_pool), workspace, d, p );
            agent_pool([end-1 end]) = [];
        end
    end
    
    if p.refresh_agent_pool_after_workspace_change && object_was_added
        agent_pool = [];
        display('agent_pool was flushed');
        % it'll be refilled with new scouts at the end of the main loop
    end
    
end



%% eval scout

function [agent_pool,d] = agent_evaluate_scout( agent_pool, agent_index, im, im_label, d, p, workspace )     

    cur_agent = agent_pool(agent_index);
    
    % pick a box for our scout (if it doesn't already have one)
    
        if isempty(cur_agent.box.r0rfc0cf)

            % then we need to pick out a box for our scout

            di = find(strcmp({d.interest},cur_agent.interest)); 
            [d(di), sampled_box_r0rfc0cf] = situate_sample_box( d(di), p );

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

        end
        
    % figure out GROUND_TRUTH support. this is the oracle response. getting
    % it for tracking, or if we're using IOU-oracle as our eval method
    
        try
            relevant_label_ind = find(strcmp(cur_agent.interest,im_label.labels_adjusted),1,'first');
            ground_truth_box_xywh = im_label.boxes_xywh(relevant_label_ind,:);
            cur_agent.support.GROUND_TRUTH = intersection_over_union_xywh( cur_agent.box.xywh, ground_truth_box_xywh );
            cur_agent.GT_label_raw = im_label.labels_raw{relevant_label_ind};
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
                relevant_label_ind = find(strcmp(cur_agent.interest,im_label.labels_adjusted),1,'first');
                if isempty(relevant_label_ind), error('couldn''t find the relevent object in the label file, so IOU oracle won''t work'); end
                ground_truth_box_xywh = im_label.boxes_xywh(relevant_label_ind,:);
                internal_support_score_function_raw = @(b_xywh) intersection_over_union_xywh( b_xywh, ground_truth_box_xywh );
            case 'CNN-SVM'
                model_ind = find(strcmp(cur_agent.interest, p.situation_objects), 1 );
                internal_support_score_function_raw = @(b_xywh) cnn.score_subimage( im, b_xywh, model_ind, d, p );
            otherwise
                error('unrecognized p.classification_method');
        end
        internal_support_score_function = @(b_xywh) round(internal_support_score_function_raw(b_xywh) * 100)/100; % rounding to nearest .01 for consistency between display and internal behavior
        cur_agent.support.internal = internal_support_score_function( cur_agent.box.xywh );
        
    % see if we can improve the initial box with some tweaking
        
        if p.use_box_adjust ...
        && cur_agent.support.internal > p.internal_support_threshold
    
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
        if cur_agent.support.internal > p.internal_support_threshold
            agent_pool(end+1) = cur_agent;
            agent_pool(end).type = 'reviewer';
            agent_pool(end).urgency = p.agent_urgency_defaults.reviewer;
        end
       
end



%% eval reviewer


function [agent_pool] = agent_evaluate_reviewer( agent_pool, agent_index, p, workspace )
    
    % the reviewer checks to see how compatible a proposed object is with
    % our understanding of the relationships between objects. if the
    % porposal is sufficiently compatible, we send ut off to a builder.
    %
    % currently, there is no evaluation being made here, so the builder is
    % made for sure.
    
    cur_agent = agent_pool(agent_index);
    cur_agent.support.external = 0;
    cur_agent.support.total = cur_agent.support.internal + cur_agent.support.external;
    agent_pool(agent_index) = cur_agent;

    if cur_agent.support.total > p.total_support_threshold_1
        agent_pool(end+1) = cur_agent;
        agent_pool(end).type = 'builder';
        agent_pool(end).urgency = p.agent_urgency_defaults.builder;
    end
    
end



%% eval builder

function [workspace,d] = agent_evaluate_builder( agent_pool, agent_index, workspace, d, p )
 
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
    
    object_was_added = false;
    
    matching_workspace_object_index = find(strcmp( workspace.labels, agent_pool(agent_index).interest) );

    switch length(matching_workspace_object_index)
        
        case 0, % no matching objects yet, so add it
  
            workspace.boxes_r0rfc0cf(end+1,:)   = cur_agent.box.r0rfc0cf;
            workspace.internal_support(end+1)   = cur_agent.support.internal;
            workspace.total_support(end+1)      = cur_agent.support.total;
            workspace.labels{end+1}             = cur_agent.interest;
            workspace.labels_raw{end+1}         = cur_agent.GT_label_raw;
            object_was_added = true;
            
        otherwise
            
            if cur_agent.support.total > workspace.total_support(matching_workspace_object_index)
                
                % remove the old entry, add the current agent
                workspace.boxes_r0rfc0cf(matching_workspace_object_index,:)          = [];
                workspace.internal_support(matching_workspace_object_index) = [];
                workspace.total_support(matching_workspace_object_index)    = [];
                workspace.labels(matching_workspace_object_index)           = [];
                workspace.labels_raw(matching_workspace_object_index)       = [];
                
                workspace.boxes_r0rfc0cf(end+1,:) = cur_agent.box.r0rfc0cf;
                workspace.internal_support(end+1) = cur_agent.support.internal;
                workspace.total_support(end+1)    = cur_agent.support.total;
                workspace.labels{end+1}           = cur_agent.interest;
                workspace.labels_raw{end+1}       = cur_agent.GT_label_raw;
                
                object_was_added = true;
                
            else
                
                % it wasn't an improvement, so fizzle
                
            end
            
    end
     
    if object_was_added 
        
        % something was added, update the distribution structures
       
        for di = 1:length(d)
            d(di) = situate_distribution_struct_update( d(di), p, workspace );
        end
       
    end
    
end






