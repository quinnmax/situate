


function [ workspace, records, visualizer_return_status ] = main_loop( im_fname, p, learned_models )
% [ workspace, records, visualizer_return_status ] = main_loop( im_fname, p, learned_models );



    %% initialization 
        
    % load an image, label
        [label,im] = situate.load_image_and_data( im_fname, p );
        im_size = [size(im,1), size(im,2)];
    
    % workspace
        % this contains things that were found by a scout, accepted by a
        % reviewer, and built by a builder. they influence conditional
        % location and size distributions and are the returned solution for
        % an investigation of a situation.
        %
        % it also contains a little bit of image information that can be
        % passed around.
        workspace = workspace_initialize(p,im_size);
        
        
    % initialize distributions struct, which keeps track of distribution during a run, including:
    %   obj urgency, 
    %   conditional distributions
        d = [];
        for dist_index = 1:length(p.situation_objects)
            d(dist_index).interest          = p.situation_objects{dist_index};
            d(dist_index).interest_priority = p.situation_objects_urgency_pre.(p.situation_objects{dist_index});
            d(dist_index).distribution      = learned_models.situation_model.joint;
            if nargin(p.situation_model.update) == 3 % see if it wants the image for updating
                d(dist_index).distribution      = p.situation_model.update( d(dist_index).distribution, p.situation_objects{dist_index}, workspace );
            else
                d(dist_index).distribution      = p.situation_model.update( d(dist_index).distribution, p.situation_objects{dist_index}, workspace, im );
            end
            d(dist_index).image_size        = [size(im,1)   size(im,2)];
            d(dist_index).image_size_px     =  size(im,1) * size(im,2);
        end
        joint_dist_index = length(d) + 1;
        d(joint_dist_index).interest          = 'joint';
        d(joint_dist_index).interest_priority = 0;
        d(joint_dist_index).distribution      = learned_models.situation_model.joint;
        if nargin(p.situation_model.update) == 3 % see if it wants the image
            d(dist_index).distribution            = p.situation_model.update( d(dist_index).distribution, p.situation_objects{dist_index}, workspace);
        else
            d(dist_index).distribution            = p.situation_model.update( d(dist_index).distribution, p.situation_objects{dist_index}, workspace, im );
        end
        d(joint_dist_index).image_size        = [size(im,1)   size(im,2)];
        d(joint_dist_index).image_size_px     =  size(im,1) * size(im,2);
        
    % initialize the agent pool
        agent_pool = repmat( agent_initialize(), 1, p.num_scouts );
        for ai = 1:length(agent_pool)
            agent_pool(ai) = agent_initialize(p);
        end
        agent_types = {'scout','reviewer','builder'};
        
    % initialize record keeping 
        records = []; % store information about the run. includes workspace entry event history, scout record, and whatever else you'd like to pass back out
        records.agent_types = agent_types;
        current_agent_snapshot_lean = [];
            current_agent_snapshot_lean.type = uint8( 0 );
            current_agent_snapshot_lean.interest = uint8( 0 );
            current_agent_snapshot_lean.box.r0rfc0cf = [0 0 0 0];
            current_agent_snapshot_lean.support = [];
        records.agent_record = repmat( current_agent_snapshot_lean, p.num_iterations, 1 );
        records.population_count          = [];
        records.population_count.scout    = 0;
        records.population_count.reviewer = 0;
        records.population_count.builder  = 0;
        records.population_count = repmat(records.population_count,p.num_iterations+1,1);
        for agent_type = {'scout','reviewer','builder'}
            records.population_count(1).(agent_type{:}) = sum( strcmp( agent_type{:}, {agent_pool.type} ) );
        end
        
    % initialize the visualization
    global visualizer_run_status;
    visualizer_run_status = 'unstarted'; % this does need to be here. it is looked at from within the visualizer
    if p.viz_options.on_iteration || p.viz_options.on_workspace_change || p.viz_options.on_end
        [~,visualization_description] = fileparts(im_fname);
        [h, visualizer_run_status] = situate.visualize( [], im, p, d, workspace, [], records.population_count, records.agent_record, visualization_description );
        % see if an exit command came from the GUI
        if ~ishandle(h), visualizer_run_status = 'stop'; end
        if any( strcmp( visualizer_run_status, {'next_image','restart','stop'} ) )
            visualizer_return_status = visualizer_run_status;
            return;
        end
    end



    %% the iteration loop 
    broke_for = [];
    for iteration = 1:p.num_iterations
            
        % select an agent
        % evaluate it
        % take a snapshot of it
        % see if workspace changed
        
            workspace_snapshot = workspace;
            agent_index        = sample_1d( [agent_pool.urgency], 1 );
            
            % note, d is an output of evaluating agents because we might
            % have sampling without replacement or a record of sampled
            % locations or something being updated
            [agent_pool,d,workspace] = agent_evaluate( agent_pool, agent_index, im, label, d, p, workspace, learned_models );
            current_agent_snapshot   = agent_pool(agent_index);
            
            % update distributions and support for existing workspace objects
            workspace_changed = ~isequal(workspace,workspace_snapshot);
            if workspace_changed
                % then update each distribution struct
                for di = 1:length( p.situation_objects )
                    % d(end) is the joint
                    % d(di).interest is the interest for this distribution
                    % workspace should be the conditioning object
                    if nargin(p.situation_model.update) == 3
                        d(di).distribution = p.situation_model.update( d(end).distribution, d(di).interest, workspace );
                    else
                        d(di).distribution = p.situation_model.update( d(end).distribution, d(di).interest, workspace, im );
                    end
                end

                % update support for existing workspace objects
                for wi = 1:length(workspace.labels)

                    cur_box = workspace.boxes_r0rfc0cf(wi,:);
                    dist_index = strcmp( {d.interest}, workspace.labels{wi} );
                    [~,new_density] = p.situation_model.sample( d(dist_index).distribution, workspace.labels{wi}, 1, d(1).image_size, cur_box );
                    workspace.external_support(wi) = p.external_support_function( new_density );

                    switch class( p.total_support_function )
                        case 'function_handle'
                            workspace.total_support(wi) = p.total_support_function( workspace.internal_support(wi), workspace.external_support(wi) );
                        case 'cell'
                            oi = strcmp( p.situation_objects, workspace.labels{wi} );
                            workspace.total_support(wi) = p.total_support_function{oi}( workspace.internal_support(wi), workspace.external_support(wi) );
                        otherwise
                            error(['dunno what to do with ' class(p.total_support_function)]);
                    end

                end
                
            end
                
            % update temperature
            if isfield(p,'temperature')
                workspace.temperature = p.temperature.update( workspace );
            end
            
        % update records
        
            % update record of scouting behavior
            records.workspace_record(iteration) = workspace_snapshot;
            current_agent_snapshot_lean = [];
            current_agent_snapshot_lean.type = uint8( find(strcmp(current_agent_snapshot.type, agent_types ) ) );
            current_agent_snapshot_lean.interest = uint8( find( strcmp( current_agent_snapshot.interest, p.situation_objects )));
            current_agent_snapshot_lean.box.r0rfc0cf = current_agent_snapshot.box.r0rfc0cf;
            current_agent_snapshot_lean.support = current_agent_snapshot.support;
            records.agent_record(iteration)     = current_agent_snapshot_lean;
            
            % population of agent types
            if iteration == 1
                records.population_count = zeros(1,length(agent_types));
                records.population_count = records.population_count + strcmp(current_agent_snapshot.type,agent_types);
            else
                records.population_count(iteration,:) = records.population_count(iteration-1,:) + strcmp(current_agent_snapshot.type,agent_types);
            end
            
            % small adjustment for direct scout->reviewer pipeline
            if isequal(current_agent_snapshot.type,'scout') && workspace_changed
                % then we must have added an object using the direct 
                % scout->workspace option, which means the current agent 
                % doesn't actually have the total support. So, we'll pull 
                % it from the end of the workspace instead. 
                records.agent_record(iteration).support.total = workspace.total_support(end);
            end
            
        % update visualization
        
            if ( p.viz_options.on_iteration && mod(iteration, p.viz_options.on_iteration_mod)==0 ) ...
            || ( p.viz_options.on_workspace_change && workspace_changed )
                
                [~,fname_no_path] = fileparts(im_fname); 
                visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)] };

                [h, visualizer_run_status] = situate.visualize( h, im, p, d, workspace, current_agent_snapshot, records.population_count, records.agent_record, visualization_description );
                
                % see if an exit command came from the GUI
                if ~ishandle(h), visualizer_run_status = 'stop'; end
                if any( strcmp( visualizer_run_status, {'next_image','restart','stop'} ) )
                    visualizer_return_status = visualizer_run_status;
                    return; 
                end 
            end
            
        % check completion status
        
            if workspace_changed 
                [is_done, message] = p.stopping_condition( workspace, p );
                if is_done
                    broke_for = message;
                    break; 
                end
            end
            
        % update the agent pool
            
            % remove the evaluated agent from the pool
            agent_pool(agent_index)  = [];
        
            % clean up the agent pool
            if workspace_changed
                
                if p.agent_pool_cleanup.on_object_of_interest_found
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
                
                if p.agent_pool_cleanup.on_workspace_change && workspace_changed
                    
                     agent_pool = [];
                    
                end
                
           end
        
        % generate new agents based on the current agent's findings
            
            if p.adjustment_model_activation_logic(current_agent_snapshot,workspace)
                % need to make this compatible with box adjust, and then go
                % back and update the local search functions
                agent_pool = p.adjustment_model_apply( learned_models.adjustment_model, current_agent_snapshot, agent_pool, im );
            end
          
        % edit: hack adjusts interest priority values.
        %
        % There's a problem where three objects are checked in
        % provisionally, and we're not actually looking for any of them
        % anymore, so we try to normalize a distribution of all zeros.
        %
        % The solution is to just return the tentatively checked-in objects
        % to their original priority and continue on.
            if sum( [d.interest_priority] ) == 0
                for wi = 1:size(workspace.boxes,1)
                if workspace.total_support(wi) < p.thresholds.total_support_final
                    di = strcmp( workspace.labels{wi}, {d.interest} );
                    d(di).interest_priority = p.situation_objects_urgency_pre.( d(di).interest );
                end
                end
            end
            
        % if the pool is under size, top off with default scouts
        while isempty(agent_pool) || sum( strcmp( 'scout', {agent_pool.type} ) ) < p.num_scouts
            if isempty(agent_pool)
                agent_pool = agent_initialize(p); 
            else
                agent_pool(end+1) = agent_initialize(p); 
            end
            
            records.population_count(iteration,:) = records.population_count(iteration,:) + strcmp('scout',agent_types);
        end
            
    end % of main iteration loop



    %% final recording of results and visualizer updating 
    
        % update records
        records.agent_pool      = agent_pool;
        records.workspace_final = workspace;
        
        % update visualization
        if p.viz_options.on_end
            if ~exist('h','var'), h = []; end
            [~,fname_no_path] = fileparts(im_fname);

            visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)] };
            if isfield(p,'temperature') && isfield(workspace,'temperature')
                visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]; ['temp: ' num2str(workspace.temperature)]; broke_for};
            end

            [h, visualizer_run_status] = situate.visualize( h, im, p, d, workspace, [], records.population_count, records.agent_record, visualization_description );
            % interpret closing the window as 'no thank you'
            if ~ishandle(h)
                visualizer_run_status = 'stop'; 
            end
            visualizer_return_status = visualizer_run_status;
        else
            % we made it through the iteration loop, 
            % if the user doesn't specify some other behavior in the final display,
            % we'll assume that we should continue on to the next image
            visualizer_return_status = 'next_image';
        end



