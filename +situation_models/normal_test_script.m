function parameter_model = model_situation_parameters( )

    % set up situate parameters and set up situation
    p = situate.parameters_initialize();
    situation = situate.situation_definitions;
    situation = situation.('dogwalking');
    p.situation_objects = situation.situation_objects;
    p.situation_objects_possible_labels = situation.situation_objects_possible_labels;
    path_ind = find( cellfun(@isdir, situation.possible_paths), 1, 'first' );
    path = situation.possible_paths{path_ind};
    
    p.situation_model_learn  = @situation_model_normal_fit;
    %p.situation_model_sample = @situation_model_normal_rc_sample;
    p.situation_model_sample = @situation_model_normal_aa_sample;
    p.situation_model_update = @situation_model_normal_condition;
    
    % build the prior based on the trainingdata path
    situation_model_prior = p.situation_model_learn( p, path );
    
    % look at some samples from the prior
    n = 20;
    figure; 
    for oi = 1:length(p.situation_objects)
        cur_obj = p.situation_objects{oi};
        sampled_boxes_r0rfc0cf = p.situation_model_sample( situation_model_prior, cur_obj, n );
        subplot(1,length(p.situation_objects),oi)
        draw_box([-.5 .5 -.5 .5], 'r0rfc0cf', 'k--');
        xlim([-.75 .75]); ylim([-.75 .75]);
        hold on;
        draw_box(sampled_boxes_r0rfc0cf,'r0rfc0cf');
        title(cur_obj);
    end
    
    % look at full situation samples
    n = 12;
    figure;
    for ni = 1:n
        cur_sample_r0rfc0cf = p.situation_model_sample( situation_model_prior, 1 );
        subplot_lazy(n,ni);
        draw_box([-.5 .5 -.5 .5], 'r0rfc0cf', 'k--');
        xlim([-.75 .75]); ylim([-.75 .75]);
        hold on;
        for oi = 1:length(situation_model_prior.situation_objects)
            cur_box_r0rfc0cf = cur_sample_r0rfc0cf( ((oi-1)*4+1) : oi*4 );
            draw_box(cur_box_r0rfc0cf,'r0rfc0cf');
        end
    end

    
    
figure
reps = 12;
for rep = 1:reps
    
    % make up a workspace
    cur_sample_r0rfc0cf = p.situation_model_sample( situation_model_prior, 1 );
    obj_boxes = zeros(0,4);
    for oi = 1:length(situation_model_prior.situation_objects)
        cur_obj_inds = (oi-1)*4 + 1 : oi * 4;
        obj_boxes(oi,:) = cur_sample_r0rfc0cf(cur_obj_inds);
    end
    sampled_dogwalker = obj_boxes(1,:);
    sampled_dog = obj_boxes(2,:);
    sampled_leash = obj_boxes(3,:);
    
    workspace = [];
%     workspace.boxes.r0rfc0cf = [sampled_dogwalker; sampled_dog];
%     workspace.labels = {'dogwalker','dog'};

%     workspace.boxes.r0rfc0cf = [sampled_dog; sampled_leash];
%     workspace.labels = {'dog','leash'};

    workspace.boxes.r0rfc0cf = [sampled_dogwalker; sampled_leash];
    workspace.labels = {'dogwalker','leash'};


    % make a conditional model for an object
    target_obj = setdiff(situation_model_prior.situation_objects,workspace.labels);
    target_obj = target_obj{1};
    situation_model_conditioned = p.situation_model_update( situation_model_prior, target_obj, workspace );
    
    % display workspace and some samples from the conditioned distribution
    sampled_conditional_boxes_r0rfc0cf = p.situation_model_sample( situation_model_conditioned, target_obj, 10 );
    subplot_lazy(reps,rep);
    draw_box([-.5 .5 -.5 .5], 'r0rfc0cf', 'k--');
    xlim([-.75 .75]); ylim([-.75 .75]);
    hold on
    draw_box( sampled_conditional_boxes_r0rfc0cf, 'r0rfc0cf', 'blue' );
    draw_box( sampled_dog, 'r0rfc0cf', 'red' );
    draw_box( sampled_dogwalker, 'r0rfc0cf', 'red' );
    
end
    
end


    
    
    
        
        
        
    
    
    
    
    
    