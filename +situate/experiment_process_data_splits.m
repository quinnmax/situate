
function [data_split_struct, fold_inds, experiment_settings] = experiment_process_data_splits( experiment_settings )

    % this is explicitly for generating splits and folds from an experiment_settings_struct
    %
    % are we:
    %   loading image from defined splits?
    %   loading up all images from the directory?
    %   generating new splits?
    
    data_split_struct = [];
    
    % see if directories exist as described
    experiment_settings.vision_model.directory_train    = find_base_dir( experiment_settings.vision_model.directory_train );
    experiment_settings.situation_model.directory_train = find_base_dir( experiment_settings.situation_model.directory_train );
    experiment_settings.directory_test                  = find_base_dir( experiment_settings.directory_test );
    
    % for vision
    [ data_split_struct_vision, ...
      experiment_settings.vision_model.directory_train ] = ...
        process_per_model_split_sturct( ...
            experiment_settings.vision_model.directory_train, ...
            experiment_settings.vision_model.training_testing_split_directory, ...
            experiment_settings );
    
    % for situation
    [ data_split_struct_situation, ...
      experiment_settings.situation_model.directory_train ] = ...
        process_per_model_split_sturct( ...
            experiment_settings.situation_model.directory_train, ...
            experiment_settings.situation_model.training_testing_split_directory, ...
            experiment_settings );
        
    
%% now try to reconcile

    load_testing_images_separately = false;
    
    if isequal( experiment_settings.vision_model.directory_train, experiment_settings.situation_model.directory_train )
        
        % we have the same training directories for vision and situation model. 
        % if the testing directory is the same as those 2, then we use the splits.
        % if it doesn't match, then we'll ignore the splits for testing, and load up independently.
        
        try
            assert( isequal( [data_split_struct_vision.fnames_im_test], [data_split_struct_situation.fnames_im_test] ) )
        catch
            warning('error while training vision and situation models: same training sets, different testing sets');
            % we get here if we had no split files at all, and generated them fresh for both. being
            % random, we got different sets. I did this so we could use more data for the visio
            % model and don't really want to remove the functionality all together. just going to
            % force them to be the same for now
            warning('using vision model splits for both');
            data_split_struct_situation = data_split_struct_vision;
        end
        
        % same same, just use them
        data_split_struct.vision = data_split_struct_vision;
        data_split_struct.situation = data_split_struct_situation;
        
        if ~isequal( experiment_settings.directory_test, experiment_settings.vision_model.directory_train )
            load_testing_images_separately = true;
        end
           
    elseif ~isequal( experiment_settings.vision_model.directory_train, experiment_settings.situation_model.directory_train ) ...
        && ~isequal( experiment_settings.vision_model.directory_train, experiment_settings.directory_test ) ...
        && ~isequal( experiment_settings.situation_model.directory_train, experiment_settings.directory_test )
            
        % good. none of them match. 
        % respect the split directories of the training sets (as they may be specifying a saved model)
        % use all of the images in the testing directory (restricted by experiment_settings.max_testing_images)
        
        load_testing_images_separately = true;
        
    else
        
        % just throw an error
        
        error_string = '';
        if ~isequal( experiment_settings.vision_model.directory_train, experiment_settings.situation_model.directory_train )
            error_string = [error_string; 'vision model and situation model training directories do not match one another.'];
        end
        if data_split_struct_vision.train_test_dirs_match
            error_string = [error_string; 'vision model ALSO matches testing data directory'];
        end
        if data_split_struct_situation.train_test_dirs_match
            error_string = [error_string; 'situation model ALSO matches testing data directory'];
        end
        error_string = [error_string; 'but'];
        if ~data_split_struct_vision.train_test_dirs_match
            error_string = [error_string; 'vision model DOES NOT match testing data directory'];
        end
        if ~data_split_struct_situation.train_test_dirs_match
            error_string = [error_string; 'situation model DOES NOT match testing data directory'];
        end
        error( error_string );
    
    end
    
    if load_testing_images_separately
        
        % if we get to here, we're loading up testing images without using the split file. 
        % instead, we'll load up everything in the testing directory
        
        fnames_im_test = arrayfun( @(x) x.name, dir(fullfile(experiment_settings.directory_test, '*.jpg')), 'UniformOutput', false );
        fnames_lb_test = arrayfun( @(x) x.name, dir(fullfile(experiment_settings.directory_test, '*.json')), 'UniformOutput', false );
        
        for fi = 1:length(data_split_struct_vision)
            data_split_struct_vision(fi).fnames_im_test = fnames_im_test;
            data_split_struct_vision(fi).fnames_lb_test = fnames_lb_test;
        end
        
        for fi = 1:length(data_split_struct_situation)
            data_split_struct_situation(fi).fnames_im_test = fnames_im_test;
            data_split_struct_situation(fi).fnames_lb_test = fnames_lb_test;
        end
        
    end
            
    
    