end



%% initialization functions 

function workspace = workspace_initialize(p,im_size)

    workspace.boxes_r0rfc0cf   = [];
    workspace.labels           = {};
    workspace.labels_raw       = {};
    workspace.internal_support = [];
    workspace.external_support = [];
    workspace.total_support    = [];
    workspace.GT_IOU           = [];
    
    workspace.im_size = im_size;
    
    workspace.situation_support = 0;
    
    if isfield(p,'temperature')
        workspace.temperature = p.temperature.initial;
    else
        workspace.temperature = -1;
    end
    
end

function agent = agent_initialize(p)

    persistent agent_base;
    persistent p_old;
    
    if ~exist('p','var') || isempty(p)
        p = [];
    end
    
    if isempty(agent_base) || ~isequal(p,p_old)
        agent_base                           = [];
        agent_base.type                      = 'scout';
        agent_base.interest                  = [];
        agent_base.urgency                   = [];
        agent_base.box.r0rfc0cf              = [];
        agent_base.box.xywh                  = [];
        agent_base.box.xcycwh                = [];
        agent_base.box.aspect_ratio          = [];
        agent_base.box.area_ratio            = [];
        agent_base.support.internal          = NaN;
        agent_base.support.external          = NaN;
        agent_base.support.total             = NaN;
        agent_base.support.GROUND_TRUTH      = NaN;
        agent_base.support.sample_densities  = NaN;
        agent_base.eval_function             = []; % not really using it right now :/
        agent_base.GT_label_raw = [];
    
        if ~isempty(p)
            agent_base.urgency  = p.agent_urgency_defaults.scout;
        end
        
        p_old = p;
    end
   
    agent = agent_base;
    
