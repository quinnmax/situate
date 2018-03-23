function experiment_handler( experiment_struct, situation_struct, situate_params_array )

% experiment_handler( experiment_struct, situation_struct, situate_params_array );



    % make parameterization structs compatible with the old struct that had everything in one pile
        situate_params_array = situate.parameters_struct_new_to_old( experiment_struct, situation_struct, situate_params_array );
        assert( situate.parameters_struct_validate( situate_params_array ) );
        if isempty( situate_params_array.seed_test )
            rng('shuffle');
            curr_rng = rng();
            for parameters_ind = 1:length(situate_params_array)
                situate_params_array(parameters_ind).seed_test = curr_rng.Seed;
            end
            display(['testing seed was empty, set to: ' num2str(situate_params_array.seed_test)]);
        end
        
        
        
    %% generate training/testing sets
    
        train_test_dirs_match   = isequal(  experiment_struct.experiment_settings.directory_train, experiment_struct.experiment_settings.directory_test );
        if isempty( experiment_struct.experiment_settings.training_testing_split_directory )
            have_training_split_dir = false;
        else
            if exist( experiment_struct.experiment_settings.training_testing_split_directory , 'dir' )
                have_training_split_dir = true;
            elseif exist( fullfile( 'data_splits', experiment_struct.experiment_settings.training_testing_split_directory), 'dir' )
                experiment_struct.experiment_settings.training_testing_split_directory = fullfile( 'data_splits', experiment_struct.experiment_settings.training_testing_split_directory);
                have_training_split_dir = true;
            else
                have_training_split_dir = false;
            end
        end
               
        
        
    
        if train_test_dirs_match && have_training_split_dir
            % load from saved splits
            data_split_struct = situate.data_load_splits_from_directory( experiment_struct.experiment_settings.training_testing_split_directory );
            display(['loaded training splits from: ' experiment_struct.experiment_settings.training_testing_split_directory]);
        end
        
        if train_test_dirs_match && ~have_training_split_dir
            % make new splits save them off
            data_path = experiment_struct.experiment_settings.directory_train;
            output_directory = fullfile('data_splits/', [situation_struct.desc '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
            num_folds = experiment_struct.experiment_settings.num_folds;
            max_images_per_fold = experiment_struct.experiment_settings.max_testing_images;
            if ~isempty(max_images_per_fold)
                data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'test_im_per_fold', max_images_per_fold, 'output_directory', output_directory );
            else
                data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'output_directory', output_directory );
            end
        end
        
        if ~train_test_dirs_match && ~have_training_split_dir
            % use everything in directories
            disp('using all images from training / testing directories');
            data_split_struct = [];
            data_split_struct.fnames_lb_train = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_train, '*.json']), 'UniformOutput', false );
            data_split_struct.fnames_lb_test  = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_test,  '*.json']), 'UniformOutput', false );
            data_split_struct.fnames_im_train = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_train, '*.jpg']),  'UniformOutput', false );
            data_split_struct.fnames_im_test  = arrayfun( @(x) x.name, dir([experiment_struct.experiment_settings.directory_test,  '*.jpg']),  'UniformOutput', false );
        end
        
        if ~train_test_dirs_match && have_training_split_dir
            % respect the provided splits
            data_split_struct = situate.data_load_splits_from_directory( experiment_struct.experiment_settings.training_testing_split_directory );
            display(['loaded training splits from: ' experiment_struct.experiment_settings.training_testing_split_directory]);
        end
       
        % if specific folds are specified, then limit to those folds
        if ~isfield(experiment_struct.experiment_settings,'specific_folds') || isempty(experiment_struct.experiment_settings.specific_folds)
            fold_inds = 1:experiment_struct.experiment_settings.num_folds;
        else
            fold_inds = experiment_struct.experiment_settings.specific_folds;
        end
        
        % if a maximum number of testing images was specified, enforce here
        if ~isempty(experiment_struct.experiment_settings.max_testing_images)
            for fii = 1:length(fold_inds)
                fi = fold_inds(fii);
                if experiment_struct.experiment_settings.max_testing_images < length(data_split_struct(fi).fnames_lb_test)
                    data_split_struct(fi).fnames_lb_test = data_split_struct(fi).fnames_lb_test(1 : experiment_struct.experiment_settings.max_testing_images );
                    data_split_struct(fi).fnames_im_test = data_split_struct(fi).fnames_im_test(1 : experiment_struct.experiment_settings.max_testing_images );
                end
            end
        end
        
        % make sure all files exist in the specified directories
        %   note: turns out the third assertion is fine as fnames_lb_test may be empty, and
        %   assert( all( [] ) ) passes.
        for fii = 1:length(fold_inds)
            fi = fold_inds(fii);
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_train, x), 'file' ), data_split_struct(fi).fnames_lb_train) ) );
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_train, x), 'file' ), data_split_struct(fi).fnames_im_train) ) );
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_test,  x), 'file' ), data_split_struct(fi).fnames_lb_test)  ) );
            assert( all( cellfun( @(x) exist(fullfile(experiment_struct.experiment_settings.directory_test,  x), 'file' ), data_split_struct(fi).fnames_im_test)  ) );
        end

        % make sure all training labels and images have their partners
        for fii = 1:length(fold_inds)
            fi = fold_inds(fii);
            assert( isequal( ...
                sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct(fi).fnames_lb_train, 'UniformOutput', false )), ...
                sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct(fi).fnames_im_train, 'UniformOutput', false )) ) );
        end
            
        
        
