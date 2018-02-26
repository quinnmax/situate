function experiment_handler_parrallel( experiment_struct, situation_struct, situate_params_array )

% experiment_handler_parrallel( experiment_struct, situation_struct, situate_params_array );


    
    % make parameterization structs compatible with the old struct that had everything in one pile
        situate_params_array = situate.parameters_struct_new_to_old( experiment_struct, situation_struct, situate_params_array );
    
    %% generate training/testing sets
    
        if isequal( experiment_struct.experiment_settings.directory_train, experiment_struct.experiment_settings.directory_test ) && ...
           ~isempty( experiment_struct.experiment_settings.training_testing_split_directory )
            % if the train and test directories are the same, and the split files are provided, use
            % them
            data_split_struct = situate.data_load_splits_from_directory( experiment_struct.experiment_settings.training_testing_split_directory );
        elseif isequal( experiment_struct.experiment_settings.directory_train, experiment_struct.experiment_settings.directory_test )
            % if the train and test are equal and no split is provided,
            % generate a split
            data_path = experiment_struct.experiment_settings.directory_train;
            output_directory = fullfile('data_splits/', [situation_struct.desc '_' datestr(now,'YYYY.MM.DD.hh.mm.ss')]);
            num_folds = experiment_struct.experiment_settings.num_folds;
            max_images_per_fold = experiment_struct.experiment_settings.max_testing_images;
            if ~isempty(max_images_per_fold)
                data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'test_im_per_fold', max_images_per_fold, 'output_directory', output_directory );
            else
                data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'output_directory', output_directory );
            end
        else
            % use everything in training/testing directories
            data_split_struct = [];
            data_split_struct.fnames_lb_train = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_train, '*.json']), 'UniformOutput', false );
            data_split_struct.fnames_lb_test  = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_test,  '*.json']), 'UniformOutput', false );
            data_split_struct.fnames_im_train = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_train, '*.jpg']),  'UniformOutput', false );
            data_split_struct.fnames_im_test  = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_test,  '*.jpg']),  'UniformOutput', false );
        end
        
        if ~isfield(experiment_struct.experiment_settings,'specific_folds') || isempty(experiment_struct.experiment_settings.specific_folds)
            fold_inds = 1:experiment_struct.experiment_settings.num_folds;
        else
            fold_inds = experiment_struct.experiment_settings.specific_folds;
        end
        
        % if we've specified a lower number of testing images, enforce that here
        if ~isempty(experiment_struct.experiment_settings.max_testing_images)
            for fi = experiment_struct.experiment_settings.num_folds
                if experiment_struct.experiment_settings.max_testing_images < length(data_split_struct(fi).fnames_lb_test)
                    data_split_struct(fi).fnames_lb_test = data_split_struct(fi).fnames_lb_test(1 : experiment_struct.experiment_settings.max_testing_images );
                    data_split_struct(fi).fnames_im_test = data_split_struct(fi).fnames_im_test(1 : experiment_struct.experiment_settings.max_testing_images );
                end
            end
        end
    
    % make sure all files exist in the specified directories
    %   note: turns out this is fine if the fnames_lb_test set is empty (as long as it's still a cell)
    
        for fi = experiment_struct.experiment_settings.num_folds
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_train, x), 'file' ), data_split_struct(fi).fnames_lb_train) ) );
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_train, x), 'file' ), data_split_struct(fi).fnames_im_train) ) );
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_test,  x), 'file' ), data_split_struct(fi).fnames_lb_test)  ) );
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_test,  x), 'file' ), data_split_struct(fi).fnames_im_test)  ) );
        end

    % make sure all training labels and images have their partners
    
        for fi = experiment_struct.experiment_settings.num_folds
            assert( isequal( ...
                sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct(fi).fnames_lb_train, 'UniformOutput', false )), ...
                sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct(fi).fnames_im_train, 'UniformOutput', false )) ) );
        end
            
        
        