end



%% eval agent (general, just routing) 

function [agent_pool, d, workspace] = agent_evaluate( agent_pool, agent_index, im, label, d, p, workspace, learned_models )

    object_was_added = false;

    switch( agent_pool(agent_index).type )
        case 'scout'
            % sampling from d may change it, so we include it as an output
            [agent_pool, d] = agent_evaluate_scout( agent_pool, agent_index, p, d, im, label, learned_models );
        case 'reviewer'
            % reviewers do not modify the distributions
            [agent_pool] = agent_evaluate_reviewer( agent_pool, agent_index, p, workspace, d );
        case 'builder'
            % builders modify d by changing the prior on scout interests,
            % and by focusing attention on box sizes and shapes similar to
            % those that have been found to be reasonable so far.
            [workspace,agent_pool,object_was_added] = agent_evaluate_builder( agent_pool, agent_index, workspace );
        otherwise
            error('situate:main_loop:agent_evaluate:agentTypeUnknown','agent does not have a known type field'); 
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
        agent_pool(agent_index).support.external = agent_pool(end).support.external;
        agent_pool(agent_index).support.total    = agent_pool(end).support.total;
        if isequal(agent_pool(end).type,'reviewer')
            % the reviewer failed to spawn a builder, so just fizzle
            agent_pool(end) = [];
        else
            % the reviewer did spawn a builder, so evaluate it
            assert(isequal(agent_pool(end).type,'builder'));
            [workspace, agent_pool, object_was_added] = agent_evaluate_builder( agent_pool, length(agent_pool), workspace );
            % feed the total support back to the scout, since this bonkers
            % process is in effect and the addition to the workspace needs
            % to be justified with a final score. alternatively, we could
            % just turn scouts into reviewers and builders, rather than
            % adding them to the pool...
            agent_pool([end-1 end]) = [];
        end
    end
    
    % for found objects, adjust their priority
    if object_was_added
       for wi = 1:length(workspace.labels)
            if workspace.total_support(wi) >= p.thresholds.total_support_final
                cur_obj_type_ind = find( strcmp( workspace.labels(wi), p.situation_objects ) );
                d(cur_obj_type_ind).interest_priority = p.situation_objects_urgency_post.( p.situation_objects{cur_obj_type_ind} );
            end
        end
    end
    
