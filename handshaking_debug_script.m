
situation = 'handshaking';

switch situation
    
    case 'handshaking'
        
        data_fn = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/lefthandshakeright_cnn_features_and_IOUs2017.10.24.15.11.40.mat';
        im_path = '/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/';
        iou_est_model_fn = '/Users/Max/Dropbox/Projects/situate/default_models/lefthandshakeright, IOU ridge regression, 1.mat';
        adjust_model_fn  = '/Users/Max/Dropbox/Projects/situate/default_models/lefthandshakeright, box_adjust_two_tone, 0.mat';
        
    case 'dogwalking'
        
        data_fn = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/dogwalking cnn_features_and_IOUs.mat';
        im_path = '/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/';
        iou_est_model_fn = '/Users/Max/Dropbox/Projects/situate/default_models/dogwalkerdogleash, IOU ridge regression, 0.mat';
        adjust_model_fn  = '/Users/Max/Dropbox/Projects/situate/default_models/dogwalkerdogleash, box_adjust_two_tone, 0.mat';
     
    case 'handshaking_unsided'
   
        data_fn = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/handshaking_alt_labels cnn_featuers_and_IOUs.mat';
        im_path = '/Users/Max/Documents/MATLAB/data/situate_images/Handshaking_train/';
        iou_est_model_fn = '/Users/Max/Dropbox/Projects/situate/default_models/participant1handshakeparticipant2, IOU ridge regression, 0.mat';
        adjust_model_fn  = '/Users/Max/Dropbox/Projects/situate/default_models/participant1handshakeparticipant2, box_adjust_two_tone, 0.mat';
     
        
end

data = load(data_fn);
p = situate.parameters_initialize;
iou_est_model = [];
iou_est_model.model = load(iou_est_model_fn);
iou_est_model.apply = @classifiers.IOU_ridge_regression_apply;

adjustment_model = [];
adjustment_model.model = load(adjust_model_fn);
adjustment_model.model.model_selection_threshold = .5;
adjustment_model.apply = @box_adjust.two_tone_apply;
situation_objects = iou_est_model.model.classes;




%% retrain the classifiers

    retrain_classifiers = false;
    
    if retrain_classifiers

        b = cell(1,length(situation_objects));
        for oi = 1:length(situation_objects)
            cur_rows = eq( data.box_source_obj_type, oi );
            x = data.box_proposal_cnn_features(cur_rows,:);
            y = data.IOUs_with_each_gt_obj(cur_rows,oi);
            b{oi} = ridge( y, x, 1000, 0);
            progress(oi,length(situation_objects));
        end
       
    else
        
        b = cell(1,length(situation_objects));
        for oi = 1:length(situation_objects)
            b{oi} = iou_est_model.model.models{oi};
        end
        
    end
    
    
    
%% get iou ests

    x = data.box_proposal_cnn_features;
    iou_est = cell(1,length(situation_objects));
    for oi = 1:length(situation_objects)
        iou_est{oi} = [ones(size(x,1),1) x] * b{oi};
    end
    
    
    
%% view classifier quality (est iou vs gt iou)

    figure
    for oi = 1:length(situation_objects)
        subplot(1,length(situation_objects),oi);
        hist( iou_est{oi}, 20 );
        title(situation_objects{oi});
    end

    figure
    for oi = 1:length(situation_objects)
        cur_rows = eq( data.box_source_obj_type, oi );
        subplot(1,length(situation_objects),oi);
        plot( data.IOUs_with_each_gt_obj(cur_rows,oi), iou_est{oi}(cur_rows), '.' );
        title(situation_objects{oi});
        xlabel('gt iou');
        ylabel('est iou');
    end


%% take a look at box adjust quality

    old_ious = [];
    new_ious = [];
    obj_type = [];
    
    imi_inds = unique(data.fname_source_index);
    
    for imii = 1:length(imi_inds)
    imi = imi_inds(imii);
    cur_image_rows = eq( imi, data.fname_source_index );
    for oi = 1:length(situation_objects)
    cur_obj_rows = eq( oi, data.box_source_obj_type );
    
        cur_rows = find( cur_image_rows & cur_obj_rows );
            
            for bi = 1:length(cur_rows)
                
                cur_row = cur_rows(bi);
                
                cur_cnn_features = data.box_proposal_cnn_features(cur_row,:);

                dummy_agent_initial = situate.agent_initialize();
                dummy_agent_initial.box.r0rfc0cf = data.box_proposals_r0rfc0cf(cur_row,:);
                dummy_agent_initial.interest = situation_objects{oi};
                dummy_agent_initial.support.internal = [1 cur_cnn_features] * b{oi};
                
                [ ~, adjusted_box_r0rfc0cf ] = adjustment_model.apply( adjustment_model.model, dummy_agent_initial, [], [], cur_cnn_features );
                
                old_iou = data.IOUs_with_source(cur_row);
                new_iou = intersection_over_union( adjusted_box_r0rfc0cf, data.box_sources_r0rfc0cf(cur_row,:), 'r0rfc0cf','r0rfc0cf' );
               
                old_ious(end+1) = old_iou;
                new_ious(end+1) = new_iou;
                obj_type(end+1) = oi;
                
                if old_iou > .5
                    display('here');
                end
                
            end
            
    end
    progress(imii,length(imi_inds));
    end
    






















