function experiment_handler_parallel( experiment_struct, situation_struct, situate_params_array )

% experiment_handler_parallel( experiment_struct, situation_struct, situate_params_array );



    %% tidy up parameterizations 
      
        situate_params_array = situate.parameters_struct_new_to_old( experiment_struct, situation_struct, situate_params_array );
        assert( all( situate.parameters_struct_validate( situate_params_array ) ) );
        num_parameterizations = numel(situate_params_array);
        if (num_parameterizations == 1 && isempty( situate_params_array.seed_test )) || any(isempty([situate_params_array.seed_test]))
            rng('shuffle');
            cur_rng = rng();
            for parameters_ind = 1:num_parameterizations
                situate_params_array(parameters_ind).seed_test = cur_rng.Seed;
            end
            display(['testing seed was empty, set to: ' num2str(cur_rng.Seed)]);
        end
        
        
        
    %% generate training/testing sets 
    
        [data_split_struct, fold_inds, experiment_settings_out] = situate.experiment_process_data_splits( experiment_struct.experiment_settings );
        experiment_struct.experiment_settings = experiment_settings_out;
        
        
        
    %% run through it all 

    for fii = 1:length(fold_inds)
    
        fi = fold_inds(fii);

        learned_models = []; % contains everything we gather from training data, so is reset at the start of each fold
        learned_models_training_functions = []; % used to see if we can skip on re-training models

        fnames_lb_train_vision    = cellfun( @(x) fullfile(experiment_struct.experiment_settings.vision_model.directory_train,    x), data_split_struct.vision(fi).fnames_lb_train,    'UniformOutput', false );
        fnames_lb_train_situation = cellfun( @(x) fullfile(experiment_struct.experiment_settings.situation_model.directory_train, x), data_split_struct.situation(fi).fnames_lb_train, 'UniformOutput', false );
        fnames_im_test            = cellfun( @(x) fullfile(experiment_struct.experiment_settings.directory_test,                  x), data_split_struct.vision(fi).fnames_im_test,     'UniformOutput', false );
        
        if isempty( experiment_struct.experiment_settings.max_testing_images )
            experiment_struct.experiment_settings.max_testing_images = length(fnames_im_test);
        end
        num_images = experiment_struct.experiment_settings.max_testing_images;
        
        [~, fnames_fail, exceptions, failed_inds] = situate.labl_validate( fnames_lb_train_vision, situation_struct );
        if ~isempty(fnames_fail)
            error('some label files failed validation');
        end
        
        [~, fnames_fail, exceptions, failed_inds] = situate.labl_validate( fnames_lb_train_situation, situation_struct );
        if ~isempty(fnames_fail)
            error('some label files failed validation');
        end
        
        % loop through experimental settings
        for parameters_ind = 1:length(situate_params_array)

            cur_parameterization = situate_params_array(parameters_ind);
            rng( cur_parameterization.seed_test );
            
            cur_param_desc = fileparts_mq(cur_parameterization.description,'name');
            save_fname = fullfile(experiment_struct.results_directory, [cur_param_desc '_fold_' num2str(fi,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);

            % load or learn the vision models
            if ~isfield( learned_models, 'classifier_model') ...
            || ~isequal( learned_models_training_functions.classifier, cur_parameterization.classifier.train )
                learned_models_training_functions.classifier = cur_parameterization.classifier.train;
                learned_models.classifier_model = ...
                    cur_parameterization.classifier.train( ...
                        cur_parameterization, ...
                        fnames_lb_train_vision, ...
                        cur_parameterization.classifier.directory );
            end
            
            % load or learn the situation model
            if ~isfield( learned_models, 'situation_model') ...
            || ~isequal( learned_models_training_functions.situation, cur_parameterization.situation_model.learn )
                learned_models_training_functions.situation = cur_parameterization.situation_model.learn;
                learned_models.situation_model = ...
                    cur_parameterization.situation_model.learn( ...
                        cur_parameterization, ...
                        fnames_lb_train_situation );
            end

            % load or learn the adjustment model
            if ~isfield( learned_models, 'adjustment_model') ...
            || ~isequal( learned_models_training_functions.adjustment, cur_parameterization.adjustment_model.train )
                learned_models_training_functions.adjustment = cur_parameterization.adjustment_model.train;
                learned_models.adjustment_model = ...
                    cur_parameterization.adjustment_model.train( ...
                        cur_parameterization, ...
                        fnames_lb_train_vision, ...
                        cur_parameterization.adjustment_model.directory);
            end

            progress( 0, length(fnames_im_test),cur_parameterization.description); 

            % loop through images
            workspaces_final       = cell(1,length(fnames_im_test));
            agent_records          = cell(1,length(fnames_im_test));
            alternative_workspaces = cell(1,length(fnames_im_test));

            if isfield(experiment_struct.experiment_settings, 'starting_image_ind') && ~isempty(experiment_struct.experiment_settings.starting_image_ind)
                im_ind_start = experiment_struct.experiment_settings.starting_image_ind;
            else
                im_ind_start = 1;
            end
          
            inds_per_save = 200;
            ind_range_0s = im_ind_start:inds_per_save:experiment_struct.experiment_settings.max_testing_images;
            ind_range_fs = min( (ind_range_0s-1)+inds_per_save, experiment_struct.experiment_settings.max_testing_images);
            
            for range_ind = 1:numel(ind_range_0s)
                
                fprintf(['%s         %s       %s       %s        IOUs: [ %s] \n'], ...
                        ['params' repmat(' ',1,numel(cur_parameterization.description)-6)], ...
                        'image ind', ...
                        'steps', ...
                        'time(s)', ...
                        sprintf('%-12s',situation_struct.situation_objects{:}) );
                    
                parfor cur_image_ind = ind_range_0s(range_ind) : ind_range_fs(range_ind)

                    % run on the current image
                    cur_fname_im = fnames_im_test{cur_image_ind};

                    tic;
                    [ ~, run_data_cur,~,~,alternative_workspaces_cur ] = situate.run( cur_fname_im, cur_parameterization, learned_models );
                    
                    % try to reconcile workspace with GT boxes
                    cur_fname_lb = [fileparts_mq(cur_fname_im,'path/name') '.json'];
                    if exist(cur_fname_lb,'file')
                        reconciled_workspace = situate.workspace_score(run_data_cur.workspace_final, cur_fname_lb, cur_parameterization );
                    else
                        reconciled_workspace = run_data_cur.workspace_final;
                    end
                    labels_missed = setdiff(cur_parameterization.situation_objects,run_data_cur.workspace_final.labels);
                    labels_temp = [run_data_cur.workspace_final.labels labels_missed];
                    GT_IOUs = [reconciled_workspace.GT_IOU nan(1,length(labels_missed))];
                    [~,sort_order_2] = sort( labels_temp );
                    [~,sort_order_1] = sort( cur_parameterization.situation_objects);
                    IOUs_of_last_run = sprintf(repmat('%1.4f         ',1,length(GT_IOUs)),GT_IOUs(sort_order_2(sort_order_1)));
    
                    % display update to console
                    if numel(cur_parameterization.description) > 32
                        temp_desc = ['...' cur_parameterization.description(end-28:end)];
                    else
                        temp_desc = cur_parameterization.description;
                    end
                    fprintf('%-28s       %3d /%4d        %4d        %6.2f        IOUs: [ %s] \n', ...
                        temp_desc, ...
                        cur_image_ind, ...
                        num_images, ...
                        reconciled_workspace.total_iterations, ...
                        toc, ...
                        IOUs_of_last_run );
                    
                    % store results
                    workspaces_final{cur_image_ind} = run_data_cur.workspace_final;
                    alternative_workspaces{cur_image_ind} = alternative_workspaces_cur;
                    agent_records{cur_image_ind}    = run_data_cur.agent_record;

                end


                % save off results, each condition and fold pair gets a file

                results_struct = [];
                results_struct.p_condition               = cur_parameterization;
                results_struct.workspaces_final          = workspaces_final;
                results_struct.workspaces_alternatives   = alternative_workspaces;
                results_struct.agent_records             = agent_records;
                results_struct.fnames_lb_train_vision    = fnames_lb_train_vision;
                results_struct.fnames_lb_train_situation = fnames_lb_train_situation;
                results_struct.fnames_im_test            = fnames_im_test;

                save(save_fname, '-v7', '-struct','results_struct');
                fprintf('saved to:\n    %s\n', save_fname);

            end
            
        end

    end

    
    
end