%% run through folds

    for fii = 1:length(fold_inds)
    
        fi = fold_inds(fii);

        learned_models = []; % contains everything we gather from training data, so is reset at the start of each fold
        learned_models_training_functions = []; % used to see if we can skip on re-training models

        fnames_lb_train = cellfun( @(x) fullfile(experiment_struct.experiment_settings.directory_train, x), data_split_struct(fi).fnames_lb_train, 'UniformOutput', false );
        fnames_im_test  = cellfun( @(x) fullfile(experiment_struct.experiment_settings.directory_test,  x), data_split_struct(fi).fnames_im_test,  'UniformOutput', false );
        
        if isempty( experiment_struct.experiment_settings.max_testing_images )
            experiment_struct.experiment_settings.max_testing_images = length(fnames_im_test);
        end
        
        [~, fnames_fail, exceptions, failed_inds] = situate.labl_validate( fnames_lb_train, situation_struct );
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

            keep_going = true;
            cur_image_ind = 1;
            while keep_going

                % run on the current image
                cur_fname_im = fnames_im_test{cur_image_ind};

                tic;
                [ ~, run_data_cur, visualizer_status_string ] = situate.main_loop( cur_fname_im, cur_parameterization, learned_models );


                if experiment_struct.experiment_settings.use_visualizer % handle visualizer status

                    switch visualizer_status_string
                        case 'restart'
                            % keep_going = true;
                        case 'next_image'
                            % keep_going = true;
                            cur_image_ind = cur_image_ind + 1;
                        case 'stop'
                            keep_going = false;
                        otherwise
                            keep_going = false;
                            % because we probably killed it with a window close
                    end

                else

                   % store results
                    workspaces_final{cur_image_ind} = run_data_cur.workspace_final;
                    agent_records{cur_image_ind}    = run_data_cur.agent_record;

                    % display an update in the console
                    num_iterations_run = sum(~eq(0,[run_data_cur.agent_record.interest]));
                    labels_missed = setdiff(cur_parameterization.situation_objects,run_data_cur.workspace_final.labels);
                    labels_temp = [run_data_cur.workspace_final.labels labels_missed];
                    % try to allign workspace boxes with gt
                    cur_fname_lb = [fileparts_mq(cur_fname_im,'path/name') '.json'];
                    if exist(cur_fname_lb,'file')
                        reconciled_workspace = situate.workspace_score(run_data_cur.workspace_final, cur_fname_lb, cur_parameterization );
                    else
                        reconciled_workspace = run_data_cur.workspace_final;
                    end
                    GT_IOUs = [reconciled_workspace.GT_IOU nan(1,length(labels_missed))];
                    [~,sort_order] = sort( labels_temp );
                    IOUs_of_last_run = num2str(GT_IOUs(sort_order));
                    fprintf('%s, %3d / %d, %4d steps, %6.2fs,  IOUs: [%s] \n', cur_parameterization.description, cur_image_ind, length(fnames_im_test), num_iterations_run, toc, IOUs_of_last_run );

                    cur_image_ind = cur_image_ind + 1;

                end

                % decide if we keep going or not
                if cur_image_ind > experiment_struct.experiment_settings.max_testing_images ...
                || cur_image_ind > length(fnames_im_test)
                    keep_going = false;
                    if experiment_struct.experiment_settings.use_visualizer
                        msgbox('out of testing images');
                    end
                end

                if ~keep_going
                    break;
                end

            end

            % bail after the first experimental setup if we're using the visualizer
            if experiment_struct.experiment_settings.use_visualizer
                break;
            end

            % save off results, each condition and fold pair gets a file
            if ~isempty(strfind(cur_parameterization.description,'.'))
                cur_param_desc = cur_parameterization.description(1:strfind(cur_parameterization.description,'.')-1);
            else
                cur_param_desc = cur_parameterization.description;
            end
            save_fname = fullfile(experiment_struct.results_directory, [cur_param_desc '_fold_' num2str(fi,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);

            results_struct = [];
            results_struct.p_condition      = cur_parameterization;
            results_struct.workspaces_final = workspaces_final;
            results_struct.agent_records    = agent_records;
            results_struct.fnames_lb_train  = fnames_lb_train;
            results_struct.fnames_im_test   = fnames_im_test;

            save(save_fname, '-v7', '-struct','results_struct');

            fprintf('saved to:\n    %s\n', save_fname);

        end

        % bail after the first fold if we're using the visualizer
        if experiment_struct.experiment_settings.use_visualizer
            break;
        end

            
            
    end
    
    
    
end

       
