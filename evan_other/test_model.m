%model_var = '/stash/mm-group/evan/saved_models_box_adjust/dog_model_external_2.mat'
model_var = '/stash/mm-group/evan/crop_learn/models/svm_dog_background?.mat'
load(model_var,'svm_model');
path_var = 'dog';

if ~exist('hogs','var')
down = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/down/'));
up = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/up/'));
left = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/left/'));
right = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/right/'));
shrink = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/shrink/'));
expand = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/expand/'));
orig = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/orig/'));
back = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/background/'));

examples = numel(down)*8;

filenames = [down,up,left,right,shrink,expand,orig,back];
	hogs = load_cnn_data(filenames);
	y = size(hogs);
	x = size(down);
	rows = x(1);
	block = y(2)/8;
	hogs2 = mat2cell(hogs,[rows],[block,block,block,block,block,block,block,block]);
    hogs3 = cell2mat(transpose(hogs2));
end
%%  
vote_mat = zeros(examples,28);
count_mat = zeros(examples,8);
score_mat = zeros(examples,28);
counts = zeros(8,8);
for i = 1:28
    disp(i);
	[predictions,scores] = predict(svm_model{i},hogs3);
    predictions = str2num(char(predictions));
    vote_mat(:,i) = predictions;
    score_mat(:,i) = scores(:,1);
end
for i = 1:length(vote_mat)
    row = vote_mat(i,:);
    [a,b] = hist(row,unique(row));
    for k = 1:numel(b)
        count_mat(i,b(k)) = a(k);
    end
end
    
m = mode(vote_mat,2);
blocks = mat2cell(m,[rows,rows,rows,rows,rows,rows,rows,rows]);
for i = 1:numel(blocks)
    [a,b] = hist(blocks{i},unique(blocks{i}));
    for k = 1:numel(b)
        counts(i,b(k)) = a(k);
    end
end
counts
% save(res_var,'counts','count_mat','vote_mat','score_mat')
