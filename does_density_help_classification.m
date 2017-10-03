


fn = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/dogwalking cnn_features_and_IOUs.mat';
data = load(fn);



%%

im_inds_train = 1:300;
im_inds_test  = 401:500;

box_inds_train = ismember( data.fname_source_index, im_inds_train );
box_inds_test  = ismember( data.fname_source_index, im_inds_test  );



%% train some classifiers

% at different external support levels, is the internal support more or less reliable?

aurocs_low_densities  = zeros(1,length(data.object_labels));
aurocs_high_densities = zeros(1,length(data.object_labels));
aurocs_all_densities  = zeros(1,length(data.object_labels));

aurocs_low_densities_total_support  = zeros(1,length(data.object_labels));
aurocs_high_densities_total_support = zeros(1,length(data.object_labels));
aurocs_all_densities_total_support  = zeros(1,length(data.object_labels));

b = cell(1,length(data.object_labels));

for oi = 1:length(data.object_labels)

    cur_obj_inds = eq( data.box_source_obj_type, oi );

    % make an iou predictor

    gt_iou_train = data.IOUs_with_source(cur_obj_inds & box_inds_train);
    cnn_features_train = data.box_proposal_cnn_features(cur_obj_inds & box_inds_train,:);
    k = 1000;
    b{oi} = ridge(gt_iou_train,cnn_features_train,k,0);
    
    progress(oi, length(data.object_labels), 'classifier training progress:');

end



%% 

% for each box in testing set box, we want gt iou with each object type, and predicted iou with each object
% type

% % we don't have the conditional probability of each object type given the other 2. only for the
% % boxes where it was the origin object
% 
% IOUs_with_each_gt_obj = data.IOUs_with_each_gt_obj(box_inds_test,:);
% predicted_IOUs_for_each_obj_type = zeros( size(IOUs_with_each_gt_obj) );
% 
% for oi = 1:length(data.object_labels)
%     predicted_IOUs_for_each_obj_type(:,oi) = [ones(sum(box_inds_test) , 1) data.box_proposal_cnn_features( box_inds_test, : )] * b{oi};
% end
    





for oi = 1:length(data.object_labels)
    
    cur_obj_inds = eq( data.box_source_obj_type, oi );
    
    % get predictions for test data
    gt_iou_test{oi} = data.IOUs_with_source(cur_obj_inds & box_inds_test);
    cnn_features_test = data.box_proposal_cnn_features(cur_obj_inds & box_inds_test,:);
    predicted_iou_test = [ones(size(cnn_features_test,1),1) cnn_features_test] * b{oi};
    
    all_class_classifications{oi}(:,oi) = predicted_iou_test;
    for oj = setsub(1:length(data.object_labels),oi)
        all_class_classifications{oi}(:,oj) = [ones(size(cnn_features_test,1),1) cnn_features_test] * b{oj};
    end

    % conditional densities
    conditional_densities = data.box_density_conditioned_2(cur_obj_inds & box_inds_test);
    
    original_seq = conditional_densities;
    [sorted_seq, sort_order] = sort( original_seq );
    [~, sort_order_sort_order] = sort( sort_order );
    prctiles = linspace(0,1,length(original_seq));
    prctiles = prctiles( sort_order_sort_order );
    
    figure
    subplot(1,2,1); hist( conditional_densities, 50 );
    title(data.object_labels{oi});
    xlabel('conditional densities');
    subplot(1,2,2); plot( prctiles, conditional_densities, '.' );
    xlabel('data prctile'); ylabel('conditional densities');

    
    
    
    dummy_total_support = (.8 * predicted_iou_test) + (.2 * prctiles)';

    
    
    % how good is the classifier in general?
    aurocs_all_densities(oi) = ROC( predicted_iou_test >= .5, gt_iou_test{oi} >= .5 );
    
    % how good is the classifier with low density boxes?
    inds_low_density = conditional_densities < prctile(conditional_densities,25);
    aurocs_low_densities(oi) = ROC( predicted_iou_test(inds_low_density) >= .5,  gt_iou_test{oi}(inds_low_density) >= .5 );

    % how good is the classifier with high density boxes?
    inds_high_density = conditional_densities > prctile(conditional_densities,90);
    aurocs_high_densities(oi) = ROC( predicted_iou_test(inds_high_density) >= .5,  gt_iou_test{oi}(inds_high_density) >= .5 );
    
    
    
    % how good is the classifier in general?
    aurocs_all_densities_total_support(oi) = ROC( dummy_total_support >= .5, gt_iou_test{oi} >= .5 );
    
    % how good is the classifier with low density boxes?
    inds_low_density = conditional_densities < prctile(conditional_densities,25);
    aurocs_low_densities_total_support(oi) = ROC( dummy_total_support(inds_low_density) >= .5,  gt_iou_test{oi}(inds_low_density) >= .5 );

    % how good is the classifier with high density boxes?
    inds_high_density = conditional_densities > prctile(conditional_densities,90);
    aurocs_high_densities_total_support(oi) = ROC( dummy_total_support(inds_high_density) >= .5,  gt_iou_test{oi}(inds_high_density) >= .5 );

    
    
end










