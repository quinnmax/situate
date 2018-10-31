
function [data_split_struct, fold_inds, experiment_settings] = experiment_process_data_splits( experiment_settings )


    % are we:
    %   loading image from defined splits?
    %   loading up all images from the directory?
    %   generating splits?
    
    data_split_struct = [];
    
    % see if directories exist as described
    experiment_settings.vision_model.directory_train    = find_base_dir( experiment_settings.vision_model.directory_train );
    experiment_settings.situation_model.directory_train = find_base_dir( experiment_settings.situation_model.directory_train );
    experiment_settings.directory_test                  = find_base_dir( experiment_settings.directory_test );
    
    % for vision
    [ data_split_struct_vision, ...
      experiment_settings.vision_model.directory_train ] = ...
        process_per_model_split_sturct( ...
            experiment_settings.directory_test, ...
            experiment_settings.vision_model.directory_train, ...
            experiment_settings.vision_model.training_testing_split_directory, ...
            experiment_settings.max_testing_images);
    
    % for situation
    [ data_split_struct_situation, ...
      experiment_settings.situation_model.directory_train ] = ...
        process_per_model_split_sturct( ...
            experiment_settings.directory_test, ...
            experiment_settings.situation_model.directory_train, ...
            experiment_settings.situation_model.training_testing_split_directory, ...
            experiment_settings.max_testing_images );
        
    experiment_settings.directory_test 
   
    
%% now try to reconcile

    try
        assert( isequal( [data_split_struct_vision.fnames_lb_test], [data_split_struct_situation.fnames_lb_test] ) )
    catch
        error('it looks like the testing sets don''t match, can''t really go on from here yet')
    end
    
    if isequal( experiment_settings.vision_model.directory_train, experiment_settings.situation_model.directory_train )
        
        % good. return the two separate split structs, use them during training, and move on
        
    elseif ~isequal( experiment_settings.vision_model.directory_train, experiment_settings.situation_model.directory_train ) ...
        && ~data_split_struct_vision.train_test_dirs_match ...
        && ~data_split_struct_situation.train_test_dirs_match 
    
        % good. return the two separate split structs, use them during training, and move on
        
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
            
    
%% now tidy up
    
    
    % if specific folds are specified, then limit to those folds
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
















function [data_split_struct,directory_train] = process_per_model_split_sturct( directory_test, directory_train, training_testing_split_directory, max_testing_images )
    
    data_split_struct = [];
    data_split_struct.train_test_dirs_match = isequal( directory_test, directory_train );

    if isempty( training_testing_split_directory ) ...
    && ~exist( training_testing_split_directory, 'dir') ...
    && ~exist( fullfile( 'data_splits', training_testing_split_directory), 'dir' )
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
        display(['loaded vision model training splits from: ' training_testing_split_directory]);
    end
    
    if ~have_training_split_dir && data_split_struct.train_test_dirs_match 
        % make new splits save them off
        disp('generating new training/testing splits');
        data_path = directory_train;
        output_directory = fullfile('data_splits/', [situation_struct.desc '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
        num_folds = experiment_settings.num_folds;
        max_images_per_fold = max_testing_images;
        if ~isempty(max_images_per_fold)
            data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'test_im_per_fold', max_images_per_fold, 'output_directory', output_directory );
        else
            data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'output_directory', output_directory );
        end
    end

    if ~have_training_split_dir && ~data_split_struct.train_test_dirs_match 
        % use everything in directories
        disp('using all vision model training images');
        data_split_struct.fnames_lb_train = arrayfun( @(x) x.name, dir(fullfile(directory_train, '*.json')), 'UniformOutput', false );
        data_split_struct.fnames_lb_test  = arrayfun( @(x) x.name, dir(fullfile(directory_test,  '*.json')), 'UniformOutput', false );
        data_split_struct.fnames_im_train = arrayfun( @(x) x.name, dir(fullfile(directory_train, '*.jpg')),  'UniformOutput', false );
        data_split_struct.fnames_im_test  = arrayfun( @(x) x.name, dir(fullfile(directory_test,  '*.jpg')),  'UniformOutput', false );
    end

end


