function data_folds = data_generate_split_files_for_long_run( training_input, testing_input, n, output_directory )

    % data_folds = data_generate_split_files_for_long_run( training_input, testing_input, [n], [output_directory] );
    %
    % split up a long run into smaller runs for more frequent saving. 
    %   training_input: either a cell array of file names (with path) or a directory.
    %   training_input: either a cell array of file names (with path) or a directory.
    %   n: number of images to include in each fold. if not set, will default to 100.
    %   output_directory: if not provided, will go to situate/data_splits/long_run_splits_yyyy.mm.dd.HH.MM.SS/
    
    
    
    if ischar(training_input) && isdir(training_input)
        fnames_train = dir2filenames( training_input, '*.jpg' );
    elseif iscell( training_input )
        fnames_train = training_input;
    else
        error('unrecognized input');
    end
    
    
    
    if ischar(testing_input) && isdir(testing_input)
        fnames_test = dir2filenames( testing_input, '*.jpg');
    elseif iscell( testing_input )
        fnames_test = testing_input;
    else
        error('unrecognized input');
    end
    
    
    
    if ~exist('n','var') || isempty(n) || n < 1
        n = 100;
    end
    
    
    if ~exist('output_directory','var') || isempty(output_directory)
        output_directory = fullfile( 'data_splits', ['long_run_splits_' datestr(now,'yyyy.mm.dd.HH.MM.SS')] );
    end
    
    
    
    test_inds_0 = 1:n:length(fnames_test);
    test_inds_f = [test_inds_0(2:end)-1 length(fnames_test)];
    
    data_folds = [];
    data_folds.fnames_im_train = [];
    data_folds.fnames_im_test  = [];
    data_folds.fnames_lb_train = [];
    data_folds.fnames_lb_test  = [];
    data_folds = repmat(data_folds,length(test_inds_0),1);
    
    for fi = 1:length(test_inds_0)
        data_folds(fi).fnames_im_train = fnames_train;
        data_folds(fi).fnames_lb_train  = cellfun( @(x) [x(1:end-4) '.json'], data_folds(fi).fnames_im_train, 'UniformOutput', false );
        
        data_folds(fi).fnames_im_test = fnames_test(test_inds_0(fi):test_inds_f(fi));
        data_folds(fi).fnames_lb_test  = cellfun( @(x) [x(1:end-4) '.json'], data_folds(fi).fnames_im_test, 'UniformOutput', false );
    end
    
    
    
    % save the splits to files
    if ~isdir(output_directory), mkdir(output_directory); end
    
    for i = 1:length(data_folds)
        fname_train_out = fullfile(output_directory, ['fnames_split_' num2str(i,'%02d') '_train.txt']);
        fid_train = fopen(fname_train_out,'w+');
        fprintf(fid_train,'%s\n',data_folds(i).fnames_lb_train{:});
        fclose(fid_train);

        fname_test_out  = fullfile(output_directory, ['fnames_split_' num2str(i,'%02d') '_test.txt' ]);
        fid_test  = fopen(fname_test_out, 'w+');
        fprintf(fid_test, '%s\n',data_folds(i).fnames_lb_test{:} );
        fclose(fid_test);
    end 
    
    
    
end
        
        
    
    
    
    