%% run through folds

 for fi = experiment_struct.experiment_settings.num_folds
     
        learned_models = []; % contains everything we gather from training data, so is reset at the start of each fold
        learned_models_training_functions = []; % used to see if we can skip on re-training models

        fnames_lb_train = cellfun( @(x) fullfile(experiment_struct.experiment_settings.directory_train, x), data_split_struct(fi).fnames_lb_train, 'UniformOutput', false );
        fnames_im_test  = cellfun( @(x) fullfile(experiment_struct.experiment_settings.directory_test,  x), data_split_struct(fi).fnames_im_test,  'UniformOutput', false );
            
        [~, fnames_fail, exceptions, failed_inds] = labl_validate( fnames_lb_train, situation_struct );
        if ~isempty(fnames_fail)
            error('some label files failed validation');
        end
            
        % loop through experimental settings
        
            for parameters_ind = 1:length(situate_params_array)

                cur_parameterization = situate_params_array(parameters_ind);
                rng( cur_parameterization.seed_test );

                % load or learn the situation model
                if ~isfield( learned_models, 'situation_model') ...
                || ~isequal( learned_models_training_functions.situation, cur_parameterization.situation_model.learn )
                    learned_models_training_functions.situation = cur_parameterization.situation_model.learn;
                    learned_models.situation_model = ...
                        cur_parameterization.situation_model.learn( ...
                            cur_parameterization, ...
                            fnames_lb_train );
                end

                % load or learn the classification models
                if ~isfield( learned_models, 'classifier_model') ...
                || ~isequal( learned_models_training_functions.classifier, cur_parameterization.classifier.train )
                    learned_models_training_functions.classifier = cur_parameterization.classifier.train;
                    learned_models.classifier_model = ...
                        cur_parameterization.classifier.train( ...
                            cur_parameterization, ...
                            fnames_lb_train, ...
                            cur_parameterization.classifier.directory );
                end

                % load or learn the adjustment model
                if ~isfield(learned_models, 'adjustment_model') ...
                || ~isequal( learned_models_training_functions.adjustment, cur_parameterization.adjustment_model.train )
                    learned_models_training_functions.adjustment = cur_parameterization.adjustment_model.train;
                    learned_models.adjustment_model = ...
                        cur_parameterization.adjustment_model.train( ...
                            cur_parameterization, ...
                            fnames_lb_train, ...
                            cur_parameterization.adjustment_model.directory);
                end
                
                progress( 0, length(fnames_im_test),cur_parameterization.description); 

                % loop through images
                workspaces_final    = cell(1,length(fnames_im_test));
                agent_records       = cell(1,length(fnames_im_test));
                
                parfor cur_image_ind = 1:experiment_struct.experiment_settings.max_testing_images
                    
                    % run on the current image
                    cur_fname_im = fnames_im_test{cur_image_ind};

                    tic;
                    [ ~, run_data_cur ] = situate.main_loop( cur_fname_im, cur_parameterization, learned_models );

                    % store results
                    workspaces_final{cur_image_ind} = run_data_cur.workspace_final;
                    agent_records{cur_image_ind}    = run_data_cur.agent_record;

                    % display an update in the console
                    num_iterations_run = sum(~eq(0,[run_data_cur.agent_record.interest]));
                    labels_missed = setdiff(cur_parameterization.situation_objects,run_data_cur.workspace_final.labels);
                    labels_temp = [run_data_cur.workspace_final.labels labels_missed];
                    GT_IOUs = [run_data_cur.workspace_final.GT_IOU nan(1,length(labels_missed))];
                    [~,sort_order] = sort( labels_temp );
                    IOUs_of_last_run = num2str(GT_IOUs(sort_order));
                    fprintf('%s, %3d / %d, %4d steps, %6.2fs,  IOUs: [%s] \n', cur_parameterization.description, cur_image_ind, length(fnames_im_test), num_iterations_run, toc, IOUs_of_last_run );

                end

                % save off results every condition and fold
                %   current fold and 
                %   experimental condition
                save_fname = fullfile(experiment_struct.results_directory, [cur_parameterization.description '_fold_' num2str(fi,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                
                p_condition = cur_parameterization;
                save(save_fname, '-v7', ...
                'p_condition', ...
                'workspaces_final', ...
                'agent_records', ...
                'fnames_lb_train', ...
                'fnames_im_test' );
                
                display(['saved to ' save_fname]);
                    
            end
            
end

       
