global cnn_svm_model dog_svm_model walker_svm_model leash_svm_model cnn_net cnn_layer sub_counts;
if internal_support > p.internal_support_threshold
        if strcmp(interest,'person') == 1
            crop_object_class = 'walker';
        else
            crop_object_class = interest;
        end
        
        if strcmp(crop_object_class,'dog') == 1
            cnn_svm_model = dog_svm_model;
        elseif strcmp(crop_object_class,'walker') == 1
            cnn_svm_model = walker_svm_model;
        elseif strcmp(crop_object_class,'leash') == 1
            cnn_svm_model = leash_svm_model;
        end
        crop_start = agent_box_xywh;
        [new_guess_crop,new_guess_iou,new_guess_moves] = crop_check(hf,im,crop_object_class,im_label,...
            crop_start,6,internal_support);

        if new_guess_iou > internal_support
            bounding_box = new_guess_crop
            iou_score = new_guess_iou;
            disp('new guess wins')
            best_guess = 'new';
        else 
            bounding_box = agent_pool(agent_index).theta{3};
            iou_score = agent_pool(agent_index).theta{4}
            disp('original guess wins')
            best_guess = 'old';
        end 
        move_record = {best_guess,new_guess_moves}
        sub_counts = [sub_counts; move_record];
        save('/u/eroche/matlab/sub_counts.mat','sub_counts');
        agent_pool(end+1).type   = 'reviewer';
        agent_pool(end).interest = agent_pool(agent_index).interest;
        agent_pool(end).urgency  = p.agent_urgency_defaults.reviewer;
        agent_pool(end).theta{1} = iou_score; % internal support from calling scout
        agent_pool(end).theta{3} = bounding_box; % box bounds from calling scout
        agent_pool(end).theta{4} = interest;

        % agent_pool(end).theta{5} = orientation;
        % in the future, more info from the scout will probably need to
        % be passed along to the reviewer for the review process to be
        % reasonable (info like where the scout was looking)
    end