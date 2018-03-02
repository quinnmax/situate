

function [] = situate_experiment_analysis_output_final_workspaces( input )

% [] = situate_experiment_analysis_output_final_workspaces( results_file_name );
% [] = situate_experiment_analysis_output_final_workspaces( results_directory );
% [] = situate_experiment_analysis_output_final_workspaces( cell_array_of_results_file_names );
%
% saved off final workspace images go to: [directory containing results file]/workspaces_final/

if isdir(input)
    dir_data = dir( fullfile( input, '*.mat' ) );
    input = cellfun( @(x) fullfile( input, x ), {dir_data.name}, 'UniformOutput', false );
end
    
if iscell(input)   
    cellfun( @situate_experiment_analysis_output_final_workspaces, input );
    return;
end

if isfile(input)
    situate_results_file_fname = input;
else
    error('input not recognized')
end

situate_results_data = load(situate_results_file_fname,'fnames_im_test','workspaces_final','p_condition');
output_directory = fullfile( fileparts( situate_results_file_fname), 'workspaces_final' );

if ~exist(output_directory,'dir')
    mkdir(output_directory);
end
    
figure;
font_size = 8;
for imi = 1:length(situate_results_data.fnames_im_test)
    
    cur_im_fname = situate_results_data.fnames_im_test{imi};
    
    subplot2(2,3,1,1,2,2);
    situate.workspace_draw( cur_im_fname, situate_results_data.p_condition, situate_results_data.workspaces_final{imi}, font_size );
    xlabel(['situation score: ' num2str(situate_results_data.workspaces_final{imi}.situation_support)]);
      
    [~,im_fname_pathless] = fileparts( situate_results_data.fnames_im_test{imi} );
    output_fname = [im_fname_pathless '_situate_boxes.png'];
    saveas( gcf, fullfile( output_directory, output_fname ), 'png')
    
    progress(imi,length(situate_results_data.fnames_im_test));
    
end


