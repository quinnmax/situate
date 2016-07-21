% function [] = cropper(fnames)
% make crop directories: rewrites at each call
    fnames = '/u/eroche/dog_other_full.txt';
    Path = '/stash/mm-group/evan/crop_learn/data/dog-other/';
    rng('shuffle');
    % imgType = '*.jpg'; 
    % labelType = '*.labl';
    % imgFolder  = dir(fullfile(Path,imgType));
    % labelFolder = dir(fullfile(Path,labelType)); 
    % len_folder = length(imgFolder);
    label_list = dataread('file',fnames,'%s','delimiter','\n')
    % end2 = textscan(fnames,'%s','delimiter','_')
    % split_type = strrep(end2{1}{4},'.txt','')
    split_type = 'train';
    
    len_list = length(label_list);
    % training_split = 0.8;
    % a = 0.0; %range for translation, proportional to original bounding box
    % b = 1.0;
    % split = (b-a).*rand(len_folder,1)+a; 

%     here = pwd;
%     cd '/stash/mm-group/evan/crop_learn/data/croptest/'
%     rmdir(split_type,'s');
%     mkdir(split_type);
%     cd (split_type);
% 
%     mkdir('dog','down');
%     mkdir('dog','up');
%     mkdir('dog','left');
%     mkdir('dog','right');
%     mkdir('dog','shrink');
%     mkdir('dog','expand');
%     mkdir('dog','orig');
%     mkdir('dog','background');
% 
%     mkdir('walker','down');
%     mkdir('walker','up');
%     mkdir('walker','left');
%     mkdir('walker','right');
%     mkdir('walker','shrink');
%     mkdir('walker','expand');
%     mkdir('walker','orig');
%     mkdir('walker','background');
% 
%     mkdir('leash','down');
%     mkdir('leash','up');
%     mkdir('leash','left');
%     mkdir('leash','right');
%     mkdir('leash','shrink');
%     mkdir('leash','expand');
%     mkdir('leash','orig');
%     mkdir('leash','background');
%     cd (here);

    if ~exist('record','var')
    for i = 64:len_list
        image_path = strcat(Path,strrep(label_list(i),'.labl','.jpg'));
        images{i} = imread(image_path{1});
        label_list(i) = strrep(label_list(i),'.jpg','.labl');
        temp = fopen(fullfile(Path,label_list{i}));
        temp2 = textscan(temp,'%s','delimiter','|');
        temp2{1} = strrep(temp2{1},'/','');
        temp2{1} = strrep(temp2{1},' ','-');
        record(i).id = i;
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


    for i = 64:len_list%cropping
        disp(i)
        if strcmp(split_type,'train') == 1
            folder = '/stash/mm-group/evan/crop_learn/data/croptest/train/';
        elseif strcmp(split_type,'test') == 1
            folder = '/stash/mm-group/evan/crop_learn/data/croptest/test/';
        end
        num_objects = record(i).num_obs;
        baseFile = num2str(i);
        for k = 1:num_objects
        box = strcat('obj',num2str(k),'_bbox');
            x = record(i).(box)(1);
            y = record(i).(box)(2);
            w = record(i).(box)(3);
            h = record(i).(box)(4);
            boxes{k} = [x y w h];
        end
        for k = 1:num_objects
            ob_num = strcat('obj',num2str(k));
            ob_name = record(i).(ob_num);
            gen = strsplit(ob_name,'-');
            ob_name = strcat('op_',ob_name);

%             if strcmp(gen{1},'leash') == 1
%                 object = 'leash/';
            if strcmp(gen{1},'dog') == 1
                idx = 0;
                object = 'dog/';
