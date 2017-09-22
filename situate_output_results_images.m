
% save off finished workspaces

% situate_results_file_fname = '/Users/Max/Dropbox/Projects/situate/results/handshake, test run, single attempt/normal location and box, box adjust_fold_01_2017.09.03.18.30.58.mat';
% situate_results_data = load(situate_results_file_fname,'fnames_im_test','workspaces_final','p_condition');
% output_directory          = '/Users/Max/Desktop/situate_results_images/';

% situate_results_file_fname = '/Users/Max/Dropbox/Projects/situate/results/handshake, negatives/normal location and box, box adjust_fold_01_2017.09.04.16.26.36.mat';
% situate_results_data = load(situate_results_file_fname,'fnames_im_test','workspaces_final','p_condition');
% output_directory          = '/Users/Max/Desktop/situate_results_images_negatives/';

situate_results_file_fname  = '/Users/Max/Dropbox/Projects/situate/results/dogwalking, negatives/dogwalking_negatives_situate.mat';
image_file_directory        = '/Users/Max/Documents/MATLAB/data/situate_images/Dogwalking_negative';
output_directory            = '/Users/Max/Desktop/dogwalking_situate_results_images_neg/';

situate_results_data = load(situate_results_file_fname,'fnames_im_test','workspaces_final','p_condition');

if ~exist(output_directory,'dir')
    mkdir(output_directory);
end
    
figure;

font_size = 8;
for imi = 1:length(situate_results_data.fnames_im_test)
    
    cur_im_fname = situate_results_data.fnames_im_test{imi};
    [~,fname,~]  = fileparts(cur_im_fname);
    cur_im_fname = fullfile( image_file_directory, [fname '.jpg'] );
    
    subplot2(2,3,1,1,2,2);
    situate.draw_workspace( cur_im_fname, situate_results_data.p_condition, situate_results_data.workspaces_final{imi}, font_size );
    xlabel(['situation score: ' num2str(situate_results_data.workspaces_final{imi}.situation_support)]);
      
    [~,im_fname_pathless] = fileparts( situate_results_data.fnames_im_test{imi} );
    output_fname = [im_fname_pathless '_situate_boxes.png'];
    saveas( gcf, fullfile( output_directory, output_fname ), 'png')
    
    progress(imi,length(situate_results_data.fnames_im_test));
    
end