%% now tidy up
    
    
    % if specific folds are given, then limit to those folds
    if ~isfield(experiment_settings,'specific_folds') || isempty(experiment_settings.specific_folds)
        fold_inds = 1:experiment_settings.num_folds;
    else
        fold_inds = experiment_settings.specific_folds;
    end

    % if a maximum number of testing images was specified, enforce here
    if ~isempty(experiment_settings.max_testing_images)
        for fii = 1:length(fold_inds)
            fi = fold_inds(fii);
            if experiment_settings.max_testing_images < length(data_split_struct_vision(fi).fnames_lb_test)
                data_split_struct_vision(fi).fnames_lb_test = data_split_struct_vision(fi).fnames_lb_test(1 : experiment_settings.max_testing_images );
                data_split_struct_vision(fi).fnames_im_test = data_split_struct_vision(fi).fnames_im_test(1 : experiment_settings.max_testing_images );
            end
            if experiment_settings.max_testing_images < length(data_split_struct_situation(fi).fnames_lb_test)
                data_split_struct_situation(fi).fnames_lb_test = data_split_struct_situation(fi).fnames_lb_test(1 : experiment_settings.max_testing_images );
                data_split_struct_situation(fi).fnames_im_test = data_split_struct_situation(fi).fnames_im_test(1 : experiment_settings.max_testing_images );
            end
        end
    end

    % make sure all files exist in the specified directories
    %   note: turns out the third assertion is fine as fnames_lb_test may be empty, and
    %   assert( all( [] ) ) passes.
    for fii = 1:length(fold_inds)
        fi = fold_inds(fii);
        
        full_file_lb_train = cellfun( @(x) fullfile( experiment_settings.vision_model.directory_train, x), data_split_struct_vision(fi).fnames_lb_train, 'UniformOutput', false );
        full_file_im_train = cellfun( @(x) fullfile( experiment_settings.vision_model.directory_train, x), data_split_struct_vision(fi).fnames_im_train, 'UniformOutput', false );
        full_file_lb_test  = cellfun( @(x) fullfile( experiment_settings.directory_test, x),  data_split_struct_vision(fi).fnames_lb_test,  'UniformOutput', false );
        full_file_im_test  = cellfun( @(x) fullfile( experiment_settings.directory_test, x),  data_split_struct_vision(fi).fnames_im_test,  'UniformOutput', false );
        expected_files_1 = [full_file_lb_train; full_file_im_train; full_file_lb_test; full_file_im_test];
        expected_files_exist_1 = cellfun( @(x) exist(x,'file'), expected_files_1 );
        
        full_file_lb_train = cellfun( @(x) fullfile( experiment_settings.situation_model.directory_train, x), data_split_struct_situation(fi).fnames_lb_train, 'UniformOutput', false );
        full_file_im_train = cellfun( @(x) fullfile( experiment_settings.situation_model.directory_train, x), data_split_struct_situation(fi).fnames_im_train, 'UniformOutput', false );
        full_file_lb_test  = cellfun( @(x) fullfile( experiment_settings.directory_test, x),  data_split_struct_situation(fi).fnames_lb_test,  'UniformOutput', false );
        full_file_im_test  = cellfun( @(x) fullfile( experiment_settings.directory_test, x),  data_split_struct_situation(fi).fnames_im_test,  'UniformOutput', false );
        expected_files_2 = [full_file_lb_train; full_file_im_train; full_file_lb_test; full_file_im_test];
        expected_files_exist_2 = cellfun( @(x) exist(x,'file'), expected_files_2 );
        
        if any( ~expected_files_exist_1 ) || any( ~expected_files_exist_2 )
            warning('expected files not found');
            display( expected_files_1( ~expected_files_exist_1 ) );
            display( expected_files_2( ~expected_files_exist_2 ) );
            error('expected files not found');
        end
           
    end

    % make sure all training labels and images have their partners
    for fii = 1:length(fold_inds)
        fi = fold_inds(fii);
        assert( isequal( ...
            sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct_vision(fi).fnames_lb_train, 'UniformOutput', false )), ...
            sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct_vision(fi).fnames_im_train, 'UniformOutput', false )) ) );
    end
    
    for fii = 1:length(fold_inds)
        fi = fold_inds(fii);
        assert( isequal( ...
            sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct_situation(fi).fnames_lb_train, 'UniformOutput', false )), ...
            sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct_situation(fi).fnames_im_train, 'UniformOutput', false )) ) );
    end
    
    data_split_struct.vision     = data_split_struct_vision;
    data_split_struct.situation  = data_split_struct_situation;
    
