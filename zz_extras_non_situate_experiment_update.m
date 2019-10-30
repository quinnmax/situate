
% looks at training data, generates workspaces based on gt boxes to see what the distribution of
% external support scores look like.

%% get data

% load structures

    % situation struct
    situation_struct = situate.situation_struct_load_all( );
    situation_struct = situation_struct.( 'dogwalking' );

    cur_params = situate.parameters_initialize_from_file( 'params_run/default.json' );
  
% split into training / testing sets

    experiment_file_fname = 'params_exp_rev/dogwalking_pos_check.json';
    experiment_struct = jsondecode_file( experiment_file_fname );
    [data_split_struct, fold_inds, experiment_settings_out] = situate.experiment_process_data_splits( experiment_struct.experiment_settings );

% load or generate cnn features

    existing_feature_directory = 'pre_extracted_feature_data';
    if ~exist(existing_feature_directory,'dir')
        mkdir(existing_feature_directory);
    end

    classes = situation_struct.situation_objects;
    fnames_in = data_split_struct.vision.fnames_lb_train;
    selected_datafile_fname = situate.check_for_existing_model( ...
        existing_feature_directory, ...
        'object_labels', classes,  @(a,b) isempty(setxor(a,b)), ...
        'fnames', fnames_in, @(a,b) all(ismember(fileparts_mq(a,'name'),fileparts_mq(b,'name'))) );

    if ~isempty(selected_datafile_fname)
        display(['loading cnn feature data from ' selected_datafile_fname]);
        existing_features_fname = selected_datafile_fname;
    else
        disp('extracting cnn feature data');
        existing_features_fname = cnn.feature_extractor_bulk( fileparts(fnames_in{1}), existing_feature_directory, situation_struct );
    end
    
    d = load( existing_features_fname );
  
    
%% get rows for training classifier

    % get indices for:
    %   training images
    %   high person iou

    %object_of_interst = 'dogwalker';
    object_of_interst = 'leash';
    % object of interest index (column)
    ooi_ind = find( strcmp( object_of_interst, d.object_labels ) ); 
    
    % rows based on object of interest
    is_ooi_row = eq( d.box_source_obj_type, ooi_ind);
    
    min_IOU_pos = .95;
    max_IOU_neg = .04;

    % filenames associated with each box in the data set
    fn_box_source = fileparts_mq( d.fnames, 'name' );
    
    % get training image rows
    fn_train_set = fileparts_mq( data_split_struct.vision(1).fnames_lb_train, 'name' );
    inds_training_images = find( ismember( fn_box_source, fn_train_set ) );
    is_training_row = ismember( d.fname_source_index, inds_training_images );

    % get high/low IOU rows
    is_high_IOU_row = d.IOUs_with_each_gt_obj(:,ooi_ind) >= min_IOU_pos;
    is_low_IOU_row  = d.IOUs_with_each_gt_obj(:,ooi_ind) <= max_IOU_neg;
    
    % get pos/neg training rows
    is_pos_train_row = logical( is_ooi_row .* is_training_row .* is_high_IOU_row );
    is_neg_train_row = logical( is_ooi_row .* is_training_row .* is_low_IOU_row );
    
    
    ooi_ious = d.IOUs_with_each_gt_obj(:,ooi_ind);
    % restrict to a single positive training row per image
    inds_train_pos = nan(length(inds_training_images),1);
    iou_val = nan(length(inds_training_images),1);
    for imii = 1:length(inds_training_images)
        imi = inds_training_images(imii);
        is_cur_im_row = eq( d.fname_source_index, imi );
        cur_im_ious = ooi_ious .* is_cur_im_row;
        inds_train_pos(imii) = argmax( cur_im_ious );
        iou_val(imii) = max(cur_im_ious);
    end
    
    is_pos_train_row(:) = false;
    is_pos_train_row(inds_train_pos) = true;
    
    
    
    
    display(['train count ' object_of_interst ' with IOU > ' num2str(min_IOU_pos) ': ' num2str(sum(is_pos_train_row))])
    display(['train count ' object_of_interst ' with IOU < ' num2str(max_IOU_neg) ': ' num2str(sum(is_neg_train_row))])
    
    row_inds_train = [ find(is_pos_train_row); find(is_neg_train_row) ];
    
% train the classifier
    
    % data and regression targets
    x = d.box_proposal_cnn_features( row_inds_train, : );
    y = [ ones(sum(is_pos_train_row),1); zeros(sum(is_neg_train_row),1) ];
    
    svm_model = fitcsvm(x,y);
    svm_model = svm_model.fitPosterior(); % outputs in 0,1
    svm_model = svm_model.compact(); % don't store training data in the obj
    
    [~,y_hat_temp] = svm_model.predict(x);
    scores_train = y_hat_temp(:,2);
    
    
    
    AUC_train = ROC( scores_train, y ); % 1 for this smallish set, meaning we're probably over-fitting
    
    figure;
    plot( y + .01*randn(size(y)), scores_train, '.' );
    xlabel('true class +noise')
    ylabel('predicted class')
    legend(num2str(AUC_train))
    axis([-.5,1.5,-.5,1.5])
    
