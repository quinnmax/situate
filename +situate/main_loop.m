


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
            if isstruct(p.situation_objects_urgency_pre)
                d(dist_index).interest_priority = p.situation_objects_urgency_pre.(p.situation_objects{dist_index});
            elseif numel(p.situation_objects_urgency_pre) == 1
                d(dist_index).interest_priority = p.situation_objects_urgency_pre;
            else
                error('multiple values but don''t know to which objects to assign them');
            end
            d(dist_index).distribution      = learned_models.situation_model.joint;
            if nargin(p.situation_model.update) < 4 % see if it wants the image for updating
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
        
        % initialize agent pool
        if isfield(p,'prime_agent_pool')
            switch p.prime_agent_pool
                case 'rcnn'
                    agent_pool = prime_agent_pool_rcnn( im_size, im_fname, p );
                case true
                    agent_pool = prime_agent_pool( im_size );
                otherwise
                    error(['don''t know what to do with p.prime_agent_pool : ' p.prime_agent_pool] );
            end
        else
            agent_pool = repmat( situate.agent_initialize(), 1, p.num_scouts );
            for ai = 1:length(agent_pool)
                agent_pool(ai) = situate.agent_initialize(p);
            end
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
            current_agent_snapshot_lean.workspace = [];
            current_agent_snapshot_lean.workspace.objects = [];
            current_agent_snapshot_lean.workspace.objects_total_support = [];
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
        [h, visualizer_run_status] = situate.visualize( [], im, p, d, workspace, [], agent_pool, records.agent_record, visualization_description );
        
        % see if an exit command came from the GUI
        if ~ishandle(h), visualizer_run_status = 'stop'; end
        if any( strcmp( visualizer_run_status, {'next_image','restart','stop'} ) )
            visualizer_return_status = visualizer_run_status;
            return;
        end
    end



    %% the iteration loop 
    
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
                    if nargin(p.situation_model.update) == 3
                        d(di).distribution = p.situation_model.update( d(end).distribution, d(di).interest, workspace );
                    else
                        d(di).distribution = p.situation_model.update( d(end).distribution, d(di).interest, workspace, im );
                    end
                    
                    % update interest priority
                    if any( strcmp( d(di).interest, workspace.labels ) )
                        if isstruct(p.situation_objects_urgency_post)
                            d(di).interest_priority = p.situation_objects_urgency_post.(d(di).interest);
                        elseif numel( p.situation_objects_urgency_post ) == 1
                            d(di).interest_priority = p.situation_objects_urgency_post;
                        else
                            error('trouble matching value to object');
                        end
                    end
                end

                % update external and total support for existing workspace objects
                for wi = 1:length(workspace.labels)

                    oi = strcmp( workspace.labels{wi},p.situation_objects);
                    
                    cur_box = workspace.boxes_r0rfc0cf(wi,:);
                    dist_index = strcmp( {d.interest}, workspace.labels{wi} );
                    [~,new_density] = p.situation_model.sample( d(dist_index).distribution, workspace.labels{wi}, 1, d(1).image_size, cur_box );
                    
                    % update external support
                    if length(p.external_support_function) == 1
                        workspace.external_support(wi) = p.external_support_function( new_density );
                    elseif length(p.external_support_function) == length(p.situation_objects) % we have different functions for each object type
                        workspace.external_support(wi) = p.external_support_function{oi}( new_density );
                    else
                        error('number of external support functions is incompatible with the number of situation objects');
                    end
                    
                    % update total support
                    if length(p.total_support_function) == 1
                        if nargin(p.total_support_function) == 2
                            workspace.total_support(wi) = p.total_support_function( workspace.internal_support(wi), workspace.external_support(wi) );
                        elseif nargin(p.total_support_function) == 3
                            workspace.total_support(wi) = p.total_support_function( workspace.internal_support(wi), workspace.external_support(wi), learned_models.classifier_model.AUROCs(oi) );
                        end
                    elseif length(p.total_support_function) == length(p.situation_objects)  % we have different functions for each object type
                        
                        workspace.total_support(wi) = p.total_support_function{oi}( workspace.internal_support(wi), workspace.external_support(wi) );
                    else
                        error('number of total support functions is incompatible with the number of situation objects');
                    end
                   
                end
                
            end
            
            % update situation grounding
                total_support_values = padarray_to( workspace.total_support, [1 length(p.situation_objects)] );
                cur_grounding = p.situation_grounding_function(total_support_values, iteration, p.num_iterations);
                workspace.situation_support = cur_grounding;
                workspace.iteration = iteration;

            % update temperature
                if isfield(p,'temperature')
                    % workspace.temperature = 1 - (iteration/p.num_iterations);
                    % workspace.temperature = 100;
                    workspace.temperature = p.temperature.update(iteration, p.num_iterations );
                end
            
            % update records

                % update record of scouting behavior
                records.workspace_record(iteration) = workspace_snapshot;
                current_agent_snapshot_lean = [];
                current_agent_snapshot_lean.type            = uint8( find(strcmp(current_agent_snapshot.type, agent_types ) ) );
                current_agent_snapshot_lean.interest        = uint8( find( strcmp( current_agent_snapshot.interest, p.situation_objects )));
                current_agent_snapshot_lean.box.r0rfc0cf    = current_agent_snapshot.box.r0rfc0cf;
                current_agent_snapshot_lean.support         = current_agent_snapshot.support;
                current_agent_snapshot_lean.workspace.objects = cellfun( @(x) find(strcmp(x,p.situation_objects)), workspace.labels );
                current_agent_snapshot_lean.workspace.total_support = workspace.total_support;
                records.agent_record(iteration)                     = current_agent_snapshot_lean;

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
                    visualization_description = {fname_no_path; ['iteration: ' num2str(iteration) '/' num2str(p.num_iterations)]; ['situation grounding: ' num2str(workspace.situation_support)] };
                    [h, visualizer_run_status] = situate.visualize( h, im, p, d, workspace, current_agent_snapshot, agent_pool, records.agent_record, visualization_description );

                    % see if an exit command came from the GUI
                    if ~ishandle(h), visualizer_run_status = 'stop'; end
                    if any( strcmp( visualizer_run_status, {'next_image','restart','stop'} ) )
                        visualizer_return_status = visualizer_run_status;
                        return; 
                    end 
                end

            % update agent pool

                % generate new agents based on the current agent's findings
                    new_agents = [];
                    if length(p.adjustment_model.activation_logic) == 1 
                        if p.adjustment_model.activation_logic(current_agent_snapshot,workspace,p)
                            new_agents = p.adjustment_model.apply( learned_models.adjustment_model, current_agent_snapshot, agent_pool, im );
                            agent_pool(agent_index).had_offspring = true;
                        end
                    elseif length(p.adjustment_model.activation_logic) == length(p.situation_objects)
                        if p.adjustment_model.activation_logic{ strcmp( current_agent_snapshot.interest, p.situation_objects ) }( current_agent_snapshot, workspace, p )
                            new_agents = p.adjustment_model.apply( learned_models.adjustment_model, current_agent_snapshot, agent_pool, im );
                            agent_pool(agent_index).had_offspring = true;
                        end
                    else
                        error('don''t know how to use this adjustment model activation function');
                    end
                    if ~isempty(new_agents)
                        agent_pool(end+1:end+length(new_agents)) = new_agents;
                    end

            % decide what to do with the evaluated agent (default is remove)
                post_eval_agent = p.scout_post_eval_function( agent_pool(agent_index) );
                if isempty(post_eval_agent)
                    agent_pool(agent_index) = [];
                else
                    agent_pool(agent_index) = post_eval_agent;
                end
                
            % make adjustments to the pool
                agent_pool = p.agent_pool_adjustment_function(agent_pool);

            % check stopping condition
                if p.stopping_condition( workspace, agent_pool, p )
                    break;
                end
                
                if nargout( p.stopping_condition ) > 1
                    [~,soft_stop] = p.stopping_condition( workspace, agent_pool, p );
                else
                    soft_stop = false;
                end
               
            % prep for the next iteration

                % check for degenerate object priority distribution
                %   if, for some reason, all of the priorities have been set to 0, then make them non-zero
                %   to avoid trying to sample from a zero density distribution
                if sum( [d.interest_priority] ) == 0
                    for di = 1:length(d)
                        dj = strcmp( workspace.labels{di}, {d.interest} );
                        d(dj).interest_priorty = p.situation_objects_urgency_pre.( d(dj).interest );
                    end
                end

                % refill the pool if we're continuing on and the pool is under size

                while ~soft_stop && sum( strcmp( 'scout', {agent_pool.type} ) ) < p.num_scouts
                    if isempty(agent_pool)
                        agent_pool = situate.agent_initialize(p); 
                    else
                        agent_pool(end+1) = situate.agent_initialize(p); 
                    end
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

            visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]; ['situation grounding: ' num2str(workspace.situation_support)] };
            [h, visualizer_run_status] = situate.visualize( h, im, p, d, workspace, [], agent_pool, records.agent_record, visualization_description );
            
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
    workspace.iteration = 0;
    
    if isfield(p,'temperature')
        workspace.temperature = p.temperature.initial;
    else
        workspace.temperature = -1;
    end
    
