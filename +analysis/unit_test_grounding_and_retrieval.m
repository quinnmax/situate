% analysis test script

file_pos   = 'results/analysis_check_pos/homebrew_rcnn_priming_1.mat';
file_neg_1 = 'results/analysis_check_neg/homebrew_rcnn_priming_1.mat';
file_neg_2 = 'results/analysis_check_neg/faster_rcnn_priming_1.mat';
file_neg_3 = 'results/analysis_check_neg/uniform_1.mat';

folder_pos  = 'results/analysis_check_pos';
folder_neg  = 'results/analysis_check_neg';
folder_both = 'results/analysis_check_both';

folder_absolute_both = '/Users/Max/Desktop/analysis_unit_test/analysis_check_both';
folder_absolute_neg  = '/Users/Max/Desktop/analysis_unit_test/analysis_check_neg';
folder_absolute_pos  = '/Users/Max/Desktop/analysis_unit_test/analysis_check_pos';
file_absolute_neg_1  = '/Users/Max/Desktop/analysis_unit_test/analysis_check_neg/homebrew_rcnn_priming_1.mat';
file_absolute_neg_2  = '/Users/Max/Desktop/analysis_unit_test/analysis_check_neg/faster_rcnn_priming_1.mat';
file_absolute_neg_3  = '/Users/Max/Desktop/analysis_unit_test/analysis_check_neg/uniform_1.mat';

% results folder stuff
if all( cellfun( @exist, {file_pos,file_neg_1,file_neg_2,file_neg_3,folder_pos,folder_neg,folder_both}))

    % single file, pos
    analysis.grounding_and_retrieval(file_pos);

    % single file, neg
    analysis.grounding_and_retrieval(file_neg_1);

    % single folder, pos
    analysis.grounding_and_retrieval(folder_pos);

    % single folder, neg
    analysis.grounding_and_retrieval(folder_neg);

    % file and file
    analysis.grounding_and_retrieval({file_pos,file_neg_1});

    % file and folder
    analysis.grounding_and_retrieval({folder_pos,file_neg_1,file_neg_2,file_neg_3});

    % folder and folder
    analysis.grounding_and_retrieval({folder_pos,folder_neg});

    % single folder, both
    analysis.grounding_and_retrieval(folder_both);

else
    warning('results files weren''t found');
end

% absolute addressing not in results folder
if all( cellfun( @exist, {folder_absolute_both,folder_absolute_pos,file_absolute_neg_1,file_absolute_neg_2,file_absolute_neg_3} ) )

    analysis.grounding_and_retrieval(folder_absolute_both);
    analysis.grounding_and_retrieval(file_absolute_neg_1);
    analysis.grounding_and_retrieval({folder_absolute_pos,folder_absolute_neg});

else
    warning('results files with absolute addressing weren''t found');
end
    
    
% file, file, other method
other_method = 'external box data/rcnn boxes';
if exist(other_method,'dir')
    if all( cellfun( @exist, {folder_pos,folder_neg} ) )
        analysis.grounding_and_retrieval({folder_neg, folder_pos},other_method,'-ko');
        close all;
    else
        warning('other method data found, but the comparison folders were not');
    end
else
    warning('other method data not found');
end