end



%% eval scout 

function [agent_pool,d] = agent_evaluate_scout( agent_pool, agent_index, p, d, im, label, learned_models ) 

    if isempty(agent_pool(agent_index).interest)
        agent_pool(agent_index).interest = p.situation_objects{ sample_1d( [d.interest_priority], 1 ) };
    end
    
    assert( isequal( agent_pool(agent_index).type, 'scout' ) );
    
    cur_agent = agent_pool(agent_index);
    
    % pick a box for our scout (if it doesn't already have one)
    
        if isempty(cur_agent.box.r0rfc0cf)

            % then we need to pick out a box for our scout

            di = find(strcmp({d.interest},cur_agent.interest));
            
            if nargout(p.situation_model.sample) == 2
                % see if it wants to change the distribution by sampling
                % (such as for inhibition on return)
                [sampled_box_r0rfc0cf, sample_density] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)] ); 
            else
                [sampled_box_r0rfc0cf, sample_density, d(di).distribution] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)] ); 
            end
            
            % double checking that it's in bounds 
            r0 = round(sampled_box_r0rfc0cf(1));
            rf = round(sampled_box_r0rfc0cf(2));
            c0 = round(sampled_box_r0rfc0cf(3));
            cf = round(sampled_box_r0rfc0cf(4));
            r0 = max( r0, 1);
            rf = min( rf, size(im,1) );
            c0 = max( c0, 1);
            cf = min( cf, size(im,2) );

            % filling out the parameters
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
            
            cur_agent.support.sample_densities = sample_density;
        else
            % This means the scout was spawned with a location in mind,
            % probably for local search.
            
            % Just update the sample density of the box with respect to the distribution as it exists 
            % now. When it was generated, it just had the sample density of its template agent.
            di = find(strcmp({d.interest},cur_agent.interest));
            [~, sample_density] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)], cur_agent.box.r0rfc0cf ); 
            cur_agent.support.sample_densities = sample_density;
        end
        
    % figure out GROUND_TRUTH support. this is the oracle response. getting
    % it for tracking, or if we're using IOU-oracle as our eval method
    
        try
            relevant_label_ind = find(strcmp(cur_agent.interest,label.labels_adjusted),1,'first');
            ground_truth_box_xywh = label.boxes_xywh(relevant_label_ind,:);
            cur_agent.support.GROUND_TRUTH = intersection_over_union( cur_agent.box.xywh, ground_truth_box_xywh, 'xywh' );
            cur_agent.GT_label_raw = label.labels_raw{relevant_label_ind};
        catch
           warning('couldn''t find the relevent objects in the label file, so GROUND_TRUTH_IOU won''t work');
        end

    % figure out the internal support
    
        classification_score = p.classifier_apply(  ...
            learned_models.classifier_model, ...
            cur_agent.interest, ...
            im, ...
            cur_agent.box.r0rfc0cf, ...
            label);
    
        internal_support_adjustment = @(x) floor(x * 100)/100; % rounding to nearest .01 for consistency between display and internal behavior
        cur_agent.support.internal = internal_support_adjustment( classification_score );
        
        
    % upate the agent pool based on what we found
    
        % update anything that changed about the current agent for the
        % visualizer (ie, the sampled box, the support, etc
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
    
    cur_agent.support.external = p.external_support_function( agent_pool(agent_index).support.sample_densities ); 
    
    switch class( p.total_support_function )
        case 'function_handle'
            cur_agent.support.total    = p.total_support_function( cur_agent.support.internal, cur_agent.support.external );
        case 'cell'
            % assume different functions per object type
            oi = strcmp( p.situation_objects, cur_agent.interest );
            cur_agent.support.total    = p.total_support_function{oi}( cur_agent.support.internal, cur_agent.support.external );
        otherwise
            error('dunno what to do with this');
    end
    
    agent_pool(agent_index) = cur_agent;

    % consider adding a builder to the pool
    if cur_agent.support.total >= p.thresholds.total_support_provisional
        agent_pool(end+1) = cur_agent;
        agent_pool(end).type = 'builder';
        agent_pool(end).urgency = p.agent_urgency_defaults.builder;
    end
    
end



%% eval builder 

function [workspace,agent_pool,object_was_added] = agent_evaluate_builder( agent_pool, agent_index, workspace ) 
 
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
        
        case 0 % no matching objects yet, so add it
  
            workspace.boxes_r0rfc0cf(end+1,:)   = cur_agent.box.r0rfc0cf;
            workspace.internal_support(end+1)   = cur_agent.support.internal;
            workspace.external_support(end+1)   = cur_agent.support.external;
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
                
                % nothing changed, so just bail
                return;
                
            end
            
    end
     
end