end



%% eval agent (general, just routing) 

function [agent_pool, d, workspace, object_was_added] = agent_evaluate( agent_pool, agent_index, im, label, d, p, workspace, learned_models )

    object_was_added = false;

    switch( agent_pool(agent_index).type )
        case 'scout'
            % sampling from d may change it, so we include it as an output
            [agent_pool, d] = agent_evaluate_scout( agent_pool, agent_index, p, d, im, label, learned_models );
        case 'reviewer'
            % reviewers do not modify the distributions
            [agent_pool] = agent_evaluate_reviewer( agent_pool, agent_index, p, workspace, d, learned_models );
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
    && strcmp(agent_pool(agent_index).type, 'scout' )

        % we'd like to just go ahead and make a reviewer for every scout, and eval it right away.
        % if it leads to a builder, we'll review that right away as well.

        % if we didn't generate a reviewer, let's just fake it and see what the total support would
        % have been anyway. Put one at the end of the pool
        if ~isequal(agent_pool(end).type, 'reviewer')
            agent_pool(end+1) = agent_pool(agent_index);
            agent_pool(end).type = 'reviewer';
            agent_pool(end).urgency = p.agent_urgency_defaults.reviewer;
        end
        
        assert( isequal( agent_pool(end).type, 'reviewer' ) );
        [agent_pool] = agent_evaluate_reviewer( agent_pool, length(agent_pool), p, workspace, d, learned_models );
        % this gets us external and total support values.
        % it might also add a builder to the end of the agent pool.
        agent_pool(agent_index).support.external = agent_pool(end).support.external;
        agent_pool(agent_index).support.total    = agent_pool(end).support.total;
        
        if isequal(agent_pool(end).type,'builder') && agent_pool(agent_index).support.internal >= p.thresholds.internal_support
            % the reviewer did spawn a builder, so evaluate it
            assert(isequal(agent_pool(end).type,'builder'));
            [workspace, agent_pool, object_was_added] = agent_evaluate_builder( agent_pool, length(agent_pool), workspace );
            % feed the total support back to the scout, since this bonkers
            % process is in effect and the addition to the workspace needs
            % to be justified with a final score. alternatively, we could
            % just turn scouts into reviewers and builders, rather than
            % adding them to the pool...
            agent_pool([end-1 end]) = [];
        elseif isequal(agent_pool(end).type,'builder')
            % the reviewer spawned a builder, but it really shouldn't have, so remove it and the
            % reviewer
            agent_pool([end-1 end]) = [];
        elseif isequal(agent_pool(end).type,'reviewer')
            % the reviewer failed to spawn a builder, so just fizzle
            agent_pool(end) = [];
        end
       
    end
    
