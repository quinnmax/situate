

%data_fname = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/dogwalking cnn_features_and_IOUs.mat';
%data_fname = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/handshaking cnn_features_and_IOUs.mat';
data_fname = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/pingpong cnn_features_and_IOUs.mat';
data = load(data_fname);

objects = data.object_labels;

model_directory = '/Users/Max/Dropbox/Projects/situate/default_models/';

model_fname = situate.check_for_existing_model( model_directory, 'model_description', 'IOU ridge regression','classes', objects ); 
assert( ~isempty(model_fname) && exist(model_fname,'file') );
models_struct = load(model_fname);

num_boxes = size(data.box_proposal_cnn_features, 1);
internal_support = zeros( num_boxes, length(objects) );

for oi = 1:length(objects)
    internal_support(:,oi) = [ ones(num_boxes,1) data.box_proposal_cnn_features ] * models_struct.models{oi};
end

IOU_high = data.IOUs_with_source > .5;

% internal support distributions
figure;
for oi = 1:length(objects)
    subplot(1,length(objects),oi);
    hist( internal_support(:,oi), 50);
    title(objects{oi});
end

% relationship between threshold and TPR
figure;
for oi = 1:length(objects)
    subplot2(2,length(objects),1,oi);
    inds_for_cur_obj = data.box_source_obj_type == oi;
    [AUROC, TPR, FPR, thresholds] = ROC( internal_support(inds_for_cur_obj,oi), IOU_high(inds_for_cur_obj) );
    plot(FPR,TPR);
    legend(num2str(AUROC));
    xlabel('FPR');
    ylabel('TPR');
    title(objects{oi});
    
    subplot2(2,length(objects),2,oi);
    plot(thresholds,TPR);
    xlabel('thresholds');
    ylabel('TPR');
    xlim([0 1]);
end



% relationship between threshold and local p
figure;
for oi = 1:length(objects)
    subplot2(1,length(objects),1,oi);
    
    inds_for_cur_obj = data.box_source_obj_type == oi;
    cur_internal = internal_support(inds_for_cur_obj,oi);
    cur_high_iou = IOU_high(inds_for_cur_obj);
    [~,sort_order] = sort(cur_internal,'ascend');
    [ x_mu, x_var, x_sig ] = local_stat( double(cur_high_iou(sort_order))',round(length(sort_order)/20));
    
    plot( cur_internal(sort_order), x_mu );
    xlabel('internal support');
    ylabel('P(gt IOU > .5)');
    title(objects{oi});
    
end




% max internal support over images
im_inds = unique(data.fname_source_index);
num_images = length(im_inds);
max_internal_support_per_image = zeros(num_images,length(objects));
for oi = 1:length(objects)
for imi = 1:num_images
    cur_im_ind = im_inds(imi);
    cur_box_inds = eq(cur_im_ind,data.fname_source_index);
    max_internal_support_per_image(imi,oi) = max(internal_support( cur_box_inds & IOU_high, oi) );
end
end

figure;
for oi = 1:length(objects)
    subplot(1,length(objects),oi);
    hist(max_internal_support_per_image(:,oi));
    xlabel('max internal support in image');
    title(objects{oi});
    xlim([0 1.1])
end


% include IOU with each gt object for all box proposals
oi_inds = zeros( size(data.box_source_obj_type,1), length(objects) );
for oi = 1:length(objects)
    oi_inds(:,oi) = eq( oi, data.box_source_obj_type );
end
IOUs_with_each_gt_obj = zeros( size(data.box_source_obj_type,1), length(objects) );
imi_list = unique(data.fname_source_index);
for imii = 1:length(imi_list)
    imi = imi_list(imii);
    cur_im_inds = eq(imi, data.fname_source_index);
    for oi = 1:length(objects)
        cur_im_ob_inds = cur_im_inds & oi_inds(:,oi);
        cur_gt_box = data.box_sources_r0rfc0cf( find( cur_im_ob_inds, 1, 'first' ), : );
        IOUs_with_each_gt_obj(cur_im_inds,oi) = intersection_over_union( cur_gt_box, data.box_proposals_r0rfc0cf(cur_im_inds,:), 'r0rfc0cf', 'r0rfc0cf' );
    end
    fprintf('.');
end

data.IOUs_with_each_gt_obj = IOUs_with_each_gt_obj;

% classifier scores for all the boxes for all the types
internal_support_all_obj_types = zeros( size(data.box_source_obj_type,1), length(objects) );
for oi = 1:length(objects)
    internal_support_all_obj_types(:,oi) = [ones(num_boxes,1) data.box_proposal_cnn_features] * models_struct.models{oi};
end

% do some ROC analysis with all these extra boxes
figure();
AUROC = zeros(1,length(objects));
for oi = 1:length(objects)
    
    label = IOUs_with_each_gt_obj(:,oi) > .5;
    score = internal_support_all_obj_types(:,oi);
    [AUROC(oi), TPR, FPR, thresholds] = ROC( score, label );
    
    subplot(1,length(objects),oi);
    plot(FPR,TPR);
    legend(num2str(AUROC(oi)));
    title(objects{oi});
    
end

% save(data_fname,'-struct','data','-v7.3');







