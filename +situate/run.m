


function [ workspace, records, visualizer_return_status, state, alternative_workspaces ] = run( im_fname, running_params, learned_models, state, num_iterations )
% [ workspace, records, visualizer_return_status, [state], [alternative_workspaces] ] = run( im_fname, running_params, learned_models, [state], [num_iterations_to_run] );

    

    %% initialization 
    
    situate.setup();
        
    if isfield(running_params,'use_monte') && running_params.use_monte
        [ workspace, records, all_workspaces ] = situate.run_monte( im_fname, running_params, learned_models );
        visualizer_return_status = [];
        state = [];
        alternative_workspaces = all_workspaces;
        return;
    end
    
    % initialize
    if ~exist('state','var') || isempty(state)
        state = [];
        state.im = imread( im_fname );
        if mean(state.im(:)) < 1, state.im = 255 * state.im; end
        state.label = situate.labl_load( im_fname, running_params ); % may return empty array if label file wasn't found
        state.im_size = [size(state.im,1), size(state.im,2)];
        
        state.workspace = situate.workspace_initialize(running_params,state.im_size);
    
        % initialize distributions struct
        [state.dist_structs,state.dist_struct_joint] = situate.distribution_struct_initialize(running_params,state.im,learned_models,state.workspace);
        state.dist_structs(end+1) = state.dist_struct_joint;
    
        % initialize agent pool
        state.agent_pool = running_params.agent_pool_initialization_function( running_params, state.im, im_fname, learned_models );
        
        % initialize record keeping 
        state.records = situate.records_initialize(running_params,state.agent_pool);
        
    end
    
    if ~exist('num_iterations','var') || isempty(num_iterations)
        num_iterations = running_params.num_iterations;
    end
        
       
        
    % initialize the visualization
    
        global visualizer_run_status;
        visualizer_run_status = 'unstarted'; % this does need to be here. it is looked at from within the visualizer
        if running_params.viz_options.use_visualizer
        
            [~,visualization_description] = fileparts(im_fname);
            [viz_handle, visualizer_run_status] = situate.visualize( [], state.im, running_params, state.dist_structs, state.workspace, [], state.agent_pool, state.records.agent_record, visualization_description );

            % see if an exit command came from the GUI (or if it was closed)
            if ~ishandle(viz_handle), visualizer_run_status = 'stop'; end
            if any( strcmp( visualizer_run_status, {'next_image','restart','stop'} ) )
                visualizer_return_status = visualizer_run_status;
                return;
            end
        end



    %% the main iteration loop 
    
    delayed_break = false;
    
    for iteration = 1:num_iterations

        % sample and eval an agent
        % update distribution structures
        % update situation score
        % update state.records
        % update visualization
        % check stopping condition
        % prep for next iteration

        % sample and evaluate an agent from the pool
            % note: state.dist_structs is an output of evaluating agents because we might
            % have sampling without replacement or a record of sampled locations.
            % these changes would be included in state.dist_structs
            agent_index = sample_1d( [state.agent_pool.urgency], 1 );
            
            workspace_snapshot = state.workspace;
            [state.agent_pool,state.dist_structs,state.workspace] = situate.agent.evaluate( state.agent_pool, agent_index, state.im, state.label, state.dist_structs, running_params, state.workspace, learned_models );
            current_agent_snapshot = state.agent_pool(agent_index);
        
        % update state.dist_structs and support for existing state.workspace objects
            workspace_changed = ~isequal(state.workspace,workspace_snapshot);
            if workspace_changed

                % then update each per-object distribution struct
                for oi = 1:length( running_params.situation_objects ) % don't go to length of distributions_struct, as last entry is the joint

                    % condition distribution
                    state.dist_structs(oi).distribution = running_params.situation_model.update( state.dist_struct_joint.distribution, state.dist_structs(oi).interest, state.workspace, state.im );

                    % update priority for that object distribution
                    if ismember( state.dist_structs(oi).interest, state.workspace.labels )
                        state.dist_structs(oi).interest_priority = running_params.situation_objects_urgency_post(oi);
                    end

                end

                % update external and total support for existing state.workspace objects
                %   note: learned_models added for classifier quality-based weighting of internal and external support
                state.workspace = situate.workspace_update_support( state.workspace, running_params, state.dist_structs, learned_models );
               
            end

        % update situation support score iteration count
            total_support_values = padarray_to( state.workspace.total_support, [1 length(running_params.situation_objects)] );
            state.workspace.situation_support = running_params.situation_grounding_function(total_support_values, iteration, running_params.num_iterations);
            
            state.workspace.total_iterations = state.workspace.total_iterations + 1;

            if isfield(running_params,'temperature')
                state.workspace.temperature = running_params.temperature.update(state.workspace, state.workspace.total_iterations, running_params.num_iterations );
            end

        % update records
            state.records = situate.records_update( state.records, iteration, workspace_snapshot, running_params, current_agent_snapshot );
       
        % update visualization
            if running_params.viz_options.use_visualizer ...
            && ( running_params.viz_options.on_iteration_mod ~= 0 && mod(iteration, running_params.viz_options.on_iteration_mod)==0 ) ...
            || ( running_params.viz_options.on_workspace_change && workspace_changed )
    
                % try to reconcile with a different interpretation of the label
                if ~isempty(label)
                    [state.workspace,label_used] = situate.workspace_score( state.workspace, label, running_params ); % might change the label struct, but will not change the state.workspace, just the gt score for the visualizer
                    if ~isempty(label_used), label = label_used; end
                end
                
                [~,fname_no_path] = fileparts(im_fname); 
                visualization_description = {fname_no_path; ['iteration: ' num2str(iteration) '/' num2str(running_params.num_iterations)]; ['situation grounding: ' num2str(state.workspace.situation_support)] };
                [viz_handle, visualizer_run_status] = situate.visualize( viz_handle, state.im, running_params, state.dist_structs, state.workspace, current_agent_snapshot, state.agent_pool, state.records.agent_record, visualization_description );

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
            state.agent_pool = situate.agent.pool_update( state.agent_pool, agent_index, running_params, state.workspace, current_agent_snapshot, state.im, learned_models );

        % check stopping condition
            [hard_stop, soft_stop] = running_params.stopping_condition( state.workspace, state.agent_pool, running_params );
            if hard_stop
                break;
            end
        
        % prep for the next iteration

            % check for degenerate object priority distribution
            %   if, for some reason, all of the priorities have been set to 0, then make them non-zero
            %   to avoid trying to sample from a zero density distribution
            if sum( [state.dist_structs.interest_priority] ) == 0
                for oi = 1:length(state.dist_structs)
                    if isstruct( running_params.situation_objects_urgency_pre )
                        dj = strcmp( state.workspace.labels{oi}, {state.dist_structs.interest} );
                        state.dist_structs(dj).interest_priorty = running_params.situation_objects_urgency_pre.( state.dist_structs(dj).interest );
                    elseif numel(running_params.situation_objects_urgency_pre) == 1
                        state.dist_structs(dj).interest_priorty = running_params.situation_objects_urgency_pre(1);
                    elseif numel(running_params.situation_objects_urgency_pre) == numel(running_params.situation_objects)
                        state.dist_structs(dj).interest_priorty = running_params.situation_objects_urgency_pre(oi);
                    else
                        error('can''t match prior to object type');
                    end
                end
            end

            % refill the pool if we're continuing on and the pool is under size
                while ~soft_stop && sum( strcmp( 'scout', {state.agent_pool.type} ) ) < running_params.num_scouts
                    if isempty(state.agent_pool)
                        state.agent_pool = situate.agent.initialize(running_params); 
                    else
                        state.agent_pool(end+1) = situate.agent.initialize(running_params); 
                    end
                end
                
                
        if delayed_break
            break;
        end
            
    end



    %% final recording of results and visualizer updating 
    
        % update state.records
        state.records.agent_pool      = state.agent_pool;
        state.records.workspace_final = state.workspace;
        
        workspace = state.workspace;
        records = state.records;
        alternative_workspaces = [];

        
        % update visualization
        if running_params.viz_options.use_visualizer && running_params.viz_options.on_end
            
            if ~exist('viz_handle','var'), viz_handle = []; end
            [~,fname_no_path] = fileparts(im_fname);

            visualization_description = {fname_no_path; [num2str(iteration) '/' num2str(running_params.num_iterations)]; ['situation grounding: ' num2str(state.workspace.situation_support)] };
            [viz_handle, visualizer_run_status] = situate.visualize( viz_handle, state.im, running_params, state.dist_structs, state.workspace, [], state.agent_pool, state.records.agent_record, visualization_description );
            
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