end



%% eval scout 

function [agent_pool,d] = agent_evaluate_scout( agent_pool, agent_index, p, d, im, label, learned_models ) 
% function [agents_out, updated_distribution_structure ] = agents.evaluate_scout( agent_in, object_dist_model, image, classifier_struct )
%
% move inclusion of gt iou outside of agent.
% update the oracle to include loading up all of the label data as the training proceedure, and
% application will just be a lookup and compare
%
% agents out will start with the updated agent_in, then any reviewers that were spawned off from it


    % a few different behaviors depending on what the scout has baked in. 
    
    % if has an interest and a location already assigned, just eval
    % if has an interest and no location, sample a location and eval
    % if has no interest and no location, sample both and eval
    % if has no interest but does have a location, then this is a priming box, so we'll eval for
    %   each object type (at a computational discount, as the classifiers will all have the same
    %   expensive feature transform)
    
    cur_agent = agent_pool(agent_index); % for convenience. will be put back into the pool array after
    
    has_interest = ~isempty( cur_agent.interest );
    has_box      = ~isempty( cur_agent.box.r0rfc0cf );
    
    sample_interest = false;
    sample_box      = false;
    update_density  = false;

    if has_interest &&  has_box
        sample_interest = false;
        sample_box      = false;
        update_density  = true;
        
    elseif has_interest && ~has_box
        % sample box for that interest type
        
        sample_interest = false;
        sample_box      = true;
        update_density  = true;
        
    elseif ~has_interest && has_box
        % eval that box for each interest, then finalize the interest
        
        sample_interest = false;
        sample_box      = false;
        update_density  = false;
        
        cur_agent.interest = p.situation_objects;
        
    elseif ~has_interest && ~has_box
        % sample an interest, then sample a box based on that interest
        
        sample_interest = true;
        sample_box      = true;
        update_density  = true;
        
    end
    
    
    
    if sample_interest
        di = sample_1d( [d.interest_priority], 1 );
        cur_agent.interest = p.situation_objects{ di };
    end
    
    if sample_box
        di = find( strcmp( cur_agent.interest, p.situation_objects ) );
        if nargout(p.situation_model.sample) == 2
            % no change to dist struct
            [sampled_box_r0rfc0cf, sample_density] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)] ); 
        else
            % with change to dist struct
            [sampled_box_r0rfc0cf, sample_density, d(di).distribution] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)] ); 
        end
        
        % check the box, add to the agent
        [~, ...
         cur_agent.box.r0rfc0cf, ...
         cur_agent.box.xywh, ...
         cur_agent.box.xcycwh, ...
         cur_agent.box.aspect_ratio, ...
         cur_agent.box.area_ratio] = situate.fix_box( sampled_box_r0rfc0cf, 'r0rfc0cf', [size(im,1) size(im,2)] );
    end
    
    if update_density
        di = find(strcmp({d.interest},cur_agent.interest));
        [~, cur_agent.support.sample_densities] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)], agent_pool(agent_index).box.r0rfc0cf ); 
    end
    
    assert( isequal( cur_agent.type, 'scout' ) );
    assert( ~isempty( cur_agent.box.r0rfc0cf ) );
    assert( ~isempty( cur_agent.interest ) );

    % figure out the internal support
    
        if iscell(cur_agent.interest)
            
            % we need to eval for a included interests and pick one
            
            % because the apply function should keep track of being called with the same image and
            % box, it can keep the expensive feature transform as a persistent variable and avoid
            % recomputing it, meaning we're just adding classifications, not feature transforms
            
            classification_scores = zeros(1,length(cur_agent.interest));
            for oi = 1:length(cur_agent.interest)
                classification_scores(oi) = p.classifier.apply(  ...
                    learned_models.classifier_model, ...
                    cur_agent.interest{oi}, ...
                    im, ...
                    cur_agent.box.r0rfc0cf, ...
                    label);
            end
            [~,winning_oi] = max( classification_scores );
            classification_score = classification_scores(winning_oi);
            cur_agent.interest = cur_agent.interest{winning_oi};
            
            % now that we have an interest, we can eval the box density w/ respect to that interest
            di = find(strcmp({d.interest},cur_agent.interest));
            [~, cur_agent.support.sample_densities] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)], agent_pool(agent_index).box.r0rfc0cf ); 
        
        elseif isnan(cur_agent.support.internal) || isempty(cur_agent.support.internal)
        
            classification_score = p.classifier.apply(  ...
                learned_models.classifier_model, ...
                cur_agent.interest, ...
                im, ...
                cur_agent.box.r0rfc0cf, ...
                label);
            
        else
            
            classification_score = cur_agent.support.internal;
            
        end
    
        internal_support_adjustment = @(x) floor(x * 100)/100; % rounding to nearest .01 for consistency between display and internal behavior
        cur_agent.support.internal = internal_support_adjustment( classification_score );
    
    % figure out GROUND_TRUTH support
    % getting it for displaying progress during a run, or if we're using IOU-oracle as our eval method
    
        if ~isempty(label) && ismember( cur_agent.interest, label.labels_adjusted )
            relevant_label_ind = find(strcmp(cur_agent.interest,label.labels_adjusted),1,'first');
            ground_truth_box_xywh = label.boxes_xywh(relevant_label_ind,:);
            if ~isempty(cur_agent.box.xywh)
                cur_agent.support.GROUND_TRUTH = intersection_over_union( cur_agent.box.xywh, ground_truth_box_xywh, 'xywh' );
            else
                cur_agent.support.GROUND_TRUTH = intersection_over_union( cur_agent.box.r0rfc0cf, ground_truth_box_xywh, 'r0rfc0cf', 'xywh' );
            end
            cur_agent.GT_label_raw = label.labels_raw{relevant_label_ind};
        else
            cur_agent.support.GROUND_TRUTH = nan;
            cur_agent.GT_label_raw = '';
        end
        
    % upate the agent pool based on what we found
    
        % replace the agent in the agent pool
        agent_pool(agent_index) = cur_agent;
        
        % consider adding a reviewer to the pool
        if cur_agent.support.internal >= p.thresholds.internal_support
            agent_pool(end+1) = cur_agent;
            agent_pool(end).type = 'reviewer';
            agent_pool(end).urgency = p.agent_urgency_defaults.reviewer;
        end
       
