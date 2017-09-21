

directories_neg = { '/Users/Max/Dropbox/AAAI2018/AllRcnnResults/handshaking leftright, negative' };
directories_pos= { '/Users/Max/Dropbox/AAAI2018/AllRcnnResults/handshaking leftright, positive all' };

fnames_include = [];
im_file_directory_pos = '/Users/Max/Documents/MATLAB/data/situate_images/Handshake_test';
im_file_directory_neg = '/Users/Max/Documents/MATLAB/data/situate_images/Handshake_negative';

situation_score_function = @(x) prod( x + .01 ) .^ length(x);

[confidences, gt_ious, boxes_xywh, output_labels, ~] = rcnn_csvs_process_handshake( directories_pos{1}, fnames_include, im_file_directory_pos );
situation_scores_pos = zeros(1,size(confidences,1));
for i = 1:length(situation_scores_pos)
    situation_scores_pos(i) = situation_score_function( confidences(i,:) );
end

[confidences, gt_ious, boxes_xywh, output_labels, ~] = rcnn_csvs_process_handshake( directories_neg{1}, fnames_include, im_file_directory_neg );
situation_scores_neg = zeros(1,size(confidences,1));
for i = 1:length(situation_scores_neg)
    situation_scores_neg(i) = situation_score_function( confidences(i,:) );
end

situation_scores_all = [situation_scores_pos situation_scores_neg];
is_pos = [true(size(situation_scores_pos)) false(size(situation_scores_neg))];

[AUROC, TPR, FPR, thresholds] = ROC( situation_scores_all, is_pos );
plot(FPR,TPR);

is_pos_inds = find(is_pos);
pos_recall_scores = zeros(size(is_pos_inds));
neg_scores = situation_scores_all(~is_pos);

for i = 1:length(is_pos_inds)
    cur_pos_ind = is_pos_inds(i);
    cur_pos_score = situation_scores_all( cur_pos_ind );
    pos_recall_scores(i) = 1 + sum( gt( neg_scores, cur_pos_score ) );
end
    
fprintf('average recall @1:   %f\n',  mean( le( pos_recall_scores, 1 ) ));
fprintf('average recall @5:   %f\n',  mean( le( pos_recall_scores, 5 ) ));
fprintf('average recall @10:  %f\n',  mean( le( pos_recall_scores, 10 ) ));
fprintf('average recall @20:  %f\n',  mean( le( pos_recall_scores, 20 ) ));
fprintf('average recall @100: %f\n',  mean( le( pos_recall_scores, 100 ) ));


        