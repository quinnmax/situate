object_class = 'walker'
Path = '/stash/mm-group/evan/crop_learn/data/PortlandNonProtoDogWalking';
rng('shuffle');
imgType = '*.jpg'; 
labelType = '*.labl';
imgFolder  = dir(fullfile(Path,imgType));
labelFolder = dir(fullfile(Path,labelType)); 
len_folder = length(imgFolder);
if ~exist('svm_model','var')
    load(strcat('/stash/mm-group/evan/crop_learn/models/svm_',object_class,'.mat'),'svm_model');
end 

%%set up CNN
global net layer; 
if 0 == 0
    cd '../../cnn/matconvnet-1.0-beta20/';
    disp('Starting MatConvNet');
    run matlab/vl_setupnn
    net = vl_simplenn_tidy(load('imagenet-vgg-f.mat'));
    layer = 18;
    net.layers = net.layers(1:layer);
    cd '../../crop/sequencer/'
    end
%%Read files
if ~exist('images','var')
    for i = 1:10 %Range of files to read in 
        images{i} = imread(fullfile(Path,imgFolder(i).name));
        temp = fopen(fullfile(Path,labelFolder(i).name));
        temp2 = textscan(temp,'%s','delimiter','|');
        temp2{1} = strrep(temp2{1},'/','');
        temp2{1} = strrep(temp2{1},' ','-');
        record(i).id = i; % read labl data into record
        record(i).width = str2num(temp2{1}{1});
        record(i).height = str2num(temp2{1}{2});
        num_objects = str2num(temp2{1}{3});
        record(i).num_obs = num_objects;
        for k = 1:num_objects
            ob_num = strcat('obj',num2str(k));
            bbox = strcat(ob_num,'_bbox');
            record(i).(ob_num) = temp2{1}{(num_objects*4)+3+k}; %get object name
            x = str2num(temp2{1}{4+((k-1)*4)}); %get bounding box
            y = str2num(temp2{1}{5+((k-1)*4)});
            w = str2num(temp2{1}{6+((k-1)*4)});
            h = str2num(temp2{1}{7+((k-1)*4)});
            record(i).(bbox) = [x y w h];
        end 
        fclose(temp);
    end
end

total_moves = [];
final_IOU = {};
IOU_idx = 1;

%% list is the pairs of translations that determine the starting points
list1 = {{'right','down'},{'right','up'},{'right','expand'},{'right','shrink'},...
{'left','down'},{'left','up'},{'right','expand'},{'right','shrink'},...
{'down','expand'},{'down','shrink'},{'up','expand'},{'up','shrink'}};

list2 = {{'right','down'},{'right','up'},...
{'left','down'},{'left','up'},{'right','expand'},...
{'up','shrink'}};

%%main sequence test loop
for i = 1:10%order of images to try
    disp(i);
    num_objects = record(i).num_obs;
    % generate starting crops 
    for k = 1:num_objects 
        ob_num = strcat('obj',num2str(k));
        ob_name = record(i).(ob_num);
        gen = strsplit(ob_name,'-');

%         if 
%             == 1 %determine which objects to look at
%             if strcmp('dog',gen{1}) == 1
%                 object = 'dog';
%                 if strcmp(gen{2},'walker') == 1
%                     continue
%                 end
%             else 
%                 continue
%             end
        if length(gen) > 1
            if strcmp(object_class,gen{2}) == 1
                object = object_class
            else 
                continue
            end
   
                
%         elseif strcmp(object_class,gen{1}) == 1
%             object = object_class;
        else 
            continue
        end
        
        %get bounding box
        box = strcat('obj',num2str(k),'_bbox');
        x = record(i).(box)(1);
        y = record(i).(box)(2);
        w = record(i).(box)(3);
        h = record(i).(box)(4);
        scale_factor = 0.4; %translate by percent of relevant bounding box dimension 
        a = 0.4; %range for randomized primary shift
        b = 0.5;
        c = -0.15; %range for randomized secondary shift 
        d = 0.15;
        r = (b-a).*rand(4,1)+a; %use this for randomized starting crops
        r2 = (d-c).*rand(4,1)+c;
        % r = [0.4 0.4 0.4 0.4]; %constant primary shift
        fli = 1; %set to 0 for NO secondary shift, 1 for postive secondary shift, -1 for negative
        big_w = w*(1+scale_factor);
        big_h = h*(1+scale_factor);
        small_w = w*(1-scale_factor);
        small_h = h*(1-scale_factor);

        orig_box = [x y w h]; %ground truth

        flag = 0; %for going to next image

        %% Loop through different starting positions
        start_list = list2; % decide which list to use
        for j = 1:numel(start_list)
            if flag == 1;
                break
            end
            rng('shuffle');
            e = 0.5; f = 1.5;
            r5 = (f-e).*rand(4,1)+e; %slight change of starting crop aspect ratio
            % r5 = [1 1 1 1] %uncomment for no change
            
            I = images{i};
            B = insertShape(I,'Rectangle',orig_box,'Color','red','LineWidth',5);

            first = start_list{j}{1};
            fh = str2func(first);
            seco = start_list{j}{2};
            fh2 = str2func(seco);

