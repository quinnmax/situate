


function [ workspace, records, visualizer_return_status ] = main_loop( im_fname, p, learned_models )
% [ workspace, records, visualizer_return_status ] = main_loop( im_fname, p, learned_models );



    %% initialization 
        
    % load an image, label
        label = situate.labl_load( im_fname, p );
        im = imread( im_fname );
        im_size = [size(im,1), size(im,2)];
    
    % initialize workspace
        
        workspace = situate.workspace_initialize(p,im_size);
        
    % initialize distributions struct
    
        [dist_structs,dist_struct_joint] = situate.distribution_struct_initialize(p,im,learned_models,workspace);
    
    % initialize agent pool
    
        agent_pool = agent.pool_initialize_default( p, im, im_fname );
        
    % initialize record keeping 
    
        records = situate.records_initialize(p,agent_pool);
        
    % initialize the visualization
        global visualizer_run_status;
        visualizer_run_status = 'unstarted'; % this does need to be here. it is looked at from within the visualizer
        if p.use_visualizer
        
            [~,visualization_description] = fileparts(im_fname);
            [viz_handle, visualizer_run_status] = situate.visualize( [], im, p, dist_structs, workspace, [], agent_pool, records.agent_record, visualization_description );

            % see if an exit command came from the GUI (or if it was closed)
            if ~ishandle(viz_handle), visualizer_run_status = 'stop'; end
            if any( strcmp( visualizer_run_status, {'next_image','restart','stop'} ) )
                visualizer_return_status = visualizer_run_status;
                return;
            end
        end



    %% the main iteration loop 
    
    for iteration = 1:p.num_iterations

        % sample and eval an agent
        % update distribution structures
        % update situation score
        % update records
        % update visualization
        % check stopping condition
        % prep for next iteration

        % sample and evaluate an agent from the pool
            % note: dist_structs is an output of evaluating agents because we might
            % have sampling without replacement or a record of sampled locations.
            % these changes would be included in dist_structs
            agent_index        = sample_1d( [agent_pool.urgency], 1 );
            workspace_snapshot = workspace;
            [agent_pool,dist_structs,workspace] = agent.evaluate( agent_pool, agent_index, im, label, dist_structs, p, workspace, learned_models );
            current_agent_snapshot              = agent_pool(agent_index);

        % update dist_structs and support for existing workspace objects
            workspace_changed = ~isequal(workspace,workspace_snapshot);
            if workspace_changed

                % then update each per-object distribution struct
                for oi = 1:length( p.situation_objects ) % don't go to length of distributions_struct, as last entry is the joint

                    % condition distribution
                    dist_structs(oi).distribution = p.situation_model.update( dist_struct_joint.distribution, dist_structs(oi).interest, workspace, im );

                    % update priority for that object distribution
                    if ismember( dist_structs(oi).interest, workspace.labels )
                        dist_structs(oi).interest_priority = p.situation_objects_urgency_post(oi);
                    end

                end

                % update external and total support for existing workspace objects
                %   note: learned_models added for classifier quality-based weighting of internal and external support
                workspace = situate.workspace_update_support( workspace, p, dist_structs, learned_models );

            end

        % update situation support score and temperature (not used much currently)
            total_support_values = padarray_to( workspace.total_support, [1 length(p.situation_objects)] );
            workspace.situation_support = p.situation_grounding_function(total_support_values, iteration, p.num_iterations);
            workspace.iteration = iteration;

            if isfield(p,'temperature')
                workspace.temperature = p.temperature.update(workspace, iteration, p.num_iterations );
            end

        % update records
            records = situate.records_update( records, iteration, workspace_snapshot, p, current_agent_snapshot );

        % update visualization
            if p.use_visualizer ...
            && ( p.viz_options.on_iteration_mod ~= 0 && mod(iteration, p.viz_options.on_iteration_mod)==0 ) ...
            || ( p.viz_options.on_workspace_change && workspace_changed )

                [~,fname_no_path] = fileparts(im_fname); 
                visualization_description = {fname_no_path; ['iteration: ' num2str(iteration) '/' num2str(p.num_iterations)]; ['situation grounding: ' num2str(workspace.situation_support)] };
                [viz_handle, visualizer_run_status] = situate.visualize( viz_handle, im, p, dist_structs, workspace, current_agent_snapshot, agent_pool, records.agent_record, visualization_description );

                % see if an exit command came from the GUI
                if ~ishandle(viz_handle), visualizer_run_status = 'stop'; end
                if ismember( visualizer_run_status, {'next_image','restart','stop'} )
                    visualizer_return_status = visualizer_run_status;
                    return; 
                end 

            end

        % update agent pool
            % add new agents based on findings
            % remove (or reinsert) evaluated agent
            % apply user-defined pool adjustments (like removing low priority agents)
            agent_pool = agent.pool_update( agent_pool, agent_index, p, workspace, current_agent_snapshot, im, learned_models );

        % check stopping condition
            [hard_stop, soft_stop] = p.stopping_condition( workspace, agent_pool, p );
            if hard_stop
                break;
            end
        
        % prep for the next iteration

            % check for degenerate object priority distribution
            %   if, for some reason, all of the priorities have been set to 0, then make them non-zero
            %   to avoid trying to sample from a zero density distribution
            if sum( [dist_structs.interest_priority] ) == 0
                for oi = 1:length(dist_structs)
                    if isstruct( p.situation_objects_urgency_pre )
                        dj = strcmp( workspace.labels{oi}, {dist_structs.interest} );
                        dist_structs(dj).interest_priorty = p.situation_objects_urgency_pre.( dist_structs(dj).interest );
                    elseif numel(p.situation_objects_urgency_pre) == 1
                        dist_structs(dj).interest_priorty = p.situation_objects_urgency_pre(1);
                    elseif numel(p.situation_objects_urgency_pre) == numel(p.situation_objects)
                        dist_structs(dj).interest_priorty = p.situation_objects_urgency_pre(oi);
                    else
                        error('can''t match prior to object type');
                    end
                end
            end

            % refill the pool if we're continuing on and the pool is under size
                while ~soft_stop && sum( strcmp( 'scout', {agent_pool.type} ) ) < p.num_scouts
                    if isempty(agent_pool)
                        agent_pool = agent.initialize(p); 
                    else
                        agent_pool(end+1) = agent.initialize(p); 
                    end
                end
            
    end



    %% final recording of results and visualizer updating 
    
        % update records
        records.agent_pool      = agent_pool;
        records.workspace_final = workspace;
        
        % update visualization
        if p.use_visualizer && p.viz_options.on_end
            if ~exist('viz_handle','var'), viz_handle = []; end
            [~,fname_no_path] = fileparts(im_fname);

            visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(p.num_iterations)]; ['situation grounding: ' num2str(workspace.situation_support)] };
            [viz_handle, visualizer_run_status] = situate.visualize( viz_handle, im, p, dist_structs, workspace, [], agent_pool, records.agent_record, visualization_description );
            
            % interpret closing the window as 'no thank you'
            if ~ishandle(viz_handle)
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