end
















function [data_split_struct,directory_train] = process_per_model_split_sturct( directory_train, training_testing_split_directory, experiment_settings )
    
    data_split_struct = [];
    
    if isempty( training_testing_split_directory ) ...
    || ( ~exist( training_testing_split_directory, 'dir') ...
        && ~exist( fullfile( 'data_splits', training_testing_split_directory), 'dir' ) )
        have_training_split_dir = false;
    else
        have_training_split_dir = true;
        if ~exist( training_testing_split_directory, 'dir')
            training_testing_split_directory = ...
                fullfile( 'data_splits', training_testing_split_directory);
        end 
    end
    
    if have_training_split_dir
        data_split_struct = situate.data_load_splits_from_directory( training_testing_split_directory );
        display(['loaded training splits from: ' training_testing_split_directory]);
    end
    
    if ~have_training_split_dir && isequal( experiment_settings.directory_test, directory_train )
        % make new splits save them off
        disp('generating new training/testing splits');
        data_path = directory_train;
        output_directory = fullfile('data_splits/', [experiment_settings.description '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
        num_folds = experiment_settings.num_folds;
        max_images_per_fold = experiment_settings.max_testing_images;
        if ~isempty(max_images_per_fold)
            data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'test_im_per_fold', max_images_per_fold, 'output_directory', output_directory );
        else
            data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'output_directory', output_directory );
        end
        for si = 1:numel(data_slit_struct)
            data_split_struct.train_test_dirs_match = true;
        end
    elseif ~have_training_split_dir && ~isequal( experiment_settings.directory_test, directory_train )
        % use everything in directories
        disp('using all training images');
        data_split_struct.fnames_lb_train = arrayfun( @(x) x.name, dir(fullfile(directory_train,                    '*.json')), 'UniformOutput', false );
        data_split_struct.fnames_lb_test  = arrayfun( @(x) x.name, dir(fullfile(experiment_settings.directory_test, '*.json')), 'UniformOutput', false );
        data_split_struct.fnames_im_train = arrayfun( @(x) x.name, dir(fullfile(directory_train,                    '*.jpg')),  'UniformOutput', false );
        data_split_struct.fnames_im_test  = arrayfun( @(x) x.name, dir(fullfile(experiment_settings.directory_test, '*.jpg')),  'UniformOutput', false );
        data_split_struct.train_test_dirs_match = false;
    end

end


