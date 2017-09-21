
Path = '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking';
%Path = '/home/evan/matlab/PortlandSimpleDogWalking';
rng('shuffle');
imgType = '*.jpg'; 
labelType = '*.labl';
imgFolder  = dir(fullfile(Path,imgType));
labelFolder = dir(fullfile(Path,labelType)); 
len_folder = length(imgFolder);


if ~exist('images','var')
    for i = 1:len_folder %Range of files to read in 
        images{i} = imread(fullfile(Path,imgFolder(i).name));
        image_list{i} = fullfile(Path,imgFolder(i).name);
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

list2 = {{'right','down'},{'right','up'},...
{'left','down'},{'left','up'},{'right','expand'},...
{'left','expand'},{'up','shrink'},{'down','shrink'}};

episodes = cell(12000,1);
ep_count = 1;

for i = 1:len_folder%order of images to try
    num_objects = record(i).num_obs;
    % generate starting crops 
    for k = 1:num_objects 
        ob_num = strcat('obj',num2str(k));
        ob_name = record(i).(ob_num);
        gen = strsplit(ob_name,'-');

        if length(gen) > 1%determine which objects to look at
            if strcmp('dog',gen{1}) == 1
                object = 'dog';
                if strcmp(gen{2},'walker') == 1
                    object = 'walker';
                end
            else 
                continue
            end
        % elseif length(gen) == 1
        % 	if strcmp('leash',gen{1}) == 1
        % 		object = 'leash';
        % 	else 
        % 		continue
        % 	end
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

            episodes{ep_count}.impath = image_list{i};
            episodes{ep_count}.object = object;
            episodes{ep_count}.ground = orig_box;
            episodes{ep_count}.start = crop;
            ep_count = ep_count + 1;  
            disp(ep_count);          
        end

    end
end
save('-v7.3','/u/eroche/matlab/episodes.mat','-struct','episodes');