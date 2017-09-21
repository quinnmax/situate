global dog_svm_model walker_svm_model leash_svm_model net layer Qtab;
% load(strcat('/stash/mm-group/evan/crop_learn/models/svm_','dog','.mat'),'svm_model');
% dog_svm_model = svm_model;
% load(strcat('/stash/mm-group/evan/crop_learn/models/svm_','walker','.mat'),'svm_model');
% walker_svm_model = svm_model;
% load(strcat('/stash/mm-group/evan/crop_learn/models/svm_','leash','.mat'),'svm_model');
% leash_svm_model = svm_model;
%%
if ~exist('cnn_net','var')
here = pwd;
cd '/stash/mm-group/evan/sequencer/cnn/matconvnet-1.0-beta20/';
disp('Starting MatConvNet');
run matlab/vl_setupnn;
net = vl_simplenn_tidy(load('imagenet-vgg-f.mat'));
layer = 18;
net.layers = net.layers(1:layer);
cd (here);  
end

if ~exist('statespace','var')
    move1 = [1,2,3,4,5,6];
    act1 = linspace(0.1,.5,5);
    iou1 = [0,1];
    move2 = [1,2,3,4,5,6];
    act2 = linspace(0.1,.5,5);
    iou2 = [0,1];
    curmove = [1,2,3,4,5,6];
    actions = linspace(0.1,.5,5);
    statespace = combvector(move1,act1,iou1,move2,act2,iou2,curmove,actions);
    disp(length(statespace))
    key = cell(length(statespace),1);
    value = zeros(length(statespace),1);
    for i = 1:length(statespace)
        disp(i)
        key{i} = strcat(num2str(statespace(i,1)),',',num2str(statespace(i,2)),',',num2str(statespace(i,3)),',',...
        num2str(statespace(i,4)),',',num2str(statespace(i,5)),',',num2str(statespace(i,6)),',',num2str(statespace(i,7)),...
        ',',num2str(statespace(i,8)));
        value(i) = 0.1*rand+0.001;
    end
end
Qtab = containers.Map(key,value)



discount = 0.9;
learning_rate = 0.5;
%%

load('/u/eroche/matlab/episodes.mat','episodes');
for i = 1:length(episodes)
	base_image = imread(episodes{i}.impath);
	object = episodes{i}.object;
	ground_truth = episodes{i}.ground;
	starting_box = episodes{i}.start;

	shift = rand;
	[movement,IOU,new_crop] = environment_update(base_image,object,ground_truth,starting_box,shift);

	state{1}.movement = movement;
	state{1}.IOU = IOU;
	old = IOU;
	state{1}.shift = shift;

	shift = rand;
	[movement,IOU,new_crop] = environment_update(base_image,object,ground_truth,new_crop,shift);
	state{2}.movement = movement;
	state{2}.IOU = IOU - old;
	old = IOU; 
	state{2}.shift = shift;
	% hid = hid +1 
	while movement ~= 7
		shift = rand;
		[movement,IOU,new_crop] = environment_update(base_image,object,ground_truth,new_crop,shift);
		state{3}.movement = movement;
		state{3}.IOU = IOU;
		state{3}.shift = shift;
		Q_cur = Qlookup(state{1}.movement,state{1}.shift,state{1}.IOU,state{2}.movement,state{2}.shift,state{2}.IOU,movement,shift);
		peek = zeros(10,6)
		for k = 1:length(actions)
			[movement,IOU,peek_crop] = environment_update(base_image,object,ground_truth,new_crop,actions(k));
			peek(k,1) = movement;
			peek(k,2) = IOU;
			peek(k,3:6) = peek_crop;
			peek(k,7) = Qlookup(state{2}.movement,state{2}.shift,state{2}.IOU,state{3}.movement,state{3}.shift,state{3}.IOU,movement,actions(k));
		end
		best = find(peek(:,7) == max(peek(:,7)));
		if length(best) > 1
			best = best(1)
		end
		Q_max_peek = peek(best,7);
		reward = 2 * peek(best,2) -1;
		Q_update_val = Q_cur + learning_rate * ( reward + discount * Q_max_peek - Q_cur)
		Qupdate(Q_update_val,state{1}.movement,state{1}.shift,state{1}.IOU,state{2}.movement,state{2}.shift,state{2}.IOU,movement,shift)
		state{1} = state{2};
		state{2} = state{3};

		new_crop = peek(best,3:6);

    end

end