%                 if strcmp(gen{2},'walker') == 1
%                     idx = 1;
%                     object = 'walker/';
%                 end
                % if strcmp(gen{2+idx},'front') == 1
                %     ori = 'front/';
                % elseif strcmp(gen{2+idx},'back') == 1
                %     ori = 'back/' ;
                % elseif strcmp(gen{3+idx},'right') == 1
                %     ori = 'right/';
                % elseif strcmp(gen{3+idx},'left') == 1
                %     ori = 'left/';
                % end 
            else 
                continue
            end
            
            box = strcat('obj',num2str(k),'_bbox');
            x = record(i).(box)(1);
            y = record(i).(box)(2);
            w = record(i).(box)(3);
            h = record(i).(box)(4);

            %% generate 6 background crops per object on first parameter run
            background_cropper(i,object,images{i},x,y,w,h,folder,boxes)
            scale_factor = [0.3 0.4 0.5 0.6 0.7 0.8];
            orig_factor = [0 0.05 0.1 -0.05 -0.1 -0.15];
            fli = [0 1 -1 0 1 -1];
            big_switch = [0 0 0 1 1 1];
            for ii = 1:6
                a = 0.3;
                b = 0.5;
                if big_switch(ii) == 0
                    a = 0.3;
                    b = 0.5;
                    shift_size = '-small';
                elseif big_switch(ii) == 1   
                    a = 0.5; %range for translation, proportional to original bounding box
                    b = 0.7;
                    shift_size = '-big';
                end
                c = 0.1; %optional secondary shift 
                d = 0.2;
                r = (b-a).*rand(4,1)+a; 
                r2 = (d-c).*rand(4,1)+c;

                if fli(ii) == 0
                    neg = '';
                elseif fli(ii) == 1
                    neg = '-n';
                elseif fli(ii) == -1
                    neg = '-p';
                end
                    
                detail = strcat(shift_size,neg);
                detail1 = strcat('-',num2str(scale_factor(ii)));
                detail2 = strcat(neg,'-',num2str(orig_factor(ii)));

                rightcrop = imcrop(images{i},[x+(w*r(1)),y+(h*r2(1)*fli(ii)),w,h]);
                leftcrop = imcrop(images{i},[x-(w*r(2)),y+(h*r2(2)*fli(ii)),w,h]);
                downcrop = imcrop(images{i},[x+(w*r2(3)*fli(ii)),y+(h*r(3)),w,h]);
                upcrop = imcrop(images{i},[x+(w*r2(4)*fli(ii)),y-(h*r(4)),w,h]);

                big_w = w*(1+scale_factor(ii));
                big_h = h*(1+scale_factor(ii));
                small_w = w*(1-scale_factor(ii));
                small_h = h*(1-scale_factor(ii));
                orig_w = w*(1+orig_factor(ii));
                orig_h = h*(1+orig_factor(ii));

                origcrop = imcrop(images{i},[x+(w/2)-orig_w/2,y+(h/2)-orig_h/2,orig_w,orig_h]);
                expandcrop = imcrop(images{i},[x+(w/2)-big_w/2,y+(h/2)-big_h/2,big_w,big_h]);
                shrinkcrop = imcrop(images{i},[x+(w/2)-small_w/2,y+(h/2)-small_h/2,small_w,small_h]);

                expandname = fullfile(folder,strcat(object,'expand/',baseFile,'-',ob_name,'_s-expand',detail1,'.jpg'));
                shrinkname = fullfile(folder,strcat(object,'shrink/',baseFile,'-',ob_name,'_s-shrink',detail1,'.jpg'));
                origname = fullfile(folder,strcat(object,'orig/',baseFile,'-',ob_name,'_no-change',detail2,'.jpg'));
                downname = fullfile(folder,strcat(object,'down/',baseFile,'-',ob_name,'_t-down',detail,'.jpg'));
                upname = fullfile(folder,strcat(object,'up/',baseFile,'-',ob_name,'_t-up',detail,'.jpg'));
                rightname = fullfile(folder,strcat(object,'right/',baseFile,'-',ob_name,'_t-right',detail,'.jpg'));
                leftname = fullfile(folder,strcat(object,'left/',baseFile,'-',ob_name,'_t-left',detail,'.jpg'));         
                imwrite(origcrop,origname);
                imwrite(downcrop,downname);
                imwrite(upcrop,upname);
                imwrite(leftcrop,leftname);
                imwrite(rightcrop,rightname);  
                imwrite(expandcrop,expandname);
                imwrite(shrinkcrop,shrinkname);
            end
        end
    end