end



%% eval reviewer 

function [agent_pool] = agent_evaluate_reviewer( agent_pool, agent_index, p, workspace, d, learned_models ) 
% function [ agents_out ] = agents.evaluate_reviewer( agent_in, object_dist_model )    


    % the reviewer checks to see how compatible a proposed object is with
    % our understanding of the relationships between objects. if the
    % porposal is sufficiently compatible, we send ut off to a builder.
    %
    % currently, there is no evaluation being made here, so the builder is
    % made for sure.
    
    cur_agent = agent_pool(agent_index);
    assert( isequal( cur_agent.type, 'reviewer' ) );
    
    if length(p.external_support_function) == 1
        cur_agent.support.external = p.external_support_function( agent_pool(agent_index).support.sample_densities ); 
    else
        obj_ind = strcmp(agent_pool(agent_index).interest,p.situation_objects);
        cur_agent.support.external = p.external_support_function{obj_ind}( agent_pool(agent_index).support.sample_densities ); 
    end
    
    oi = strcmp( p.situation_objects, cur_agent.interest );
    
    switch class( p.total_support_function )
        case 'function_handle'
            if nargin(p.total_support_function) == 2
                cur_agent.support.total    = p.total_support_function( cur_agent.support.internal, cur_agent.support.external );
            elseif nargin(p.total_support_function) == 3
                cur_agent.support.total    = p.total_support_function( cur_agent.support.internal, cur_agent.support.external, learned_models.classifier_model.AUROCs(oi) );
            end
        case 'cell'
            % assume different functions per object type
            cur_agent.support.total    = p.total_support_function{oi}( cur_agent.support.internal, cur_agent.support.external );
        otherwise
            error('dunno what to do with this');
    end
    
    agent_pool(agent_index) = cur_agent;

    % consider adding a builder to the pool
    if cur_agent.support.total >= p.thresholds.total_support_provisional || cur_agent.support.total >= p.thresholds.total_support_final
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


