path_var = 'dog'

down = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/down/'));
up = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/up/'));
left = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/left/'));
right = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/right/'));
shrink = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/shrink/'));
expand = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/expand/'));
orig = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/orig/'));
back = image_files(strcat('/stash/mm-group/evan/crop_learn/data/fullset/test/',path_var,'/background/'));

examples = numel(down)*8;
% temp = load('data/part3/net-epoch-13.mat','net');
% net = temp.net;
net.layers{end}.type = 'softmax'
filenames = [down(1:600);up(1:600);left(1:600);right(1:600);shrink(1:600);expand(1:600);orig(1:600);back(1:600)];
guesses = classify_cnn_data(filenames,net);
x = size(down);
rows = 100
counts = zeros(8);
%%
blocks = mat2cell(guesses,[rows,rows,rows,rows,rows,rows,rows,rows]);
for i = 1:numel(blocks)
    [a,b] = hist(blocks{i},unique(blocks{i}));
    for k = 1:numel(b)
        counts(i,b(k)) = a(k);
    end
end
counts
% save(res_var,'counts','count_mat','vote_mat','score_mat')
