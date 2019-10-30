
% for each object type, use the situation model
% for each image, generate 5000 box proposals from distribution (scaled to cur image)
% collect iou scores
%
% ratio of boxes with iou>.5
%   0.0015    0.0028    0.0034
%
% mean iou
%	0.0454    0.0289    0.0376
%
% ratio zero iou
%   0.5315    0.7384    0.6633
%


%%

data = load('/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/dogwalkerdogleash_cnn_features_and_IOUs2017.10.31.00.47.35.mat');
situation_model = load('/Users/Max/Dropbox/Projects/situate/saved_models/dogwalkerdogleash, normal situation model, 0.mat');

num_objs = numel(situation_model.situation_objects);

%% p of iou > .5, using situation model as source of samples

% get im areas
temp = situate.labl_load( fileparts_mq( data.fnames, 'path/name' ) );
im_ws = [temp.im_w]';
im_ws = im_ws( data.fname_source_index );
im_hs = [temp.im_h]';
im_hs = im_hs( data.fname_source_index );
im_areas = im_hs .* im_ws;

is_training_im = ismember( fileparts_mq( data.fnames, 'name'), situation_model.fnames_lb_train );

unique_gt_box_rows = argmax( (data.fname_source_index .* obj_rows) == find(is_training_im)' );
obj_gt_boxes_r0rfc0cf = data.box_sources_r0rfc0cf(unique_gt_box_rows,:);

num_ims = numel(unique_gt_box_rows);

% w = obj_gt_boxes_r0rfc0cf(:,4) - obj_gt_boxes_r0rfc0cf(:,3) + 1;
% h = obj_gt_boxes_r0rfc0cf(:,2) - obj_gt_boxes_r0rfc0cf(:,1) + 1;
% obj_area_ratios = (w.*h) ./ im_areas(unique_gt_box_rows);
% obj_aspect_ratios = w./h;

npi = 5000; % samples per image

ious_over_50 = nan(num_ims,num_objs);
mean_iou = nan(num_ims,num_objs);
zero_iou = nan(num_ims,num_objs);
sampled_ious_record = nan(num_ims,num_objs,npi);

for oi = 1:num_objs
    
    obj_rows = eq( oi, data.box_source_obj_type );
    
    for imi = 1:num_ims
        
        cur_gt_box_r0rfc0cf = obj_gt_boxes_r0rfc0cf(imi,:);
        cur_im_w = im_ws( unique_gt_box_rows( imi ) );
        cur_im_h = im_hs( unique_gt_box_rows( imi ) );
        
        sampled_r0rfc0cf = situation_models.normal_sample( situation_model, situation_model.situation_objects{oi}, npi, [cur_im_h cur_im_w]); 
        
        sampled_ious = intersection_over_union( sampled_r0rfc0cf, cur_gt_box_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
        
        ious_over_50(imi,oi) = mean(sampled_ious>=.5);
        mean_iou(imi,oi)     = mean(sampled_ious);
        zero_iou(imi,oi)     = mean(sampled_ious==0);
        sampled_ious_record(imi,oi,:) = sampled_ious;
        
        progress(imi,num_ims);
        
    end
    
end

%% make a figure



h = figure('color','white');
for oi = 1:num_objs
    
    cur_sample = sort(reshape(sampled_ious_record(:,oi,:),1,[]),'ascend');
    
    subplot(1,num_objs,oi)
    %hist( cur_sample, 100 );
    
    y = linspace(0,1,numel(cur_sample));
    plot(cur_sample,y,'.','MarkerSize',5)
    
    text_shift = [.03, .02];
    
    hold on;
    plot( 0, mean(cur_sample==0), '.r','MarkerSize',20 );
    text( 0+text_shift(1), mean(cur_sample==0)-text_shift(2), num2str(mean(cur_sample==0)) );
    
    plot( [.5 .5],[0, 1-mean(cur_sample>=.5) ],'--black')
    plot( .5, 1-mean(cur_sample>=.5), '.r','MarkerSize',20 );
    text( .5+text_shift(1), 1-mean(cur_sample>=.5) -text_shift(2), num2str(1-mean(cur_sample>=.5)) );
    hold off;
    
    
    
    xlabel('iou with ground-truth box');
    ylabel('cumulative density')
    title(situation_model.situation_objects{oi});
    
    fprintf('%s, ratio IOU==0: %f \n', situation_model.situation_objects{oi}, mean(cur_sample==0));
    fprintf('%s, mean  IOU:    %f \n', situation_model.situation_objects{oi}, mean(cur_sample));
    fprintf('%s, ratio IOU>.5: %f \n', situation_model.situation_objects{oi}, mean(cur_sample>=.5));
    
    
end
    







    
        
        
        
