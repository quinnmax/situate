
function data_folds = data_generate_split_files( data_path, varargin )
% data_folds = data_generate_split_files( data_path, [num_folds], [output_directory] );

    if length(varargin) >= 1
        num_folds = varargin{1};
    else
        num_folds = 1;
    end
    
    if length(varargin) >= 2
        output_directory = varargin{2};
    else
        output_directory = [];
    end

    % get the file names
        
        % get the label files
        dir_data = dir(fullfile(data_path, '*.labl'));
        fnames_lb = {dir_data.name};
        assert(~isempty(fnames_lb));
        
        % get the associated image files
        is_missing_image_file = false(1,length(fnames_lb));
        for fi = 1:length(fnames_lb)
            is_missing_image_file(fi) = ~exist( fullfile(data_path, [fnames_lb{fi}(1:end-5) '.jpg' ]),'file');
        end
        fnames_lb(is_missing_image_file) = [];
        
        % shuffle
        rp = randperm( length(fnames_lb) );
        fnames_lb = fnames_lb(rp);
        
    % generate training/testing splits for cross validation

        n = length(fnames_lb);
        step = floor( n / num_folds );
        fold_inds_start = (0:step:n-step)+1;
        fold_inds_end   = fold_inds_start + step - 1;
        
        data_folds = [];
        data_folds.fnames_im_train = [];
        data_folds.fnames_im_test  = [];
        data_folds.fnames_lb_train = [];
        data_folds.fnames_lb_test  = [];
        data_folds = repmat(data_folds,1,num_folds);
        for i = 1:num_folds
            data_folds(i).fnames_lb_test  = fnames_lb( fold_inds_start(i):fold_inds_end(i) );
            data_folds(i).fnames_lb_train = setdiff( fnames_lb, data_folds(i).fnames_lb_test );
            data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-5) '.jpg'], data_folds(i).fnames_lb_test,  'UniformOutput', false );
            data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-5) '.jpg'], data_folds(i).fnames_lb_train, 'UniformOutput', false );
        end
          
    % save the splits to files
    if ~isempty(output_directory)
        
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

        
end

