
rcnn_data_directory_pos = { '/Users/Max/Dropbox/Projects/situate/rcnn box data/handshaking leftright, positive all' };
rcnn_data_directory_neg = { '/Users/Max/Dropbox/Projects/situate/rcnn box data/handshaking leftright, negative' };
im_file_directory_pos   = { '/Users/Max/Documents/MATLAB/data/situate_images/Handshake_test' };
im_file_directory_neg   = { '/Users/Max/Documents/MATLAB/data/situate_images/Handshake_negative' };

% rcnn_data_directory_pos = { '/Users/Max/Dropbox/Projects/situate/rcnn box data/dogwalking, positive, portland test/' };
% rcnn_data_directory_neg = { '/Users/Max/Dropbox/Projects/situate/rcnn box data/dogwalking, negative, all/' };
% im_file_directory_pos   = { '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_test/' };
% im_file_directory_neg   = { '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative/' };

% rcnn_data_directory_pos = { '/Users/Max/Dropbox/Projects/situate/rcnn box data/dogwalking, positive, stanford/' };
% rcnn_data_directory_neg = { '/Users/Max/Dropbox/Projects/situate/rcnn box data/dogwalking, negative, all/' };
% im_file_directory_pos   = { '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_StanfordSimple/' };
% im_file_directory_neg   = { '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative/' };

fnames_include = [];

situation_score_function = @(x) prod( x + .01 ) .^ length(x);

confidences = rcnn_results_processing.csvs_process( rcnn_data_directory_pos{1}, fnames_include, im_file_directory_pos{1} );
situation_scores_pos = zeros(1,size(confidences,1));
for i = 1:length(situation_scores_pos)
    situation_scores_pos(i) = situation_score_function( confidences(i,:) );
end

[confidences, gt_ious, boxes_xywh, output_labels, ~] = rcnn_results_processing.csvs_process( rcnn_data_directory_neg{1}, fnames_include, im_file_directory_neg{1} );
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

recall_at_vals = 1:100;
mean_recall_at = zeros(1,100);
for ni = 1:100
    mean_recall_at(ni) = mean( le( pos_recall_scores, recall_at_vals(ni) ) );
end

for ni = 1:length(recall_at_vals)
    fprintf('average recall @%d:   %f\n',  recall_at_vals(ni), mean_recall_at(ni) );
end

display(['rcnn median recall score: ' num2str(median(pos_recall_scores))]);




output_directory = 'results';
fname_out = fullfile( output_directory, ['average_recall_at_n_rcnn_' datestr(now,'yyyy_mm_dd_HH_MM_SS') '.csv'] );
fid = fopen(fname_out,'w');

fprintf(fid, 'n, ');
fprintf(fid, '%d, ', recall_at_vals(1:end-1) ); 
fprintf(fid, '%d\n', recall_at_vals(end) ); 

param_descriptions = {'rcnn boxes'};
for ci = 1:length(param_descriptions)
    cur_condition_desc = param_descriptions{ci};
    cur_condition_desc = strrep( cur_condition_desc, ',', '.' );
    fprintf(fid, '%s, ', cur_condition_desc);
    fprintf(fid, '%f, ', mean_recall_at(ci,1:end-1) );
    fprintf(fid, '%f\n', mean_recall_at(ci,end) );
end

fclose(fid);





        