

function data_folds = load_data_splits_from_directory( split_file_directory )

       % Load the folds from files rather than generating new ones

        fnames_splits_train = dir(fullfile(split_file_directory, '*_fnames_split_*_train.txt'));
        fnames_splits_test  = dir(fullfile(split_file_directory, '*_fnames_split_*_test.txt' ));
        fnames_splits_train = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_train.name}, 'UniformOutput', false );
        fnames_splits_test  = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_test.name},  'UniformOutput', false );

        assert( length(fnames_splits_train) > 0 );
        assert( length(fnames_splits_train) == length(fnames_splits_test) );

        fprintf('using training splits from: \t%s\n', fnames_splits_train{:});
        fprintf('using testing  splits from: \t%s\n', fnames_splits_test{:} );

        temp = [];
        temp.fnames_lb_train = cellfun( @(x) importdata(x, '\n'), fnames_splits_train, 'UniformOutput', false );
        temp.fnames_lb_test  = cellfun( @(x) importdata(x, '\n'), fnames_splits_test,  'UniformOutput', false );
        data_folds = [];
        for i = 1:length(temp.fnames_lb_train)
            data_folds(i).fnames_lb_train = temp.fnames_lb_train{i};
            data_folds(i).fnames_lb_test  = temp.fnames_lb_test{i};
            data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_train{i}, 'UniformOutput', false );
            data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_test{i},  'UniformOutput', false );
        end

end

       
           