%% Apply the two transformations
            if strcmp(first,'shrink') == 1
                temp = fh(x,y,w,h,r,r2,fli,small_w,small_h);
            else
                temp = fh(x,y,w,h,r,r2,fli,big_w,big_h);
            end
            x1 = temp(1); y1 = temp(2); w1 = temp(3); h1 = temp(4);
            if strcmp(seco,'shrink') == 1
                crop = fh2(x1,y1,w1*r5(1),h1*r5(2),r,r2,fli,small_w,small_h);
            else
                crop = fh2(x1,y1,w1*r5(3),h1*r5(4),r,r2,fli,big_w,big_h);
            end
            %Starting crop is blue box

            B2 = insertShape(B,'Rectangle',crop,'Color','blue','LineWidth',3);

            start_crop = imcrop(images{i},crop);
%%
            class_guess = predict_crop(svm_model,start_crop);
            %initialize movement parameters
            r3 = (b-a).*rand(4,1)+a; %primary shift between 0.4 and 0.5
            if strcmp(object_class,'walker') == 1
                r3 = r3/2
            end
            ratio_min = -0.05;%range for randomized secondary shift
            ratio_max = 0.1;
            loop_scale = 0.2; %shift factor for the detection loop
            new_w = 0; % dummy variable
            new_h = 0;
            loop_count = 0; %increment for Up Down Left Right
            total_count = 0;
            start_IOU = bboxOverlapRatio(orig_box,crop);
            r3 = (b-a).*rand(4,1)+a; %primary shift between 0.4 and 0.5
            if strcmp(object_class,'walker') == 1
                r3 = r3/2
            end

            run_IOU = [start_IOU];
%% Detetection Loop
            while class_guess ~= 7; 
                rng('shuffle');
                r4 = (ratio_max-ratio_min).*rand(4,1)+ratio_min; 

                name = decode(class_guess);
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
                elseif class_guess == 8;
                    crop = expand(x2,y2,w2,h2,r3,r4,fli,w2*1.4,h2*1.4);    
                end
           
                new_crop = imcrop(images{i},crop);
                IOU = bboxOverlapRatio(crop,orig_box);
                run_IOU = [run_IOU IOU];
%%
                B3 = insertShape(B2,'Rectangle',previous,'Color','green','LineWidth',3);
                B4 = insertShape(B3,'Rectangle',crop,'Color','yellow','LineWidth',3);
                positions = [1 1; 1 45; 1 90; 1 135; 1 180; 1 225; 250 1; 250 45];
                values = {'previous',strcat('IOU: ',num2str(old_IOU)),name,strcat('move_amount: ',num2str(move_amount)),...
                strcat('loop_scale:',num2str(loop_scale)),num2str(total_count),'current',num2str(IOU)};
                B5 = insertText(B4,positions,values,'AnchorPoint','LeftTop','FontSize',30);
%%               
                total_count = total_count +1; 
                class_guess = predict_crop(svm_model,new_crop);
                if class_guess == 7
%%                   
                    B6 = insertShape(B5,'Rectangle',crop,'Color','magenta','LineWidth',7);
                    imshow(B6);
%%
                    total_moves = [total_moves total_count];
                    final_IOU{IOU_idx} = run_IOU;
                    IOU_idx = IOU_idx + 1;
                    loop_scale = 0.2;
                    k = waitforbuttonpress;
                    if k == 0
                        flag = 1;
                        break 
                    else
                        continue  
                    end


                else
                    imshow(B5);
                end
                
                if loop_scale < 0.05
                    loop_scale = 0.2;
                end
                if loop_count == 6
                    r3 = r;
                    loop_count = 0;
                    if strcmp(object_class,'dog') == 1
                        crop(3) = crop(3)*(r4(2)+1.3);
                        crop(4) = crop(3);
                    elseif strcmp(object_class,'walker') == 1
                        crop(3) = crop(3)*(r4(2)+1.3);
                        crop(4) = crop(3)*2
                    end
                end
                if total_count == 30; %gives up after X tries
                    break
                end
                
                k = waitforbuttonpress;
                if k == 0
                    flag = 1;
                    break  
                end
            end 
                             
        end

    end
end
save('res_counts.mat','final_IOU','total_moves');
