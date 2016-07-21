function [fin_crop,fin_iou,fin_moves] = crop_check(hf,base_image,object_class,label,starting_box,alotted_tries,starting_IOU)
%% sub function that returns a new crop and new iou for comparison
save('/u/eroche/matlab/base_image.mat','base_image');
disp(object_class)
save('/u/eroche/matlab/ground_truth.mat','label');
disp(starting_box)
disp(starting_IOU)
% if ~exist('cnn_svm_model','var')
%     load(strcat('/stash/mm-group/evan/crop_learn/models/svm_',object_class,'.mat'),'svm_model');
%     cnn_svm_model = svm_model;
% end 

% %%set up CNN
% if ~exist('net','var')
%     global net layer;
%     here = pwd;
%     cd '/u/eroche/matlab/cnn/matconvnet-1.0-beta20/';
%     disp('Starting MatConvNet');
%     run matlab/vl_setupnn;
%     net = vl_simplenn_tidy(load('imagenet-vgg-f.mat'));
%     layer = 18;
%     net.layers = net.layers(1:layer);
%     cd (here);
% end
%%Read files
if strcmp(object_class,'dog') == 1
    idx = find(label.is_dog == 1);
    orig_box = label.boxes(idx,:);
elseif strcmp(object_class,'walker') == 1
    idx = find(label.is_ped == 1);
    orig_box = label.boxes(idx,:);
elseif strcmp(object_class,'leash') == 1
    idx = find(label.is_leash ==1);
    orig_box = label.boxes(idx,:);
end
    
total_moves = [];
final_IOU = {};
IOU_idx = 1;

base255 = im2uint8(base_image);
I = base255;
B = insertShape(I,'Rectangle',orig_box,'Color','red','LineWidth',5);
B2 = insertShape(B,'Rectangle',starting_box,'Color','blue','LineWidth',3);

start_crop = imcrop(base255,starting_box);
%%
class_guess = predict_crop(start_crop);
%initialize movement parameters
a = 0.4;
b = 0.5;
r = (b-a).*rand(4,1)+a; %primary shift between 0.4 and 0.5
if strcmp(object_class,'walker') == 1
    r = r/2;
end
r3 = r;

ratio_min = -0.15;%range for randomized secondary shift
ratio_max = 0.15;
loop_scale = 0.2; %shift factor for the detection loop
new_w = 0; % dummy variable
new_h = 0;
fli = 1;
loop_count = 0; %increment for Up Down Left Right
total_count = 0;
crop = starting_box;
run_IOU = [starting_IOU];
%% Detetection Loop
fin_crop = [];
fin_iou = 0;
fin_moves = 9;

hf = figure('Selected','on')
for ii = 1:9 
    rng('shuffle');
    r4 = (ratio_max-ratio_min).*rand(4,1)+ratio_min;
    name = decode(class_guess)
    move_amount = r3(1);
    x2 = crop(1); y2 = crop(2); w2 = crop(3); h2 = crop(4);
    bnew_w = w2*(1+loop_scale);
    bnew_h = h2*(1+loop_scale);
    snew_w = w2*(1-loop_scale);
    snew_h = h2*(1-loop_scale);

    old_IOU = bboxOverlapRatio(crop,orig_box);
    previous = crop;
    if class_guess == 0;
        break
    elseif class_guess == 1
        crop = up(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);
        loop_count = loop_count + 1;                
        r3 = r3-0.05;
    elseif class_guess == 2
        crop = down(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);
        loop_count = loop_count + 1;
        r3 = r3-0.05;
    elseif class_guess == 3
        crop = right(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);
        loop_count = loop_count + 1;
        r3 = r3-0.05;
    elseif class_guess == 4
        crop = left(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);
        loop_count = loop_count + 1;  
        r3 = r3-0.05;                  
    elseif class_guess == 5
        crop = expand(x2,y2,w2,h2,r3,r4,fli,bnew_w,bnew_h);
        loop_scale = loop_scale - 0.05;
    elseif class_guess == 6
        crop = shrink(x2,y2,w2,h2,r3,r4,fli,snew_w,snew_h);
        loop_scale = loop_scale - 0.05;
    end
    
    new_crop = imcrop(base255,crop);
    IOU = bboxOverlapRatio(crop,orig_box);
    run_IOU = [run_IOU IOU];
%%
    B3 = insertShape(B2,'Rectangle',previous,'Color','green','LineWidth',3);
    B4 = insertShape(B3,'Rectangle',crop,'Color','yellow','LineWidth',3);
    positions = [1 1; 1 25; 1 50; 1 75; 1 100; 1 125; 250 1; 250 25];
    values = {'previous',strcat('IOU: ',num2str(old_IOU)),name,strcat('move_amount: ',num2str(move_amount)),...
    strcat('loop_scale:',num2str(loop_scale)),num2str(total_count),'current',num2str(IOU)};
    B5 = insertText(B4,positions,values,'AnchorPoint','LeftTop','FontSize',18);
%%               
    total_count = total_count +1; 
    class_guess = predict_crop(new_crop);

    if class_guess == 7
%%                   
        B6 = insertShape(B5,'Rectangle',crop,'Color','magenta','LineWidth',7);
        hf, imshow(B6);
%%
        total_moves = [total_moves total_count];
        final_IOU = IOU;
        IOU_idx = IOU_idx + 1;
        loop_scale = 0.2;
        r_f = crop(2) + crop(4) - 1;
        c_f = crop(1) + crop(3) - 1;
        fin_crop = [crop(2) r_f crop(1) c_f];
        fin_iou = IOU
        fin_moves = total_count
        k = waitforbuttonpress;
        close
        break
    else
        hf, imshow(B5);
    end
    
    if loop_scale < 0.05
        loop_scale = 0.2;
    end
    if loop_count == 4
        r3 = r;
        loop_count = 0;
        if strcmp(object_class,'walker') == 1
            crop(3) = crop(3)*(r4(2)+1.3);
            crop(4) = crop(3)*2
        else
            crop(3) = crop(3)*(r4(2)+1.3);
            crop(4) = crop(3);
        end
    end
    k = waitforbuttonpress;
    if ii == 9
        close
    end
end 
                        
end