% evaluate on validation crops

    % get testing rows
    fn_test_set = fileparts_mq( data_split_struct.vision(1).fnames_lb_test, 'name' );
    inds_testing_images = find( ismember( fn_box_source, fn_test_set ) );
    is_testing_row = ismember( d.fname_source_index, inds_testing_images );
    
    is_pos_test_row = logical( is_ooi_row .* is_testing_row .* is_high_IOU_row );
    is_neg_test_row = logical( is_ooi_row .* is_testing_row .* is_low_IOU_row );
    
    display(['test count ' object_of_interst ' with IOU > ' num2str(min_IOU_pos) ': ' num2str(sum(is_pos_test_row))])
    display(['test count ' object_of_interst ' with IOU < ' num2str(max_IOU_neg) ': ' num2str(sum(is_neg_test_row))])
    
    row_inds_test = [ find(is_pos_test_row); find(is_neg_test_row) ];
    
    % data and regression targets
    x_test = d.box_proposal_cnn_features( row_inds_test, : );
    y_test = [ ones(sum(is_pos_test_row),1); zeros(sum(is_neg_test_row),1) ];
    
    [~,y_hat_test_temp] = svm_model.predict(x_test);
    scores_test_1 = y_hat_test_temp(:,2);
    
    AUC_test = ROC( scores_test_1, y_test ); % 1 for this smallish set, meaning we're probably over-fitting
    
    [~,sort_order] = sort(scores_test_1);
    figure('color','white');
    plot([0 1],[0 1],'--black')
    hold on
    smoothing_width = round(numel(scores_test_1)/5);
    p_gtIOU_over_50 = local_stat(double(y_test(sort_order)>.5)',smoothing_width);
    plot( scores_test_1(sort_order), p_gtIOU_over_50,'.' );
    ylabel('P( IOU_{gt}(x) > .5 )')
    xlabel('classifier score(x)')
    
    
    figure;
    plot( y_test + .01*randn(size(y_test)), scores_test_1, '.' );
    xlabel('true class (+noise for visibility)')
    ylabel('prediction')
    legend(num2str(['AUC: ' num2str(AUC_test)]))
    axis([-.5,1.5,-.5,1.5])
    
    % AUC_test is .9988, so basically still perfect. thumbs up, good job. we made a good human/not
    % human classifier for this data set
    
%% visualize classifier output over an image
do_this = true;
situate.setup();
if do_this
    
    im = imread('/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/dog-walking402.jpg');
    chip_w = round(max(size(im)/10));
    step = round(max(size(im)/40));
    [ chips, source_coords ] = chipper( im, chip_w, step, 'cells' );
    cnn_vects = cell(size(chips,1),size(chips,2));
    
    for i = 1:numel(cnn_vects)
        cnn_vects{i} = cnn.cnn_process(chips{i});
        progress(i,numel(cnn_vects));
    end
    
    scores = nan(size(chips,1),size(chips,2));
    for i = 1:numel(cnn_vects)
        [~,temp] = svm_model.predict(cnn_vects{i}');
        scores(i) = temp(2);
        progress(i,numel(cnn_vects));
    end
   
    figure();
    subplot(1,2,1);
    imshow(scores,[])
    resized_map = imresize( scores, [size(im,1) size(im,2)], 'nearest' );
    resized_map = cat(3, resized_map, zeros(size(resized_map)), zeros(size(resized_map)) );
    subplot(1,2,2);
    imshow( mat2gray(im) + resized_map, [] );
    
    % non-max suppression
    y = local_max(scores,1,1,false);
    z = scores;
    z(scores ~= y) = 0;
    figure;
    subplot(1,3,1); imshow(scores,[]);
    subplot(1,3,2); imshow(y,[]);
    subplot(1,3,3); imshow(z,[]);
    
    %[~,sort_order] = sort(scores(:),'descend');
    [z_sorted,sort_order] = sort(z(:),'descend');
    source_coords_list = source_coords(:);
    source_coords_list = source_coords_list(sort_order);
    
    n = 8;
    figure('color','white');
    for i = 1:n
        if n>4
            subplot_lazy(n, i);
        else
            subplot(1,n,i);
        end
        r0 = source_coords_list{i}(1);
        rf = source_coords_list{i}(2);
        c0 = source_coords_list{i}(3);
        cf = source_coords_list{i}(4);
        imshow( im(r0:rf,c0:cf,:), [] );
        xlabel(['score: ' num2str(z_sorted(i))]);
    end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
end
    
    
%% look at hill climbing hypothesis
% for multiple images/boxes, is there a correlation between IOU and score?
% for multiple images/boxes, what is the probability that a box that looks better, actually is better?    
% for individual images, is there a correlation between IOU and score?
% for individual images, what is the probability that a box that looks better actuall is better?
%
% should it work in situate?
%       policy: generate x, all above y get eval, keep best
%       is the best from among several actually better than the origin?


%% for multiple images/boxes, is there a correlation between IOU and score?


% is it true for a a single image in the region of a target?
%
% took a sample of boxes of varying sizes and shapes (within reasonable bounds) from around objects of interest
% and sub sampled to get a uniform distribution of ground-truth intersection over union values.
%

    is_smooth_test_row = logical( is_ooi_row .* is_testing_row );
    x_smooth_test = d.box_proposal_cnn_features( is_smooth_test_row, : );
    gt_ious_test = d.IOUs_with_each_gt_obj(is_smooth_test_row, ooi_ind );
    
    
    % score_test = classify(w_vect_ooi,x_smooth_test);
    [~,score_test_temp] = svm_model.predict(x_smooth_test);
    score_test = score_test_temp(:,2);
    
    im_ind_smooth_test = d.fname_source_index(is_smooth_test_row);
    
    corr_val = corr(gt_ious_test,score_test);
    
    figure;
    plot( score_test, gt_ious_test, '.' )
    xlabel( 'classifier score' );
    ylabel( 'true IOU' );
    legend(num2str(['corr: ' num2str(corr_val)]))
    title('classifier/ground-truth correlation');
    axis([-.1,1.5,0,1])
    
% found that correlation between ground truth intersection over union (gtIOU) and the score
% from the classifier is ~.85. A pretty clear trend, albeit noisy. Seems to support the notion of
% local search, at least in the trend.

 
%% aggregated p( iou+ | score+ )

test_rows = find(is_smooth_test_row);
p_score_up_implies_gt_up = nan( length(test_rows), 1 );
p_score_up_implies_gt_up_eps1 = nan( length(test_rows), 1 );
p_score_up_implies_gt_up_eps2 = nan( length(test_rows), 1 );
p_score_up_implies_gt_up_band = nan( length(test_rows), 1 );
epsilon1 = .05;
epsilon2 = .2;

[~,sort_order_temp] = sort(score_test);
[~,sort_order_temp] = sort(sort_order_temp);
scaled_score = linspace(0,1,length(score_test))';
scaled_score = scaled_score(sort_order_temp);

for ii = 1:length(test_rows)
    
    score_delta = scaled_score - scaled_score(ii);
    %score_delta = score_test - score_test(ii);
    gt_delta = gt_ious_test - gt_ious_test(ii);
    
    is_score_up = score_delta > 0;
    is_gt_up = gt_delta > 0;
   
    % all
    p_score_up_implies_gt_up(ii) = sum(is_gt_up & is_score_up) / sum(is_score_up);
    
    % score close 1
    is_score_close = abs(score_delta) < epsilon1;
    p_score_up_implies_gt_up_eps1(ii) = sum( is_gt_up & is_score_close & is_score_up) / sum(is_score_up & is_score_close);
    
    % score close 2
    is_score_close = abs(score_delta) < epsilon2;
    p_score_up_implies_gt_up_eps2(ii) = sum( is_gt_up & is_score_close & is_score_up) / sum(is_score_up & is_score_close);
    
    % score band
    is_score_close = abs(score_delta) > epsilon1 ...
                   & abs(score_delta) < epsilon2;
    p_score_up_implies_gt_up_band(ii) = sum( is_gt_up & is_score_close & is_score_up) / sum(is_score_up & is_score_close);
    
    progress(ii,length(test_rows));
    
end




%smoothing_window = blackman(2000);
m = 1000;
smoothing_window = 1/m * ones(1,m);

[score_test_ridge_sorted,sort_order] = sort(score_test);

h = figure();
set(h,'color',[1 1 1]);
set(h,'position',[1,1,1280,340])

% over all scores

p_score_up_implies_gt_up(isnan(p_score_up_implies_gt_up)) = 0; % if nothing is greater, then nan, but also 0 chance of improvement

[x_mu,~,x_sigma] = local_stat( p_score_up_implies_gt_up(sort_order)', smoothing_window );
subplot(1,3,1);
h1 = plot(score_test,p_score_up_implies_gt_up,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([0 1],[.5,.5],'--black','linewidth',2);
xlim([-.1 1.1]);
ylim([-.05 1.2])
title(['P( \DeltaIOU > 0 | 0 < \Deltaf )']);
xlabel({'classifier score';'(a)'});
ylabel('P( IOU+ | score+ )');

% within eps1 scores

p_score_up_implies_gt_up_eps1(isnan(p_score_up_implies_gt_up_eps1)) = 0; % if nothing is greater, then nan, but also 0 chance of improvement
[x_mu,~,x_sigma] = local_stat( p_score_up_implies_gt_up_eps1(sort_order)', smoothing_window );

subplot(1,3,2);
h1 = plot(score_test,p_score_up_implies_gt_up_eps1,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([0 1],[.5,.5],'--black','linewidth',2);
xlim([-.1 1.1]);
ylim([-.05 1.2])
xlabel({'classifier score';'(b)'});
title(['P( \DeltaIOU > 0 | 0 < \Deltaf < ' num2str(epsilon1) ' )']);

% within eps2 scores

p_score_up_implies_gt_up_eps2(isnan(p_score_up_implies_gt_up_eps2)) = 0; % if nothing is greater, then nan, but also 0 chance of improvement
[x_mu,~,x_sigma] = local_stat( p_score_up_implies_gt_up_eps2(sort_order)', smoothing_window );

subplot(1,3,3);
h1 = plot(score_test,p_score_up_implies_gt_up_eps2,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([0 1],[.5,.5],'--black','linewidth',2);
xlim([-.1 1.1]);
ylim([-.05 1.2]);
xlabel({'classifier score';'(c)'});
title(['P( \DeltaIOU > 0 | 0 < \Deltaf < ' num2str(epsilon2) ') )']);
legend([h1,h2],'individual boxes','moving local average');


%% now look at the expected magnitude of change



test_rows = find(is_smooth_test_row);
E_gt_up_given_score_up = nan( length(test_rows), 1 );
E_gt_up_given_score_up_eps1 = nan( length(test_rows), 1 );
E_gt_up_given_score_up_eps2 = nan( length(test_rows), 1 );
E_gt_up_given_score_up_band = nan( length(test_rows), 1 );
epsilon1 = .05;
epsilon2 = .2;

[~,sort_order_temp] = sort(score_test);
[~,sort_order_temp] = sort(sort_order_temp);
scaled_score = linspace(0,1,length(score_test))';
scaled_score = scaled_score(sort_order_temp);

for ii = 1:length(test_rows)
    
    score_delta = scaled_score - scaled_score(ii);
    %score_delta = score_test - score_test(ii);
    gt_delta = gt_ious_test - gt_ious_test(ii);
    
    is_score_up = score_delta > 0;
    is_gt_up = gt_delta > 0;
    
    % all
    E_gt_up_given_score_up(ii) = sum(gt_delta .* is_score_up) / sum(is_score_up);
    
    % score close 1
    is_score_close = abs(score_delta) < epsilon1;
    E_gt_up_given_score_up_eps1(ii) = sum(gt_delta .* is_score_up .* is_score_close) / sum(is_score_up & is_score_close);
    
    % score close 2
    is_score_close = abs(score_delta) < epsilon2;
    E_gt_up_given_score_up_eps2(ii) = sum(gt_delta .* is_score_up .* is_score_close) / sum(is_score_up & is_score_close);
    
    % score band
    is_score_close = abs(score_delta) > epsilon1 ...
                   & abs(score_delta) < epsilon2;
    E_gt_up_given_score_up_band(ii) = sum(gt_delta .* is_score_up .* is_score_close) / sum(is_score_up & is_score_close);
    
    progress(ii,length(test_rows));
    
end




%smoothing_window = blackman(2000);
m = 1000;
smoothing_window = 1/m * ones(1,m);
[score_test_ridge_sorted,sort_order] = sort(score_test);

h = figure;
set(h,'color',[1 1 1]);
set(h,'position',[1,1,1280,340])

[x_mu,~,x_sigma] = local_stat( E_gt_up_given_score_up(sort_order)', smoothing_window );

subplot(1,3,1);
h1 = plot(score_test,E_gt_up_given_score_up,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([0 1],[0 0],'--black','linewidth',2);
xlabel({'classifier score';'(a)'});
ylabel('E( \DeltaIOU )');
xlim([-.1 1.1]);
ylim([-.4 .8])
title(['E( \DeltaIOU | 0 < \Deltaf )']);

% within eps1 scores
[x_mu,~,x_sigma] = local_stat( E_gt_up_given_score_up_eps1(sort_order)', smoothing_window );

subplot(1,3,2);
h1 = plot(score_test,E_gt_up_given_score_up_eps1,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([0 1],[0 0],'--black','linewidth',2);
xlabel({'classifier score';'(b)'});
xlim([-.1 1.1]);
ylim([-.4 .8])
title(['E( \DeltaIOU | 0 < \Deltaf < ' num2str(epsilon1) ' )']);

% within eps2 scores
[x_mu,~,x_sigma] = local_stat( E_gt_up_given_score_up_eps2(sort_order)', smoothing_window );

subplot(1,3,3);
h1 = plot(score_test,E_gt_up_given_score_up_eps2,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([0 1],[0 0],'--black','linewidth',2);
xlabel({'classifier score';'(c)'});
xlim([-.1 1.1]);
ylim([-.4 .8])
title(['E( \DeltaIOU | 0 < \Deltaf < ' num2str(epsilon2) ' )']);
legend([h1,h2],'individual boxes','moving local average');


%% for multiple images/boxes, what is the probability that a box that looks better, actually is better?    
% 
% % in the region around the target (that i've pre-evaluated), 
% % probability that a higher est IOU => higher gt IOU ( boxes with both / boxes with higher est )
% 
% num_boxes_per_image = zeros(1,length(inds_testing_images));
% for ii = 1:length(inds_testing_images)
%     cur_im_ind = inds_testing_images(ii);
%     is_cur_im_row = eq( cur_im_ind, d.fname_source_index );
%     num_boxes_per_image(ii) = sum( is_ooi_row .* is_cur_im_row);
% end
% 
% max_boxes_per_image = max( num_boxes_per_image );
% 
% box_iou_gt  = nan( length(inds_testing_images), max_boxes_per_image );
% box_score   = nan( length(inds_testing_images), max_boxes_per_image );
% 
% box_p_better_est_implies_better_gt_by_imi_bi = nan( length(inds_testing_images), max_boxes_per_image );
% 
% epsilon1 = .1;
% epsilon2 = .2;
% box_p_better_est_implies_better_gt_by_imi_bi_eps1 = nan( length(inds_testing_images), max_boxes_per_image );
% box_p_better_est_implies_better_gt_by_imi_bi_eps2 = nan( length(inds_testing_images), max_boxes_per_image );
% box_p_better_est_implies_better_gt_by_imi_bi_scoreband = nan( length(inds_testing_images), max_boxes_per_image );
%    
% for ii = 1:length(inds_testing_images)
%     cur_im_ind = inds_testing_images(ii);
%     is_cur_im_row = eq( cur_im_ind, d.fname_source_index );
%     is_cur_row = logical( is_cur_im_row .* is_ooi_row );
%     cur_im_x = d.box_proposal_cnn_features(is_cur_row,:);
%     cur_im_gt_vect = d.IOUs_with_each_gt_obj(is_cur_row,ooi_ind);
%     
%     %cur_im_score_vect = classify( w_vect_ooi, cur_im_x );
%     [~,cur_im_score_vect_temp] = svm_model.predict(cur_im_x);
%     cur_im_score_vect = cur_im_score_vect_temp(:,2);
%     
%     for bi = 1:num_boxes_per_image(ii)
%         cur_iou_gt  = cur_im_gt_vect(bi);
%         cur_score = cur_im_score_vect(bi);
%         
%         % consider all boxes with better score
%         box_p_better_est_implies_better_gt_by_imi_bi(ii,bi) = sum(cur_im_gt_vect > cur_iou_gt & cur_im_score_vect > cur_score) / sum(cur_im_score_vect > cur_score);
%         box_iou_gt(ii,bi) = cur_iou_gt;
%         box_score(ii,bi) = cur_score;
%         
%         % consider boxes with better score within a small step 1
%         up_gt = cur_im_gt_vect > cur_iou_gt;
%         up_score = cur_im_score_vect > cur_score;
%         close_score = abs(cur_score - cur_im_score_vect) < epsilon1;
%         box_p_better_est_implies_better_gt_by_imi_bi_eps1(ii,bi) = sum( up_gt & up_score & close_score) / sum( up_score & close_score );
%         
%         % consider boxes with better score within a small step 2
%         up_gt = cur_im_gt_vect > cur_iou_gt;
%         up_score = cur_im_score_vect > cur_score;
%         close_score = abs(cur_score - cur_im_score_vect) < epsilon2;
%         box_p_better_est_implies_better_gt_by_imi_bi_eps2(ii,bi) = sum( up_gt & up_score & close_score) / sum( up_score & close_score );
%         
%         % consider boxes with scores within a band
%         up_gt = cur_im_gt_vect > cur_iou_gt;
%         up_score = cur_im_score_vect > cur_score;
%         score_in_band = abs(cur_score - cur_im_score_vect) > epsilon1 & abs(cur_score - cur_im_score_vect) < epsilon2;
%         box_p_better_est_implies_better_gt_by_imi_bi_scoreband(ii,bi) = sum( up_gt & up_score & score_in_band) / sum( up_score & score_in_band );
%        
%         
%     end
%     progress(ii, length(inds_testing_images))
% end
% 
% figure();
% hist(box_p_better_est_implies_better_gt_by_imi_bi(:))
% xlabel('p(+gt|+score)');
% ylabel('frequency');
% title('p(+gt|+score), 100 boxes compared against the 99 from the same image, for 100 images')
% 
% % this looks pretty good. median p val is .86, so half have 86% chance of an imrpovement in score
% % creating a real increase in score. however, this is using a uniform distribution of IOU scores, so
% % few are 0, which is not like a real experiment, where the majority will have a low ground truth
% % IOU. what happens when we restrict to just boxes with a gt IOU that is low, medium, or high?
% 
% 
% 
% 
% figure();
% hist(box_p_better_est_implies_better_gt_by_imi_bi_eps1(:))
% xlabel(['p(+gt|+score), when score delta < ' num2str(epsilon1)]);
% ylabel('frequency');
% title('p(+gt|+score), 100 boxes compared against the 99 from the same image, for 100 images')
% 
% figure();
% hist(box_p_better_est_implies_better_gt_by_imi_bi_eps1(:))
% xlabel(['p(+gt|+score), when score delta < ' num2str(epsilon2)]);
% ylabel('frequency');
% title('p(+gt|+score), 100 boxes compared against the 99 from the same image, for 100 images')
% 
% 
% % when restricted to relatively close scores (which is a bit more realistic in terms of searching
% % locally, we see things get really bad. the probability of a score increase is actually pretty low.
% % if you have a big score jump, we can be confident that we're making a real improvement, but we
% % don't see so much of that...do we?
% 
% 
% figure();
% hist(box_p_better_est_implies_better_gt_by_imi_bi_scoreband(:))
% xlabel(['p(+gt|+score), when score delta in [' num2str(epsilon1) ', ' num2str(epsilon2) ']']);
% ylabel('frequency');
% title('p(+gt|+score), 100 boxes compared against the 99 from the same image, for 100 images')
% 
% % we can get pretty good results if we consider only increases that are over some threshold.
% % however, this is going down a road that includes a) processing multiple near-by boxes, b) restricting
% % only to those that are over a threshold, c) still risking an actual drop in actual IOU d) dealing
% % with finding the thresholds that allow us to do this even moderately well
% 
% 


 %% some box shape analysis, all combinations
%        
%        % lets look at search in the region of an ooi using box adjusts that include
%        % shape,size,position
%        
%         % for imii = 1:5
%         for imii = 5
% 
%             
%             
%             % image
%             
%             imi = inds_testing_images(imii);
%             im_fn = [fileparts_mq(d.fnames{imi},'path/name'),'.jpg'];
%             im = imread( im_fn );
%             lb_struct = situate.labl_load( d.fnames{imi}, situation_struct  );
%             obj_row = strcmp( object_of_interst, lb_struct.labels_adjusted );
%             box_gt_xcycwh = lb_struct.boxes_xcycwh(obj_row,:);
%             box_gt_r0rfc0cf = lb_struct.boxes_r0rfc0cf(obj_row,:);
% 
%             
%             
%             % starting box info
%             
%             box_gt_xc = box_gt_xcycwh(1);
%             box_gt_yc = box_gt_xcycwh(2);
%             box_gt_w  = box_gt_xcycwh(3);
%             box_gt_h  = box_gt_xcycwh(4);
%             box_gt_ratio = box_gt_xcycwh(3) / box_gt_xcycwh(4);
%             
%             box_initial_xc = round( box_gt_xc - box_gt_w * .2  );
%             %box_initial_xc = round( box_gt_xc - box_gt_w * 0 );
%             box_initial_yc = round( box_gt_yc - box_gt_h * .2 );
%             [box_initial_w,box_initial_h] = box_aa2wh(mean([.5, box_gt_ratio]),1.1*box_gt_w*box_gt_h); 
%             box_initial_xcycwh = [ box_initial_xc, box_initial_yc, box_initial_w, box_initial_h ];
%             [success,~,box_initial_xywh,box_initial_xcycwh] = box_fix( box_initial_xcycwh, 'xcycwh', size(im) );
%             box_initial_ratio = box_initial_w / box_initial_h;
%             
%             iou_initial = intersection_over_union( box_gt_r0rfc0cf, box_initial_xywh, 'r0rfc0cf', 'xywh');
%             
%             
%             
%             % local search offsets
%             
%             location_offset_ratio_x = linspace( -.75, .75, 15 );
%             location_offset_ratio_y = linspace( -.75, .75, 15 );
%             box_size_multiplier     = exp( linspace(log(1/4), log(4/1), 15 ) );
%             box_aspect_ratio        = exp( unique([ log(box_initial_ratio) log(box_gt_ratio) linspace(log(1/3),log(3/1),11) ]) );
%             
%             
%             
%             
%             % get indices for the parameter that's closest to gt, and closest to original box
%             
%             gt_i = argmin( abs( location_offset_ratio_x - (box_gt_xc - box_initial_xc)/box_gt_w ) );
%             gt_j = argmin( abs( location_offset_ratio_y - (box_gt_yc - box_initial_yc)/box_gt_h ) );
%             gt_k = argmin( abs( box_size_multiplier - 1 ) );
%             gt_l = argmin( abs( box_aspect_ratio - box_gt_ratio ) );
%             
%             b0_i = argmin( abs( location_offset_ratio_x - 0 ) );
%             b0_j = argmin( abs( location_offset_ratio_y - 0 ) );
%             b0_k = argmin( abs( box_size_multiplier - 1 ) );
%             b0_l = argmin( abs( box_aspect_ratio - box_gt_ratio ) );
%             
%             
%             
%             % allocate
%             
%             score_gt  = nan( numel(location_offset_ratio_x), ...
%                              numel(location_offset_ratio_y), ...
%                              numel(box_size_multiplier), ...
%                              numel(box_aspect_ratio) );
%             score_est = nan( size(score_gt) );
% 
%             iter = 1;
%             total_iter = numel(location_offset_ratio_x) * ...
%                          numel(location_offset_ratio_y) * ...
%                          numel(box_size_multiplier) * ...
%                          numel(box_aspect_ratio);
%                    
% 
%             box_records_r0rfc0cf = nan(total_iter,4);
%                      
%             for i = 1:numel(location_offset_ratio_x)
%             for j = 1:numel(location_offset_ratio_y)
%             for k = 1:numel(box_size_multiplier)
%             for l = 1:numel(box_aspect_ratio)
%                 
%                 
%                 if sum(~eq([i-b0_i,j-b0_j,k-b0_k,l-b0_l],0)) > 1 && ...
%                    sum(~eq([i-gt_i,j-gt_j,k-gt_k,l-gt_l],0)) > 1
%                     continue;
%                 end
%                 
%                 
%                 [w_new,h_new] = box_aa2wh( box_aspect_ratio(l), box_size_multiplier(k) * box_initial_w * box_initial_h );
%                 %xc_new = box_initial_xc + w_new * location_offset_ratio_x(i);
%                 %yc_new = box_initial_yc + h_new * location_offset_ratio_y(j);
%                 xc_new = box_initial_xc + box_gt_w * location_offset_ratio_x(i);
%                 yc_new = box_initial_yc + box_gt_h * location_offset_ratio_y(j);
%                 
%                 r0 = round(yc_new - h_new/2 + 1);
%                 rf = round(r0 + h_new - 1);
%                 c0 = round(xc_new - w_new/2 + 1);
%                 cf = round(c0 + w_new -1);
% 
%                 [was_success, box_new_r0rfc0cf] = box_fix( [r0 rf c0 cf], 'r0rfc0cf', size(im) );
%                 if was_success
%                     r0 = box_new_r0rfc0cf(1);
%                     rf = box_new_r0rfc0cf(2);
%                     c0 = box_new_r0rfc0cf(3);
%                     cf = box_new_r0rfc0cf(4);
% 
%                     cnn_vec = cnn.cnn_process( im(r0:rf,c0:cf,:) )';
%                     
%                     %score_est(i,j,k,l) = classify( w_vect_ooi, cnn_vec);
%                     [~,temp] = svm_model.predict(cnn_vec);
%                     score_est(i,j,k,l) = temp(:,2);
%                     
%                     score_gt(i,j,k,l) = intersection_over_union([r0, rf, c0, cf], box_gt_r0rfc0cf,'r0rfc0cf','r0rfc0cf');
%                 end
%                 
%                 if was_success
%                     box_records_r0rfc0cf(iter,:) = box_new_r0rfc0cf;
%                 end
%                 
%                 if mod(iter,10)==0 || iter == total_iter
%                     progress(iter,total_iter);
%                 end
%                 iter = iter + 1;
%                 
%             end
%             end
%             end
%             end
%             
%             
%             % view family of boxes
%             box_records_r0rfc0cf( isnan(box_records_r0rfc0cf(:,1)), :) = [];
%             figure;
%             imshow(im);
%             hold on;
%             r = randperm( size( box_records_r0rfc0cf,1 ) );
%             draw_box( box_records_r0rfc0cf(r(1:20),:), 'r0rfc0cf');
%             hold off;
%             
%             
%             figure;
%             
%             y_plot_min = -.1;
%             y_plot_max = 1.5;
%             
%             subplot_lazy(4,1);
%             temp = score_est;
%             temp = shiftdim(temp,0);
%             temp = reshape(temp,[size(temp,1), size(temp,2)*size(temp,3)*size(temp,4)]);            
%             plot(location_offset_ratio_x, temp'); hold on;
%             h(1) = plot(location_offset_ratio_x, squeeze(score_est(:,gt_j,gt_k,gt_l)), 'LineWidth',2,'Color','red'); 
%             h(2) = plot(location_offset_ratio_x, squeeze(score_est(:,b0_j,b0_k,b0_l)), 'LineWidth',2,'Color','blue'); 
%             h(3) = plot(location_offset_ratio_x([gt_i,gt_i]),[y_plot_min y_plot_max],'--black' );
%             hold off;
%             xlim([min(location_offset_ratio_x) max(location_offset_ratio_x)]);
%             ylim([y_plot_min y_plot_max]);
%             xlabel('location offset ratio x'); ylabel('score estimate')
%             
%             title(fileparts_mq(im_fn,'name.ext'))
%             
%             subplot_lazy(4,2);
%             temp = score_est;
%             temp = shiftdim(temp,1);
%             temp = reshape(temp,[size(temp,1), size(temp,2)*size(temp,3)*size(temp,4)]);            
%             plot( location_offset_ratio_y, temp' ); hold on;
%             h(1) = plot(location_offset_ratio_y, squeeze(score_est(gt_i,:,gt_k,gt_l)), 'LineWidth',2,'Color','red'); 
%             h(2) = plot(location_offset_ratio_y, squeeze(score_est(b0_i,:,b0_k,b0_l)), 'LineWidth',2,'Color','blue'); 
%             h(3) = plot(location_offset_ratio_y([gt_j,gt_j]),[y_plot_min y_plot_max],'--black' );
%             hold off;
%             legend([h(1) h(2) h(3)],'other params correct','other params slightly off','ground truth parameter');
%             xlim([min(location_offset_ratio_y) max(location_offset_ratio_y)]);
%             ylim([y_plot_min y_plot_max]);
%             xlabel('location offset ratio y'); ylabel('score estimate')
%             
%             subplot_lazy(4,3);
%             temp = score_est;
%             temp = shiftdim(temp,2);
%             temp = reshape(temp,[size(temp,1), size(temp,2)*size(temp,3)*size(temp,4)]);            
%             plot( log(box_size_multiplier), temp' ); hold on;
%             h(1) = plot( log(box_size_multiplier), squeeze(score_est(gt_i,gt_j,:,gt_l)), 'LineWidth',2,'Color','red'); 
%             h(2) = plot( log(box_size_multiplier), squeeze(score_est(b0_i,b0_j,:,b0_l)), 'LineWidth',2,'Color','blue'); 
%             h(3) = plot( log(box_size_multiplier([gt_k,gt_k])),[y_plot_min y_plot_max],'--black' );
%             hold off;
%             xlim([min(log(box_size_multiplier)) max(log(box_size_multiplier))]);
%             ylim([y_plot_min y_plot_max]);
%             xlabel('box-size multiplier'); ylabel('score estimate')
%             xticks(log([1/3 1/2 1/1 2/1 3/1]))
%             xticklabels({'1/3', '1/2', '1/1', '2/1', '3/1'});
%             
%             
%             subplot_lazy(4,4);
%             temp = score_est;
%             temp = shiftdim(temp,3);
%             temp = reshape(temp,[size(temp,1), size(temp,2)*size(temp,3)*size(temp,4)]);            
%             plot( log(box_aspect_ratio), temp' ); hold on;
%             h(1) = plot( log(box_aspect_ratio), squeeze(score_est(gt_i,gt_j,gt_k,:)), 'LineWidth',2,'Color','red'); 
%             h(2) = plot( log(box_aspect_ratio), squeeze(score_est(b0_i,b0_j,b0_k,:)), 'LineWidth',2,'Color','blue'); 
%             h(3) = plot( log(box_aspect_ratio([gt_l,gt_l])),[y_plot_min y_plot_max],'--black' );
%             hold off;
%             xlim([min(log(box_aspect_ratio)) max(log(box_aspect_ratio))])
%             ylim([y_plot_min y_plot_max]);
%             xlabel('aspect ratio'); ylabel('score estimate')
%             xticks(log([1/3 1/2 2/3 1/1 3/2 2/1  3/1]))
%             xticklabels({'1/3', '1/2','2/3', '1/1', '2/1', '3/2', '3/1'});
%             
%             
%             
%             
%             
%             
%             
%             
%             
%             figure;
%             plot( score_est(:), score_gt(:),'.')
%             xlabel('classifier score');
%             ylabel('gt iou');
%             xlim([min([0; score_est(:)]), max([1; score_est(:)])]);
%             ylim([-.1 1.1]);
%             title('classifier quality for boxes near evaluated');
%             
%             
%             % for each point, the probability that an increased est is an increased gt iou (at conf
%             % score .4 and above)
%            
%             a = score_est(:);
%             b = score_gt(:);
%             [a,sortorder] = sort(a);
%             b = b(sortorder);
%             y1 = nan(size(a)); % p of gt up | est up
%             expected_improvement = nan(size(a)); % E of improvement per point | est up
%             
%             for i = 1:numel(a)
%                 score_up_inds = a > a(i);
%                 if ~any(score_up_inds)
%                     y1(i) = nan;
%                     expected_improvement(i) = 0;
%                 else
%                     y1(i) = sum( b(score_up_inds) > b(i)) / sum(score_up_inds);
%                     expected_improvement(i) = mean(b(score_up_inds) - b(i));
%                 end
%             end
%             
%             onescol = @(x) padarray(x,[0 1],1,'pre');
%             reg_b = regress(expected_improvement,onescol(a));
%             reg_x = linspace(min(a),max(a),100)';
%             reg_y = onescol(reg_x) * reg_b;
%           
%             
%             
%             
%             
%             figure;
%             subplot(1,2,1);
%             plot(a,y1,'.')
%             xlim([min([0; score_est(:)]), max([1; score_est(:)])]);
%             ylim([min(y1) max(y1)]);
%             xlabel('classifier score');
%             ylabel('P( gt iou+ | score+ )');
%             legend([num2str(numel(a)) ' box proposals']);
%             
%             subplot(1,2,2);
%             plot(a,expected_improvement,'.')
%             xlim([min([0; score_est(:)]), max([1; score_est(:)])]);
%             ylim([min(expected_improvement) max(expected_improvement)])
%             xlabel('classifier score');
%             ylabel('E( gt iou+ | score+ )');
%             hold on;
%             
%             %[x_mu,~,x_sigma] = local_stat( expected_improvement', 100 );
%             [x_mu,~,x_sigma] = local_stat( expected_improvement', blackman(200) );
%             plot(a,x_mu,'blue','linewidth',2); hold on;
%             plot(a,x_mu+2*x_sigma,'red');
%             plot(a,x_mu-2*x_sigma,'red');
%             hold off;
%             ylim([-.5 .5])
%             xlabel('classifier score')
%             ylabel('expected improvement from change (given increased score)');
%             
%             legend('box proposals','mean (moving average)','2 sigma')
%             
%             % makes a really interesting figure:
%             % sort of a cumulative distribution with snow falling below it. why? on the far left,
%             % most points are very low gt iou and everything has a better score, so basically a
%             % guarentee of improvement, but because all boxes have better scores, that includes the
%             % few that are actually worse, so there's a cap on probability of improvement. as you
%             % move a little to the right, that trash all gets cleaned up, but you're still very low
%             % score, so your ceiling rises a little bit. once you get to a 'low-moderate score', you
%             % still have a ton of room for improvement, but the full range of actual results, so the
%             % full spread fills in. then, as you get to high scores, and probably a good box, the
%             % chance of actually getting worse becomes more of an issue, and your P of improving
%             % starts to meaningfully drop
%             %
%             % another way. why no point above that line? if were a point above that line, you would
%             % have a very low score, but a high probability of improving if you found a better
%             % score. a good number of points with score 0, but only 80% of better scores are
%             % actually better than points scoring very low
%             
%             % additional take. the optimal parameters are often relatively easy to find if all other
%             % parameters are also correct, but if they're all slightly off, then none of them are
%             % greedily optimized, and the many mistakes along the way include higher confidences
%             % than the correct parameterizations, so it gets pretty far off track.
%             
%             
%             
%         end

            
%% IOU regression, rather than classification

  % get indices for:
    %   training images
    
    object_of_interst = 'dogwalker';
    % object of interest index (column)
    ooi_ind = find( strcmp( object_of_interst, d.object_labels ) ); 
    
    % rows based on object of interest
    is_ooi_row = eq( d.box_source_obj_type, ooi_ind);
    
    % filenames associated with each box in the data set
    fn_box_source = fileparts_mq( d.fnames, 'name' );
    
    % get training image rows
    fn_train_set = fileparts_mq( data_split_struct.vision(1).fnames_lb_train, 'name' );
    inds_training_images = find( ismember( fn_box_source, fn_train_set ) );
    is_training_image_row = ismember( d.fname_source_index, inds_training_images );

    % get pos/neg training rows
    is_training_row = logical( is_ooi_row .* is_training_image_row );
    
    % get gt IOUs
    ooi_ious = d.IOUs_with_each_gt_obj(:,ooi_ind);
    
% train the classifier

    x = d.box_proposal_cnn_features( is_training_row, : );
    y = ooi_ious(is_training_row);
    k = 1000;
    w_vect_ooi = ridge( y, x, k, 0 );
    classify = @(m,x) [ones(size(x,1),1) x] * m;
    
    % regressor output (original training)
    scores_train = classify(w_vect_ooi,x);
    
    figure;
    plot( y, scores_train, '.' );
    xlabel('IOU')
    ylabel('estimated IOU')
    legend(['corr coeff: ' num2str(corr(y,scores_train))])
    axis([-.5,1.5,-.5,1.5])
    
    % tighter correlation in the middle

% eval on validation set

    
    % get testing rows
    fn_test_set = fileparts_mq( data_split_struct.vision(1).fnames_lb_test, 'name' );
    inds_testing_images = find( ismember( fn_box_source, fn_test_set ) );
    is_testing_row = ismember( d.fname_source_index, inds_testing_images );
    
    is_ooi_testing_row = logical( is_ooi_row .* is_testing_row );
    display(['test count ' object_of_interst ': ' num2str(sum(is_ooi_testing_row))])
    
    % data and regression targets
    x_test = d.box_proposal_cnn_features( is_ooi_testing_row, : );
    y_test = d.IOUs_with_each_gt_obj( is_ooi_testing_row, ooi_ind );
    
    score_test_ridge = classify(w_vect_ooi,x_test);
    
    figure;
    plot( y_test, score_test_ridge, '.' );
    xlabel('IOU')
    ylabel('estimated iou')
    legend(['corr coeff: ' num2str(corr(y_test,score_test_ridge))])
    axis([-.5,1.5,-.5,1.5])
    
    % corr coeff on testing data is around .84, so not something to be totally in love with. now
    % time for the more in depth search? 
    

%% P of improvement, E of improvement
    

test_rows = find(is_ooi_testing_row);

p_score_up_implies_gt_up = nan( length(test_rows), 1 );
p_score_up_implies_gt_up_eps1 = nan( length(test_rows), 1 );
p_score_up_implies_gt_up_eps2 = nan( length(test_rows), 1 );
p_score_up_implies_gt_up_band = nan( length(test_rows), 1 );

E_gt_up_given_score_up = nan( length(test_rows), 1 );
E_gt_up_given_score_up_eps1 = nan( length(test_rows), 1 );
E_gt_up_given_score_up_eps2 = nan( length(test_rows), 1 );
E_gt_up_given_score_up_band = nan( length(test_rows), 1 );

epsilon1 = .05;
epsilon2 = .2;

[~,sort_order_temp] = sort(score_test_ridge);
[~,sort_order_temp] = sort(sort_order_temp);
scaled_score = linspace(0,1,length(score_test_ridge))';
scaled_score = scaled_score(sort_order_temp);

for ii = 1:length(test_rows)
    
    score_delta = scaled_score - scaled_score(ii);
    %score_delta = score_test - score_test(ii);
    gt_delta = gt_ious_test - gt_ious_test(ii);
    
    is_score_up = score_delta > 0;
    is_gt_up = gt_delta > 0;
    
    % all
    p_score_up_implies_gt_up(ii) = sum(is_gt_up & is_score_up) / sum(is_score_up);
    E_gt_up_given_score_up(ii) = sum(gt_delta .* is_score_up) / sum(is_score_up);
    
    % score close 1
    is_score_close = abs(score_delta) < epsilon1;
    p_score_up_implies_gt_up_eps1(ii) = sum( is_gt_up & is_score_close & is_score_up) / sum(is_score_up & is_score_close);
    E_gt_up_given_score_up_eps1(ii) = sum(gt_delta .* is_score_up .* is_score_close) / sum(is_score_up & is_score_close);
    
    % score close 2
    is_score_close = abs(score_delta) < epsilon2;
    p_score_up_implies_gt_up_eps2(ii) = sum( is_gt_up & is_score_close & is_score_up) / sum(is_score_up & is_score_close);
    E_gt_up_given_score_up_eps2(ii) = sum(gt_delta .* is_score_up .* is_score_close) / sum(is_score_up & is_score_close);
    
    % score band
    is_score_close = abs(score_delta) > epsilon1 ...
                   & abs(score_delta) < epsilon2;
    p_score_up_implies_gt_up_band(ii) = sum( is_gt_up & is_score_close & is_score_up) / sum(is_score_up & is_score_close);
    E_gt_up_given_score_up_band(ii) = sum(gt_delta .* is_score_up .* is_score_close) / sum(is_score_up & is_score_close);
    
    progress(ii,length(test_rows));
    
end


%% visualize P and E

m = 1000;
smoothing_window = 1/m * ones(1,m);

[score_test_ridge_sorted,sort_order] = sort(score_test_ridge);

h = figure;
set(h,'color',[1 1 1]);
set(h,'position',[1,1,1280,340])

[x_mu,~,x_sigma] = local_stat( E_gt_up_given_score_up(sort_order)', smoothing_window );

subplot(1,3,1);
h1 = plot(score_test_ridge,E_gt_up_given_score_up,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
% h3 = plot( y_hat_sorted, x_mu + 2*x_sigma,'--red','linewidth',2);
% h4 = plot( y_hat_sorted, x_mu - 2*x_sigma,'--red','linewidth',2);
plot([0 1],[0 0],'--black','linewidth',2);
xlabel({'classifier score';'(a)'});
ylabel('E( \DeltaIOU )');
xlim([-.1 1.1]);
ylim([-.4 .8])
title(['E( \DeltaIOU | 0 < \Deltaf_{ridge} )']);

% within eps1 scores
[x_mu,~,x_sigma] = local_stat( E_gt_up_given_score_up_eps1(sort_order)', smoothing_window );

subplot(1,3,2);
h1 = plot(score_test_ridge,E_gt_up_given_score_up_eps1,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
% h3 = plot( y_hat_sorted, x_mu + 2*x_sigma,'--red','linewidth',2);
% h4 = plot( y_hat_sorted, x_mu - 2*x_sigma,'--red','linewidth',2);
plot([0 1],[0 0],'--black','linewidth',2);
xlabel({'classifier score';'(b)'});
xlim([-.1 1.1]);
ylim([-.4 .8])
title(['E( \DeltaIOU | 0 < \Deltaf_{ridge} < ' num2str(epsilon1) ' )']);

% within eps2 scores
[x_mu,~,x_sigma] = local_stat( E_gt_up_given_score_up_eps2(sort_order)', smoothing_window );

subplot(1,3,3);
h1 = plot(score_test_ridge,E_gt_up_given_score_up_eps2,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([0 1],[0 0],'--black','linewidth',2);
xlabel({'classifier score';'(c)'});
xlim([-.1 1.1]);
ylim([-.4 .8])
title(['E( \DeltaIOU | 0 < \Deltaf_{ridge} < ' num2str(epsilon2) ' )']);
legend([h1,h2],'individual boxes','moving local average');





h = figure();
set(h,'color',[1 1 1]);
set(h,'position',[1,1,1280,340])
[score_test_ridge_sorted,sort_order] = sort(score_test_ridge);

% over all scores
p_score_up_implies_gt_up(isnan(p_score_up_implies_gt_up)) = 0; % if nothing is greater, then nan, but also 0 chance of improvement
[x_mu,~,x_sigma] = local_stat( p_score_up_implies_gt_up(sort_order)', smoothing_window );

subplot(1,3,1);
h1 = plot(score_test_ridge,p_score_up_implies_gt_up,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([-.2 1.2],[.5,.5],'--black','linewidth',2);
xlim([-.2 1.2]);
ylim([-.05 1.2])
title(['P( \DeltaIOU > 0 | 0 < \Deltaf )']);
xlabel({'classifier score';'(a)'});
ylabel('P( \DeltaIOU > 0 )');

% within eps1 scores

p_score_up_implies_gt_up_eps1(isnan(p_score_up_implies_gt_up_eps1)) = 0; % if nothing is greater, then nan, but also 0 chance of improvement
[x_mu,~,x_sigma] = local_stat( p_score_up_implies_gt_up_eps1(sort_order)', smoothing_window );

subplot(1,3,2);
h1 = plot(score_test_ridge,p_score_up_implies_gt_up_eps1,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([-.2 1.2],[.5,.5],'--black','linewidth',2);
xlim([-.2 1.2]);
ylim([-.05 1.2])
xlabel({'classifier score';'(b)'});
title(['P( \DeltaIOU > 0 | 0 < \Deltaf < ' num2str(epsilon1) ' )']);

% within eps2 scores

p_score_up_implies_gt_up_eps2(isnan(p_score_up_implies_gt_up_eps2)) = 0; % if nothing is greater, then nan, but also 0 chance of improvement
[x_mu,~,x_sigma] = local_stat( p_score_up_implies_gt_up_eps2(sort_order)', smoothing_window );

subplot(1,3,3);
h1 = plot(score_test_ridge,p_score_up_implies_gt_up_eps2,'.');
hold on;
h2 = plot( score_test_ridge_sorted, x_mu, 'red','linewidth',2);
plot([-.2 1.2],[.5,.5],'--black','linewidth',2);
xlim([-.2 1.2]);
ylim([-.05 1.2]);
xlabel({'classifier score';'(c)'});
title(['P( \DeltaIOU > 0 | 0 < \Deltaf < ' num2str(epsilon2) ') )']);
legend([h1,h2],'individual boxes','moving local average');

    
%% bounding box regression, using basically all boxes to triain

situation_struct = situate.situation_struct_load_json('situation_definitions/dogwalking.json');
% fnames in as defined above
saved_models_directory = 'saved_models';
training_IOU_threshold = .1; % use almost everything. exclude just what has essentially no content
bb_model_temp = agent_adjustment.bb_regression_train( situation_struct, fnames_in, saved_models_directory, training_IOU_threshold );

adjust_vect_human_broad = horzcat(bb_model_temp.weight_vectors{ strcmp('dogwalker',bb_model_temp.object_types),:});



% %% bounding box regression, using just lower quality boxes
% 
% situation_struct = situate.situation_struct_load_json('situation_definitions/dogwalking.json');
% % fnames in as defined above
% saved_models_directory = 'saved_models';
% training_IOU_threshold = [.1 .6]; % use almost everything. exclude just what has essentially no content
% bb_model_temp = agent_adjustment.bb_regression_train( situation_struct, fnames_in, saved_models_directory, training_IOU_threshold );
% 
% adjust_vect_human_band = horzcat(bb_model_temp.weight_vectors{ strcmp('dogwalker',bb_model_temp.object_types),:});


%% bounding box regression, using only boxes with .6 IOU or better to train

situation_struct = situate.situation_struct_load_json('situation_definitions/dogwalking.json');
% fnames in as defined above
saved_models_directory = 'saved_models';
training_IOU_threshold = .6; % traditional, associated with no-check application
bb_model_temp = agent_adjustment.bb_regression_train( situation_struct, fnames_in, saved_models_directory, training_IOU_threshold );

adjust_vect_human_high = horzcat(bb_model_temp.weight_vectors{ strcmp('dogwalker',bb_model_temp.object_types),:});


%% bb regression eval
% [ new_agent, adjusted_box_r0rfc0cf, delta_xywh ] = apply( model, input_agent, ~, image, cnn_features );

n = sum(is_ooi_testing_row);
proposed_boxes_r0rfc0cf     = d.box_proposals_r0rfc0cf(    is_ooi_testing_row, : );
proposed_boxes_cnn_features = d.box_proposal_cnn_features( is_ooi_testing_row, : );

adjusted_boxes_r0rfc0cf_broad  = zeros(n,4);
delta_xywh_broad               = zeros(n,4);

% adjusted_boxes_r0rfc0cf_band = zeros(n,4);
% delta_xywh_band              = zeros(n,4);

adjusted_boxes_r0rfc0cf_high = zeros(n,4);
delta_xywh_high              = zeros(n,4);

for bi = 1:n
   
    [ adjusted_boxes_r0rfc0cf_broad(bi,:), delta_xywh_broad(bi,:) ]   = agent_adjustment.bb_regression_adjust_box( adjust_vect_human_broad, proposed_boxes_r0rfc0cf(bi,:), [], proposed_boxes_cnn_features(bi,:) );
%     [ adjusted_boxes_r0rfc0cf_band(bi,:), delta_xywh_band(bi,:) ] = agent_adjustment.bb_regression_adjust_box( adjust_vect_human_band, proposed_boxes_r0rfc0cf(bi,:), [], proposed_boxes_cnn_features(bi,:) );
    [ adjusted_boxes_r0rfc0cf_high(bi,:), delta_xywh_high(bi,:) ] = agent_adjustment.bb_regression_adjust_box( adjust_vect_human_high, proposed_boxes_r0rfc0cf(bi,:), [], proposed_boxes_cnn_features(bi,:) );
    progress(bi,n);
    
end


%% bb regression analysis



gt_source_boxes_r0rfc0cf = d.box_sources_r0rfc0cf( is_ooi_testing_row, : );
pre_adjust_IOUs = d.IOUs_with_source(is_ooi_testing_row);
post_adjust_IOUs_broad  = zeros( 1,n);
% post_adjust_IOUs_band   = zeros( 1,n);
post_adjust_IOUs_high   = zeros( 1,n);
for bi = 1:n
    post_adjust_IOUs_broad(bi)  = intersection_over_union( adjusted_boxes_r0rfc0cf_broad(bi,:), gt_source_boxes_r0rfc0cf(bi,:), 'r0rfc0cf', 'r0rfc0cf' );
%     post_adjust_IOUs_band(bi)   = intersection_over_union( adjusted_boxes_r0rfc0cf_band(bi,:),  gt_source_boxes_r0rfc0cf(bi,:), 'r0rfc0cf', 'r0rfc0cf' );
    post_adjust_IOUs_high(bi)   = intersection_over_union( adjusted_boxes_r0rfc0cf_high(bi,:),  gt_source_boxes_r0rfc0cf(bi,:), 'r0rfc0cf', 'r0rfc0cf' );
end



figure('color',[1 1 1]);

subplot(1,2,1)
h1 = plot(pre_adjust_IOUs, post_adjust_IOUs_broad,'.');
hold on;
h2 = plot([0 1],[0 1],'red','linewidth',2);
xlabel('initial gt IOU');
ylabel('post-adjust gt IOU');
title('training IOUs \in [.1 1]');

% subplot(1,3,2)
% h1 = plot(pre_adjust_IOUs, post_adjust_IOUs_band,'.');
% hold on;
% h2 = plot([0 1],[0 1],'red','linewidth',2);
% xlabel('initial gt IOU');
% title('training IOUs \in [.1 .6]');

subplot(1,2,2)
h1 = plot(pre_adjust_IOUs, post_adjust_IOUs_high,'.');
hold on;
h2 = plot([0 1],[0 1],'red','linewidth',2);
xlabel('initial gt IOU');
legend([h1 h2],'boxes','break-even','location','southeast')
title('training IOUs \in [.6 1]');



delta_IOUs_broad  = post_adjust_IOUs_broad  - pre_adjust_IOUs';
delta_IOUs_broad(isnan(delta_IOUs_broad)) = 0;

% delta_IOUs_band = post_adjust_IOUs_band - pre_adjust_IOUs';
% delta_IOUs_band(isnan(delta_IOUs_band)) = 0;

delta_IOUs_high = post_adjust_IOUs_high - pre_adjust_IOUs';
delta_IOUs_high(isnan(delta_IOUs_high)) = 0;



[~,sort_order] = sort(pre_adjust_IOUs);
%[~,sort_order] = sort(score_test_ridge);
m = 1000;
[E_delta_IOU_broad, ~, std_delta_IOU_broad] = local_stat( delta_IOUs_broad(sort_order), m );
% [E_delta_IOU_band, ~, std_delta_IOU_band]   = local_stat( delta_IOUs_band(sort_order),  m );
[E_delta_IOU_high, ~, std_delta_IOU_high]   = local_stat( delta_IOUs_high(sort_order),  m );

P_improved_IOU_broad = local_stat( double(delta_IOUs_broad(sort_order) > 0), m );
% P_improved_IOU_band  = local_stat( double(delta_IOUs_band(sort_order) > 0), m );
P_improved_IOU_high  = local_stat( double(delta_IOUs_high(sort_order) > 0), m );



figure('color',[1 1 1]);

subplot(1,2,1);

plot( [0 1], [.5 .5], '--black')
title('Probability of improvement');
hold on;

h1 = plot( pre_adjust_IOUs(sort_order), P_improved_IOU_broad, 'blue','linewidth',2 );
% h2 = plot( pre_adjust_IOUs(sort_order), P_improved_IOU_band, 'green','linewidth',2 );
h3 = plot( pre_adjust_IOUs(sort_order), P_improved_IOU_high, 'red', 'linewidth',2 );

ylim([0,1.1])
% legend([h1 h2 h3],'broad training data','mid IOU training data','high IOU training data');
legend([h1 h3],'broad training data','high IOU training data');
xlabel('initial IOU');
ylabel('P(\DeltaIOU>0)')



subplot(1,2,2);

plot( [0 1], [0 0], '--black')
title('Expected improvement');
hold on;

h1 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_broad, 'blue','linewidth',2 );
h2 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_broad + 1 * std_delta_IOU_broad, 'blue--' );
plot( pre_adjust_IOUs(sort_order), E_delta_IOU_broad - 1 * std_delta_IOU_broad, 'blue--' );

% h3 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_band, 'green', 'linewidth',2 );
% h4 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_band + 1 * std_delta_IOU_band, 'green--' );
% plot( pre_adjust_IOUs(sort_order), E_delta_IOU_band - 1 * std_delta_IOU_band, 'green--' );

h5 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_high, 'red', 'linewidth',2 );
h6 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_high + 1 * std_delta_IOU_high, 'red--' );
plot( pre_adjust_IOUs(sort_order), E_delta_IOU_high - 1 * std_delta_IOU_high, 'red--' );

ylim([-.5,.5])
legend([h1 h2 h5 h6],...
    'broad training data','\sigma^2', ...
    'high IOU training data','\sigma^2',...
    'location','northeast');
% legend([h1 h2 h3 h4 h5 h6],...
%     'local \mu broad','local \sigma^2 broad', ...
%     'local \mu mid','local \sigma^2 mid',...
%     'local \mu high','local \sigma^2 high',...
%     'location','northeast');
xlabel('initial IOU');
ylabel('E(\DeltaIOU)');



% two tone

threshold_intersect = pre_adjust_IOUs( sort_order( find( E_delta_IOU_broad < E_delta_IOU_high, 1,'first') ) );
thresholds = sort([linspace(.1,.9,20) threshold_intersect]);
opt_vals = nan(1,numel(thresholds));
for ti = 1:numel(thresholds)
    threshold_2tone = thresholds(ti);
    post_adjust_IOUs_2tone = zeros( size( post_adjust_IOUs_broad ) );
    post_adjust_IOUs_2tone( score_test_ridge <= threshold_2tone ) = post_adjust_IOUs_broad( score_test_ridge <= threshold_2tone );
    post_adjust_IOUs_2tone( score_test_ridge > threshold_2tone )  = post_adjust_IOUs_high(  score_test_ridge >  threshold_2tone );
    delta_IOUs_2tone = post_adjust_IOUs_2tone - pre_adjust_IOUs';
    delta_IOUs_2tone(isnan(delta_IOUs_2tone)) = 0;
    opt_vals(ti) = mean(delta_IOUs_2tone);
end
figure;
plot( thresholds, opt_vals ); 
xlabel('proposed threshold');
ylabel('E(\DeltaIOU)');
title('finding optimal mixing threshold');
    
threshold_2tone = thresholds(argmax(opt_vals));
post_adjust_IOUs_2tone = zeros( size( post_adjust_IOUs_broad ) );
post_adjust_IOUs_2tone( score_test_ridge <= threshold_2tone ) = post_adjust_IOUs_broad( score_test_ridge <= threshold_2tone );
post_adjust_IOUs_2tone( score_test_ridge > threshold_2tone )  = post_adjust_IOUs_high(  score_test_ridge >  threshold_2tone );
delta_IOUs_2tone = post_adjust_IOUs_2tone - pre_adjust_IOUs';
delta_IOUs_2tone(isnan(delta_IOUs_2tone)) = 0;
[E_delta_IOU_2tone, ~, std_delta_IOU_2tone] = local_stat( delta_IOUs_2tone(sort_order),  m );
P_improved_IOU_2tone = local_stat( double(delta_IOUs_2tone(sort_order) > 0), m );


figure('color',[1 1 1]);

subplot(1,2,1);

plot( [0 1], [.5 .5], '--black')
title('Probability of improvement');
hold on;

h1 = plot( pre_adjust_IOUs(sort_order), P_improved_IOU_broad, 'blue','linewidth',2 );
h3 = plot( pre_adjust_IOUs(sort_order), P_improved_IOU_high, 'red', 'linewidth',2 );
h2 = plot( pre_adjust_IOUs(sort_order), P_improved_IOU_2tone, 'green', 'linewidth',2 );

ylim([0,1.1])
% legend([h1 h2 h3],'broad training data','mid IOU training data','high IOU training data');
legend([h1 h3 h2],'broad training data','high IOU training data','2tone');
xlabel('initial IOU');
ylabel('P(\DeltaIOU>0)')



subplot(1,2,2);

plot( [0 1], [0 0], '--black')
title('Expected improvement');
hold on;

h1 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_broad, 'blue','linewidth',2 );
%h2 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_broad + 1 * std_delta_IOU_broad, 'blue--' );
%plot( pre_adjust_IOUs(sort_order), E_delta_IOU_broad - 1 * std_delta_IOU_broad, 'blue--' );

h5 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_high, 'red', 'linewidth',2 );
%h6 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_high + 1 * std_delta_IOU_high, 'red--' );
%plot( pre_adjust_IOUs(sort_order), E_delta_IOU_high - 1 * std_delta_IOU_high, 'red--' );

h3 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_2tone, 'green', 'linewidth',2 );
%h4 = plot( pre_adjust_IOUs(sort_order), E_delta_IOU_2tone + 1 * std_delta_IOU_2tone, 'green--' );
%plot( pre_adjust_IOUs(sort_order), E_delta_IOU_2tone - 1 * std_delta_IOU_2tone, 'green--' );


ylim([-.5,.5])
legend([h1 h5 h3],...
    'broad training data', ...
    'high IOU training data', ...
    '2tone',...
    'location','northeast');
% legend([h1 h2 h5 h6 h3 h4],...
%     'broad training data','\sigma^2', ...
%     'high IOU training data','\sigma^2',...
%     '2tone','\sigma^2',...
%     'location','northeast');
xlabel('initial IOU');
ylabel('E(\DeltaIOU)');







    
    
    
    
    
    
    
    
    

