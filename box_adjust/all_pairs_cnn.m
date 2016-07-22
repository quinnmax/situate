% function [] = all_pairs_cnn(fnames,fold)
	fold = '_background';
	% fnames = '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/fnames_train_full.txt';
%% train cnn models
% file_list = dataread('file',fnames,'%s','delimiter','\n');
% base_path = '/stash/mm-group/evan/crop_learn/data/fullset/train/';
% save_path = '/stash/mm-group/evan/saved_models_box_adjust';
base_path = '~/data/fullset/train';
save_path = '~/saved_models_box_adjust';
path_var = {'dog','walker','leash'};
model_var = {strcat('dog_model_',fold,'.mat'),strcat('walker_model_',fold,'.mat'),strcat('leash_model_',fold,'.mat')};
for ii = 2
    orig   = image_files(strcat( base_path, path_var{ii}, '/orig/'));
    up     = image_files(strcat( base_path, path_var{ii},  '/up/'));
    down   = image_files(strcat( base_path, path_var{ii},  '/down/'));
    left   = image_files(strcat( base_path, path_var{ii},  '/left/'));
    right  = image_files(strcat( base_path, path_var{ii},  '/right/'));
    expand = image_files(strcat( base_path, path_var{ii},  '/expand/'));
    shrink = image_files(strcat( base_path, path_var{ii},  '/shrink/'));
    back   = image_files(strcat( base_path, path_var{ii},  '/background/'));
	%%	
	filenames = [orig,up,down,right,left,shrink,expand,back];
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
	comboslabel = nchoosek(labels1,2)
	for i = 1:28
	    first = combos{i,1}
	    second = combos{i,2}
	    hog_data = [comboshog{i,1}; comboshog{i,2}];
	    label_data = [comboslabel{i,1}, comboslabel{i,2}];
		svm_model{i} = fitcsvm(hog_data,label_data,'KernelFunction','linear','Standardize',true,'ClassNames',{first,second});

	    clear first second predictions scores label_data hog_data;
	end
	save('-v7.3',strcat(save_path,model_var{ii}),'svm_model');
end
