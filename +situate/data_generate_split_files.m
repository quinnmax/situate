
function data_folds = data_generate_split_files( data_path, varargin )
% data_folds = data_generate_split_files( data_path, 'num_folds', num_folds );
% data_folds = data_generate_split_files( data_path, 'test_im_per_fold', test_im_per_fold );
% data_folds = data_generate_split_files( data_path, 'testing_ratio', testing_ratio );
%
% data_folds = data_generate_split_files( data_path, 'output_directory', output_directory );
%
% if not specified, num folds will be 1
% if test_im_per_fold and testing_ratio aren't specified and num folds is 1, 25% will be for testing

    % process the input

        for vi = 1:2:length(varargin)
            switch varargin{vi}
                case 'num_folds'
                    num_folds = varargin{vi + 1};
                case 'test_im_per_fold'
                    test_im_per_fold = varargin{vi + 1};
                case 'testing_ratio'
                    testing_ratio = varargin{vi + 1};
                case 'output_directory'
                    output_directory = varargin{vi + 1};
                otherwise
                    error('unknown arg')
            end
        end

        if ~exist('num_folds','var'),        num_folds        = 1; end
        if ~exist('test_im_per_fold','var'), test_im_per_fold = []; end
        if ~exist('testing_ratio','var'),    testing_ratio    = []; end
        if ~exist('output_directory','var'), output_directory = []; end
   
    % get the file names
        
        % get the label files
        dir_data = dir(fullfile(data_path, '*.json'));
        fnames_lb = {dir_data.name};
        assert(~isempty(fnames_lb));
        
        % get the associated image files
        is_missing_image_file = cellfun( @(x) ~exist(fullfile( data_path, [fileparts_mq(x,'name') '.jpg']),'file'), fnames_lb );
        fnames_lb(is_missing_image_file) = [];
        
        % shuffle
        rp = randperm( length(fnames_lb) );
        fnames_lb = fnames_lb(rp);
        
        n = length(fnames_lb);
        
    % oof, the logic of these options
    
        if isempty(test_im_per_fold) ...
        && isempty(testing_ratio) ...
        
            % we'll try to set up folds, but we'll use 25% testing data if there's just 1
    
            if num_folds == 1
                testing_ratio = .25;
                test_im_per_fold = floor(testing_ratio * n);
            else
                testing_ratio = 1/num_folds;
                test_im_per_fold = floor(testing_ratio * n);
            end
            
        elseif ~isempty(testing_im_per_fold)
            % good to go
        
        elseif ~isempty(testing_ratio)
            test_im_per_fold = floor(testing_ratio * n);
            
        end
            
    % generate training/testing splits multiple folds
    
        step = floor( n / num_folds );
        test_groups_start = (0:step:n-step)+1;
        if test_im_per_fold < step
            test_groups_end   = test_groups_start + test_im_per_fold - 1;
        else
            test_groups_end   = test_groups_start + step - 1;
        end
        
        data_folds = [];
        data_folds.fnames_im_train = [];
        data_folds.fnames_im_test  = [];
        data_folds.fnames_lb_train = [];
        data_folds.fnames_lb_test  = [];
        data_folds = repmat(data_folds,1,num_folds);
        for i = 1:num_folds
            data_folds(i).fnames_lb_test  = fnames_lb( test_groups_start(i):test_groups_end(i) );
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

