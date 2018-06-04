function [] = results_grounding_to_CSVs( fn )

% [] = results_grounding_to_CSVs( results_grounding_file_name );
% 
% When the grounding analysis script is run, it should generate a file called "results_grounding.mat" in
% the directory where figures and images were saved. This script takes the full file and path to one
% of those .mat files and produces csv files that contain detection results for specific objects.
%
% The naming convention for the csv files is [method description]_[object type].csv
%

    x = load(fn);

    for ci = 1:length(x.condition_structs_unique)   % condition index
    for oi = 1:length(x.situation_objects)          % object index

        % get the data
        table = [reshape(x.iou_thresholds,[],1) reshape(mean(x.object_detections_at_iou_true_pos{ci}(:,:,oi),1),[],1)];

        % make a file name
        method_description = fileparts_mq(x.condition_structs_unique{ci}.description,'name');
        obj_description = x.situation_objects{oi};
        output_fn = [method_description '_' obj_description '.csv' ];
        output_fn_full = fullfile( fileparts_mq(fn,'path'), output_fn );
        
        % make a file, save to it
        fid = fopen( output_fn_full, 'w' );
        fprintf( fid, 'threshold, hit_rate \n');
        fprintf( fid, '%0.3f, %0.3f \n', table' );
        fclose(fid);

    end
    end
    
end

    
    
    
    

    