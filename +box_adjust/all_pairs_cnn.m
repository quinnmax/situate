function [] = all_pairs_cnn( fnames )

    %% train cnn models

    file_list = dataread('file',fnames,'%s','delimiter','\n');
    path_var  = {'dog','walker','leash'};
    model_var = {'dog_model.mat','walker_model.mat','leash_model.mat'};
    
    for ii = 1:3

        down   = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/down/'));
        up     = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/up/'));
        left   = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/left/'));
        right  = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/right/'));
        shrink = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/shrink/'));
        expand = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/expand/'));
        orig   = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/orig/'));
        back   = image_files(strcat( '/stash/mm-group/evan/crop_learn/data/croptest/train/', path_var{ii}, '/background/'));

        %%	
        filenames = [ down, up, left, right, shrink, expand, orig, back ];
        hogs = load_cnn_data(filenames);
        y = size(hogs);
        x = size(down);
        rows = x(1);
        block = y(2)/8;
        hogs2 = mat2cell(hogs,[rows],[block,block,block,block,block,block,block,block]);

        %%
        labels = [map(1:size(down, 1), @(x) '1') map(1:size(up, 1), @(x) '2')...
        map(1:size(left, 1), @(x) '3') map(1:size(right, 1), @(x) '4') ...
        map(1:size(shrink, 1), @(x) '5') map(1:size(expand, 1), @(x) '6') ...
        map(1:size(orig, 1), @(x) '7') map(1:size(back, 1), @(x) '8')];
        %	labels = transpose(labels);

        labels1 = mat2cell(labels,1,[rows,rows,rows,rows,rows,rows,rows,rows]);
        clear down up left right shrink expand orig;

        %% Train an SVM model
        classes = {'1','2','3','4','5','6','7','8'};
        combos = nchoosek(classes,2);
        comboshog = nchoosek(hogs2,2);
        comboslabel = nchoosek(labels1,2);
        svm_model = cell(1,28);
        for i = 1:28
            first = combos{i,1};
            second = combos{i,2};
            hog_data = [comboshog{i,1}; comboshog{i,2}];
            label_data = [comboslabel{i,1}, comboslabel{i,2}];
            svm_model{i} = fitcsvm(hog_data,label_data,'KernelFunction','linear','Standardize',true,'ClassNames',{first,second});

            clear first second predictions scores label_data hog_data;
        end
    fnames_lb_train = file_list;
    save(['saved_models_box_adjust/' model_var(ii)],'svm_model','fnames_lb_train')

    end
    
end